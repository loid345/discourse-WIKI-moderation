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
    pending = WikiModeration.pending_edit_for(target)
    return create_result(:success, transition_to: :approved) unless pending

    raw = args[:edited_raw].presence || pending["raw"]
    apply_pending_edit!(target, raw, performing_user)
    WikiModeration.clear_pending_edit!(target)

    create_result(:success, transition_to: :approved)
  end

  def perform_reject_wiki_edit(performing_user, args)
    WikiModeration.clear_pending_edit!(target)
    create_result(:success, transition_to: :rejected)
  end

  def self.needs_review!(target:, created_by:, payload:)
    existing =
      ReviewableWikiEdit.pending.find_by(
        target_type: target.class.name,
        target_id: target.id,
      )
    return existing if existing

    ReviewableWikiEdit.create!(
      created_by: created_by,
      target: target,
      payload: payload,
      status: Reviewable.statuses[:pending],
    )
  end

  private

  def apply_pending_edit!(post, raw, performing_user)
    post.update!(
      raw: raw,
      last_editor_id: performing_user.id,
      edit_reason: I18n.t("reviewable_wiki_edit.approved"),
    )
    post.rebake!
  end
end
