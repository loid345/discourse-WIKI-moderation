# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Wiki moderation reject" do
  fab!(:admin)
  let_it_be(:editor) { Fabricate(:user) }
  let_it_be(:wiki_post) { Fabricate(:post, wiki: true) }

  let(:pending_payload) do
    {
      "id" => SecureRandom.uuid,
      "raw" => "updated wiki content",
      "original_raw" => wiki_post.raw,
      "revision_id" => 1,
      "edited_by_id" => editor.id,
      "created_at" => Time.zone.now.iso8601,
    }
  end

  let!(:reviewable) do
    WikiModeration.queue_pending_edit!(wiki_post, pending_payload)
    ReviewableWikiEdit.needs_review!(
      target: wiki_post,
      created_by: editor,
      payload: WikiModeration.reviewable_payload_for(pending_payload),
    )
  end

  before do
    SiteSetting.wiki_moderation_enabled = true
    sign_in(admin)
  end

  def reject_request(reason: nil)
    params = {}
    params[:reject_reason] = reason if reason.present?
    post "/wiki-moderation/#{reviewable.id}/reject.json", params: params
  end

  it "rejects without a reason" do
    reject_request

    expect(response).to have_http_status(:ok)
    expect(reviewable.reload).to be_rejected
    expect(reviewable.reject_reason).to be_nil
  end

  it "persists reject_reason when provided" do
    reason = "Needs clarification"

    reject_request(reason: reason)

    expect(response).to have_http_status(:ok)
    expect(reviewable.reload.reject_reason).to eq(reason)
  end
end
