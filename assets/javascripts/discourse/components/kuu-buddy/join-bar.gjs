import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import routeAction from "discourse/helpers/route-action";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import ApplyForm from "./modal/apply-form.gjs";

// 发起人以外的人看到的底部（界面 3、4）：「申请加入」；申请了是「已申请，等发起人确认」+「撤回」；
// 已加入是「退出」；被婉拒、被移出的委婉提示一句。未登录点「申请加入」去登录
export default class JoinBar extends Component {
  @service currentUser;
  @service dialog;
  @service modal;
  @service toasts;

  @tracked saving = false;

  get activity() {
    return this.args.activity;
  }

  get status() {
    return this.activity.my_application?.status;
  }

  get isPending() {
    return this.status === "pending";
  }

  get isMember() {
    return this.status === "accepted";
  }

  get isBarred() {
    return this.status === "declined" || this.status === "removed";
  }

  // 未登录的人在招募中的帖子上也看到按钮，点了去登录
  get showApply() {
    if (!this.currentUser) {
      return (
        this.activity.status === "recruiting" && this.activity.spots_left > 0
      );
    }
    return this.activity.can_apply;
  }

  get canLeave() {
    return this.isMember && this.activity.status !== "ended";
  }

  @action
  apply() {
    this.modal.show(ApplyForm, {
      model: { activity: this.activity, onApplied: this.args.onChange },
    });
  }

  @action
  withdraw() {
    this.dialog.yesNoConfirm({
      message: i18n("kuu_buddy.join.confirm_withdraw"),
      didConfirm: () =>
        this.#save("applications/mine", "kuu_buddy.join.withdrawn"),
    });
  }

  @action
  leave() {
    this.dialog.yesNoConfirm({
      message: i18n("kuu_buddy.join.confirm_leave"),
      didConfirm: () => this.#save("membership", "kuu_buddy.join.left"),
    });
  }

  async #save(path, messageKey) {
    this.saving = true;

    try {
      const result = await ajax(
        `/kuu-buddy/activities/${this.activity.topic_id}/${path}.json`,
        { type: "DELETE" }
      );
      this.args.onChange(result.activity);
      this.toasts.success({ data: { message: i18n(messageKey) } });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <div class="kuu-buddy-join">
      {{#if this.isPending}}
        <span class="kuu-buddy-join__pending">
          {{i18n "kuu_buddy.join.pending"}}
        </span>
        <DButton
          class="btn-default kuu-buddy-join__withdraw"
          @action={{this.withdraw}}
          @disabled={{this.saving}}
          @isLoading={{this.saving}}
          @label="kuu_buddy.join.withdraw"
        />
      {{else if this.canLeave}}
        <span class="kuu-buddy-join__member">
          {{i18n "kuu_buddy.join.member"}}
        </span>
        <DButton
          class="btn-flat kuu-buddy-join__leave"
          @action={{this.leave}}
          @disabled={{this.saving}}
          @isLoading={{this.saving}}
          @label="kuu_buddy.join.leave"
        />
      {{else if this.isBarred}}
        <span class="kuu-buddy-join__barred">
          {{i18n "kuu_buddy.join.barred"}}
        </span>
      {{else if this.showApply}}
        <DButton
          class="btn-primary kuu-buddy-join__apply"
          @action={{if this.currentUser this.apply (routeAction "showLogin")}}
          @label="kuu_buddy.join.apply"
        />
      {{/if}}
    </div>
  </template>
}
