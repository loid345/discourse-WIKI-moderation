import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class RejectWikiEditController extends Controller {
  @service siteSettings;
  @tracked selectedReason = "";
  @tracked rejectReason = "";

  onShow() {
    this.selectedReason = "";
    this.rejectReason = "";
  }

  get rejectionReasons() {
    return (this.siteSettings.wiki_moderation_rejection_reasons || "")
      .split("|")
      .map((reason) => reason.trim())
      .filter(Boolean);
  }

  get submitDisabled() {
    return !this.rejectReason?.trim();
  }

  @action
  updateRejectReason(event) {
    this.rejectReason = event.target.value;
  }

  @action
  applyRejectTemplate(event) {
    this.selectedReason = event.target.value;
    if (this.selectedReason) {
      this.rejectReason = this.selectedReason;
    }
  }

  @action
  async reject() {
    if (!this.rejectReason?.trim()) {
      alert(I18n.t("wiki_moderation.reject_reason_required"));
      return;
    }

    try {
      await ajax(`/wiki-moderation/${this.model.edit.id}/reject`, {
        type: "POST",
        data: {
          reject_reason: this.rejectReason,
        },
      });

      if (this.model.afterReject) {
        this.model.afterReject(this.model.edit);
      }

      this.send("closeModal");
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
