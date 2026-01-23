import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminPluginsWikiModerationController extends Controller {
  @tracked edits = [];
  @tracked loading = false;

  @action
  updateDraft(edit, event) {
    edit.draft_raw = event.target.value;
    this.edits = [...this.edits];
  }

  @action
  async approve(edit) {
    this.loading = true;

    try {
      await ajax(`/wiki-moderation/${edit.id}/approve`, {
        type: "POST",
        data: {
          edited_raw: edit.draft_raw,
        },
      });

      this.edits = this.edits.filter((item) => item.id !== edit.id);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  async reject(edit) {
    if (!confirm(I18n.t("wiki_moderation.reject_confirm"))) {
      return;
    }

    this.loading = true;

    try {
      await ajax(`/wiki-moderation/${edit.id}/reject`, {
        type: "POST",
      });

      this.edits = this.edits.filter((item) => item.id !== edit.id);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }
}
