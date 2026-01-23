# frozen_string_literal: true

require "rails_helper"

RSpec.describe WikiModeration do
  describe ".diff_html" do
    it "returns inline diff html for content changes" do
      html = described_class.diff_html("old content", "new content")

      expect(html).to be_present
      expect(html).to include("<ins").or include("<del")
    end
  end

  describe ".side_by_side_diff_html" do
    it "returns side by side diff html for content changes" do
      html = described_class.side_by_side_diff_html("old content", "new content")

      expect(html).to be_present
      expect(html).to include("<table")
    end
  end

  describe ".reviewable_payload_for" do
    it "includes side by side diff html" do
      payload =
        described_class.reviewable_payload_for(
          "original_raw" => "old content",
          "raw" => "new content",
        )

      expect(payload["diff_html"]).to be_present
      expect(payload["side_by_side_html"]).to be_present
    end
  end
end
