# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Wiki moderation reject", type: :request do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:post) { Fabricate(:post, wiki: true) }

  let(:pending_payload) do
    {
      "id" => SecureRandom.uuid,
      "raw" => "updated content",
      "original_raw" => "original content",
      "revision_id" => 1,
      "edited_by_id" => admin.id,
      "created_at" => Time.zone.now.iso8601,
    }
  end

  let!(:reviewable) do
    WikiModeration.queue_pending_edit!(post, pending_payload)
    ReviewableWikiEdit.needs_review!(
      target: post,
      created_by: admin,
      payload: WikiModeration.reviewable_payload_for(pending_payload),
    )
  end

  before { sign_in(admin) }

  it "rejects without a reason" do
    post "/wiki-moderation/#{reviewable.id}/reject"

    expect(response.parsed_body["errors"]).to be_present
    expect(reviewable.reload.reject_reason).to be_nil
  end

  it "persists reject_reason when provided" do
    post "/wiki-moderation/#{reviewable.id}/reject", params: { reject_reason: "Needs more details" }

    expect(response).to have_http_status(:ok)
    expect(reviewable.reload.reject_reason).to eq("Needs more details")
    expect(reviewable.reload.status).to eq("rejected")
  end
end
