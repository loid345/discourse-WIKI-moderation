# frozen_string_literal: true

# name: discourse-WIKI-moderation
# about: Adds moderation for wiki edits with approve/reject flow.
# version: 0.1.0
# authors: Discourse Community
# url: https://github.com/example/discourse-wiki-moderation
# required_version: 3.2.0

enabled_site_setting :wiki_moderation_enabled

add_admin_route "wiki_moderation.title", "wiki-moderation"

module ::WikiModeration
  PLUGIN_NAME = "discourse-WIKI-moderation"
  PENDING_EDIT_KEY = "wiki_moderation_pending_edit"

  def self.pending_edits_for(post)
    raw = post.custom_fields[PENDING_EDIT_KEY]
    return [] if raw.blank?

    parsed = JSON.parse(raw)
    return [] if parsed.blank?

    parsed.is_a?(Array) ? parsed : [parsed]
  rescue JSON::ParserError
    []
  end

  def self.pending_edit_for(post)
    pending_edits_for(post).first
  end

  def self.store_pending_edits!(post, payloads)
    if payloads.blank?
      post.custom_fields.delete(PENDING_EDIT_KEY)
    else
      post.custom_fields[PENDING_EDIT_KEY] = payloads.to_json
    end
    post.save_custom_fields
  end

  def self.queue_pending_edit!(post, payload)
    edits = pending_edits_for(post)
    edits << payload
    store_pending_edits!(post, edits)
    edits
  end

  def self.remove_pending_edit!(post, pending_id)
    edits = pending_edits_for(post)
    edits.reject! { |edit| edit["id"] == pending_id }
    store_pending_edits!(post, edits)
    edits
  end

  def self.clear_pending_edit!(post)
    store_pending_edits!(post, [])
  end

  def self.exempt_from_moderation?(editor)
    return true if editor&.staff? && SiteSetting.wiki_moderation_ignore_staff

    exempt_groups = SiteSetting.wiki_moderation_exempt_groups
    return false if exempt_groups.blank? || editor.blank?

    group_names = exempt_groups.split("|")
    Group
      .where(name: group_names)
      .joins(:users)
      .where(users: { id: editor.id })
      .exists?
  end

  def self.build_pending_payload(old_raw:, new_raw:, revision:, editor:)
    {
      "id" => SecureRandom.uuid,
      "raw" => new_raw,
      "original_raw" => old_raw,
      "revision_id" => revision.id,
      "edited_by_id" => editor&.id,
      "created_at" => Time.zone.now.iso8601,
    }
  end

  def self.reviewable_payload_for(pending)
    pending.merge(
      "diff_html" => diff_html(pending["original_raw"], pending["raw"]),
      "side_by_side_html" => side_by_side_diff_html(pending["original_raw"], pending["raw"]),
    )
  end

  def self.notify_moderators!(post, editor)
    return unless SiteSetting.wiki_moderation_notify_moderators

    staff_group_ids = [Group::AUTO_GROUPS[:admins], Group::AUTO_GROUPS[:moderators]].uniq
    user_ids =
      Group.where(id: staff_group_ids).joins(:users).distinct.pluck("users.id") - [editor&.id].compact
    return if user_ids.empty?

    User.where(id: user_ids).find_each do |user|
      SystemMessage.create(
        user,
        "wiki_edit_pending",
        post_title: post.topic&.title || post.topic&.fancy_title || post.topic_id,
        post_url: post.url,
        editor_username: editor&.username || I18n.t("user.deleted", default: "deleted"),
      )
    end
  end

  def self.notify_author!(post, pending, moderator:, decision:, reject_reason: nil)
    return unless SiteSetting.wiki_moderation_notify_authors

    user = User.find_by(id: pending["edited_by_id"])
    return unless user

    SystemMessage.create(
      user,
      "wiki_edit_#{decision}",
      post_title: post.topic&.title || post.topic&.fancy_title || post.topic_id,
      post_url: post.url,
      moderator_username: moderator&.username || I18n.t("user.deleted", default: "deleted"),
      reject_reason: reject_reason.to_s,
    )
  end

  def self.diff_html(original_raw, proposed_raw)
    return if original_raw.blank? || proposed_raw.blank?

    DiscourseDiff.new(original_raw, proposed_raw).inline_html
  end

  def self.side_by_side_diff_html(original_raw, proposed_raw)
    return if original_raw.blank? || proposed_raw.blank?

    DiscourseDiff.new(original_raw, proposed_raw).side_by_side_html
  end
end

require_relative "lib/wiki_moderation/engine"

after_initialize do
  on(:post_edited) do |post, editor|
    next unless SiteSetting.wiki_moderation_enabled
    next unless post.wiki
    next if WikiModeration.exempt_from_moderation?(editor)

    revision = post.revisions&.last
    raw_change = revision&.modifications&.dig("raw")
    next unless raw_change&.length == 2

    old_raw, new_raw = raw_change
    next if old_raw.blank? || new_raw.blank? || old_raw == new_raw

    pending_payload =
      WikiModeration.build_pending_payload(
        old_raw: old_raw,
        new_raw: new_raw,
        revision: revision,
        editor: editor,
      )

    WikiModeration.queue_pending_edit!(post, pending_payload)
    post.update_columns(raw: old_raw)
    post.rebake!

    ReviewableWikiEdit.needs_review!(
      target: post,
      created_by: editor,
      payload: WikiModeration.reviewable_payload_for(pending_payload),
    )

    WikiModeration.notify_moderators!(post, editor)
  end
end
