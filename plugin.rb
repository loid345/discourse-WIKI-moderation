# frozen_string_literal: true

# name: discourse-wiki-moderation
# about: Adds moderation for wiki edits with approve/reject flow.
# version: 0.1.0
# authors: Discourse Community
# url: https://github.com/example/discourse-wiki-moderation
# required_version: 3.2.0

enabled_site_setting :wiki_moderation_enabled

module ::WikiModeration
  PLUGIN_NAME = "discourse-wiki-moderation"
  PENDING_EDIT_KEY = "wiki_moderation_pending_edit"

  def self.pending_edit_for(post)
    raw = post.custom_fields[PENDING_EDIT_KEY]
    return if raw.blank?

    JSON.parse(raw)
  end

  def self.store_pending_edit!(post, payload)
    post.custom_fields[PENDING_EDIT_KEY] = payload.to_json
    post.save_custom_fields
  end

  def self.clear_pending_edit!(post)
    post.custom_fields.delete(PENDING_EDIT_KEY)
    post.save_custom_fields
  end
end

require_relative "lib/wiki_moderation/engine"

require_relative "app/models/reviewable_wiki_edit"

after_initialize do
  DiscourseEvent.on(:post_edited) do |post, editor|
    next unless SiteSetting.wiki_moderation_enabled
    next unless post.wiki
    next if editor&.staff?
    next if WikiModeration.pending_edit_for(post)

    revision = post.revisions&.last
    raw_change = revision&.modifications&.dig("raw")
    next unless raw_change&.length == 2

    old_raw, new_raw = raw_change
    next if old_raw.blank? || new_raw.blank? || old_raw == new_raw

    pending_payload = {
      "raw" => new_raw,
      "revision_id" => revision.id,
      "edited_by_id" => editor&.id,
      "created_at" => Time.zone.now.iso8601,
    }

    WikiModeration.store_pending_edit!(post, pending_payload)
    post.update_columns(raw: old_raw)
    post.rebake!

    ReviewableWikiEdit.needs_review!(
      target: post,
      created_by: editor,
      payload: pending_payload,
    )
  end
end
