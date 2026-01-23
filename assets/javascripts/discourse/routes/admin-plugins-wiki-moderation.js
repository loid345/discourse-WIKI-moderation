import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class AdminPluginsWikiModerationRoute extends DiscourseRoute {
  model() {
    return ajax("/wiki-moderation");
  }

  setupController(controller, model) {
    const edits = (model?.pending_edits || []).map((edit) => ({
      ...edit,
      draft_raw: edit.raw,
    }));

    controller.setProperties({
      edits,
    });
  }
}
