# frozen_string_literal: true

require_dependency "reviewable"

class ReviewableWikiEdit < Reviewable
  def build_actions(actions, guardian, args)
    return unless guardian.can_approve?(self)

    actions.add(
      :approve_wiki_edit,
      icon: "check",
      button_class: "btn-primary",
      label: "js.reviewables.actions.approve_wiki_edit.title",
    )
    actions.add(
      :reject_wiki_edit,
      icon: "times",
      button_class: "btn-danger",
      label: "js.reviewables.actions.reject_wiki_edit.title",
    )
  end

  def perform_approve_wiki_edit(performing_user, args)
    pending = pending_edit_from_payload
    return create_result(:success, transition_to: :approved) unless pending

    raw = args[:edited_raw].presence || pending["raw"]
    apply_pending_edit!(target, raw, performing_user)
    remaining = WikiModeration.remove_pending_edit!(target, pending["id"])
    WikiModeration.notify_author!(target, pending, moderator: performing_user, decision: :approved)

    if remaining.any?
      update_reviewable_for_next!(remaining.first)
      create_result(:success, transition_to: :pending)
    else
      create_result(:success, transition_to: :approved)
    end
  end

  def perform_reject_wiki_edit(performing_user, args)
    pending = pending_edit_from_payload
    update!(reject_reason: args[:reject_reason].presence)
    WikiModeration.remove_pending_edit!(target, pending["id"]) if pending
    update!(reject_reason: reject_reason) if reject_reason.present?
    if pending
      WikiModeration.notify_author!(
        target,
        pending,
        moderator: performing_user,
        decision: :rejected,
        reject_reason: reject_reason,
      )
    end

    remaining = WikiModeration.pending_edits_for(target)
    if remaining.any?
      update_reviewable_for_next!(remaining.first)
      create_result(:success, transition_to: :pending)
    else
      create_result(:success, transition_to: :rejected)
    end
  end

  def self.needs_review!(target:, created_by:, payload:)
    existing =
      ReviewableWikiEdit.find_by(
        target_type: target.class.name,
        target_id: target.id,
      )
    if existing
      return existing if existing.pending?

      existing.update!(
        created_by: created_by,
        payload: payload,
        reviewable_by_moderator: true,
        status: Reviewable.statuses[:pending],
      )
      return existing
    end

    ReviewableWikiEdit.create!(
      created_by: created_by,
      reviewable_by_moderator: true,
      target: target,
      payload: payload,
      status: Reviewable.statuses[:pending],
    )
  end

  private

  def apply_pending_edit!(post, raw, performing_user)
    if defined?(PostRevisor)
      PostRevisor.new(post, performing_user).revise!(
        performing_user,
        { raw: raw },
        force_new_revision: true,
        edit_reason: I18n.t("reviewable_wiki_edit.approved"),
      )
    else
      post.update!(
        raw: raw,
        last_editor_id: performing_user.id,
        edit_reason: I18n.t("reviewable_wiki_edit.approved"),
      )
      post.rebake!
    end
  end

  def pending_edit_from_payload
    pending_id = payload&.dig("id")
    pending_edits = WikiModeration.pending_edits_for(target)
    pending_edits.find { |edit| edit["id"] == pending_id } || pending_edits.first
  end

  def update_reviewable_for_next!(pending)
    update!(
      created_by_id: pending["edited_by_id"],
      payload: WikiModeration.reviewable_payload_for(pending),
    )
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint           not null, primary key
#  force_review            :boolean          default(FALSE), not null
#  latest_score            :datetime
#  payload                 :json
#  potential_spam          :boolean          default(FALSE), not null
#  potentially_illegal     :boolean          default(FALSE)
#  reject_reason           :text
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  score                   :float            default(0.0), not null
#  status                  :integer          default("pending"), not null
#  target_type             :string
#  type                    :string           not null
#  type_source             :string           default("unknown"), not null
#  version                 :integer          default(0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  category_id             :integer
#  created_by_id           :integer          not null
#  target_created_by_id    :integer
#  target_id               :integer
#  topic_id                :integer
#
# Indexes
#
#  idx_reviewables_score_desc_created_at_desc                  (score,created_at)
#  index_reviewables_on_reviewable_by_group_id                 (reviewable_by_group_id)
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_target_id_where_post_type_eq_post      (target_id) WHERE ((target_type)::text = 'Post'::text)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
