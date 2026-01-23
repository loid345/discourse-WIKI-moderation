# frozen_string_literal: true

module WikiModeration
  class WikiModerationController < ::ApplicationController
    requires_plugin "discourse-WIKI-moderation"

    before_action :ensure_staff

    def index
      reviewables =
        ReviewableWikiEdit
          .where(status: Reviewable.statuses[:pending])
          .includes(:target, :created_by)
          .order(created_at: :asc)
          .limit(50)

      editor_ids = reviewables.map { |reviewable| reviewable.payload&.dig("edited_by_id") }.compact
      editors = User.where(id: editor_ids).index_by(&:id)

      render_json_dump(pending_edits: serialize_pending_edits(reviewables, editors))
    end

    def approve
      reviewable = find_reviewable
      reviewable.perform_approve_wiki_edit(current_user, edited_raw: params[:edited_raw])
      render json: success_json
    rescue StandardError => e
      render_json_error(e.message)
    end

    def reject
      reviewable = find_reviewable
      reviewable.perform_reject_wiki_edit(
        current_user,
        { reject_reason: params[:reject_reason] },
      )
      render json: success_json
    rescue StandardError => e
      render_json_error(e.message)
    end

    private

    def ensure_staff
      raise Discourse::InvalidAccess.new unless current_user&.staff?
    end

    def find_reviewable
      ReviewableWikiEdit.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      raise Discourse::NotFound
    end

    def serialize_pending_edits(reviewables, editors)
      reviewables.map do |reviewable|
        pending = reviewable.payload || {}
        post = reviewable.target
        editor = editors[pending["edited_by_id"]]

        {
          id: reviewable.id,
          post_id: post&.id,
          post_url: post&.url,
          post_title: post&.topic&.title || post&.topic&.fancy_title,
          original_raw: pending["original_raw"],
          raw: pending["raw"],
          diff_html:
            pending["diff_html"] || WikiModeration.diff_html(pending["original_raw"], pending["raw"]),
          side_by_side_html:
            pending["side_by_side_html"] ||
              WikiModeration.side_by_side_diff_html(pending["original_raw"], pending["raw"]),
          edited_by_id: pending["edited_by_id"],
          edited_by_username: editor&.username,
          created_at: pending["created_at"] || reviewable.created_at&.iso8601,
        }
      end
    end
  end
end
