import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import ActivityForm from "./modal/activity-form.gjs";
import EndActivity from "./modal/end-activity.gjs";

const STATUS_ICONS = {
  started: "user-group",
  ended: "flag-checkered",
  recruiting: "rotate-left",
};

// 发起人和管理员的按钮（界面 5、6）：修改、打开群聊、开始活动、活动结束、过期后重新开放
export default class ActivityActions extends Component {
  @service dialog;
  @service modal;
  @service router;
  @service toasts;

  @tracked changingTo = null;

  get activity() {
    return this.args.activity;
  }

  get isChanging() {
    return !!this.changingTo;
  }

  @action
  statusIcon(status) {
    return STATUS_ICONS[status];
  }

  @action
  statusLabel(status) {
    return `kuu_buddy.actions.change_to.${status}`;
  }

  // 活动结束要问群聊保不保留（界面 7），单独一个弹窗
  @action
  changeStatus(status) {
    if (status === "ended") {
      this.modal.show(EndActivity, { model: { activity: this.activity } });
    } else if (status === "started") {
      this.dialog.yesNoConfirm({
        message: i18n("kuu_buddy.actions.confirm_start"),
        didConfirm: () => this.#saveStatus(status),
      });
    } else {
      this.#saveStatus(status);
    }
  }

  @action
  openChat() {
    this.router.transitionTo("chat.channel", "-", this.activity.chat.id);
  }

  @action
  edit() {
    this.modal.show(ActivityForm, { model: { activity: this.activity } });
  }

  async #saveStatus(status) {
    this.changingTo = status;

    try {
      await ajax(
        `/kuu-buddy/activities/${this.activity.topic_id}/status.json`,
        {
          type: "PUT",
          data: { status },
        }
      );
      this.toasts.success({
        duration: "long",
        data: { message: i18n(`kuu_buddy.actions.changed.${status}`) },
      });
      this.router.refresh();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.changingTo = null;
    }
  }

  <template>
    <div class="kuu-buddy-actions">
      <DButton
        class="btn-default kuu-buddy-actions__edit"
        @action={{this.edit}}
        @icon="pencil"
        @label="kuu_buddy.actions.edit"
      />
      {{#if this.activity.chat}}
        <DButton
          class="btn-default kuu-buddy-actions__chat"
          @action={{this.openChat}}
          @icon="comments"
          @label="kuu_buddy.actions.open_chat"
        />
      {{/if}}
      {{#each this.activity.statuses_reachable as |status|}}
        <DButton
          class="kuu-buddy-actions__change
            {{if (eq status 'ended') 'btn-primary' 'btn-default'}}"
          data-status={{status}}
          @action={{fn this.changeStatus status}}
          @disabled={{this.isChanging}}
          @icon={{this.statusIcon status}}
          @isLoading={{eq this.changingTo status}}
          @label={{this.statusLabel status}}
        />
      {{/each}}
    </div>
  </template>
}
