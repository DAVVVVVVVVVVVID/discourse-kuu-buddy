import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";
import UserLevel from "./user-level.gjs";

// 发起人处理申请（界面 5）：「新的申请 2」（只有你能看到），每条头像、名字、什么时候申请、留言，
// 「婉拒」「接受，拉进群聊」。人满或活动开始后不能再接受，只能婉拒
export default class ApplicationsList extends Component {
  @service dialog;
  @service toasts;

  @tracked busyId = null;

  get activity() {
    return this.args.activity;
  }

  get canAccept() {
    return (
      this.activity.status === "recruiting" && this.activity.spots_left > 0
    );
  }

  @action
  accept(application) {
    this.#decide(application, "accept");
  }

  @action
  decline(application) {
    this.dialog.deleteConfirm({
      confirmButtonLabel: "kuu_buddy.applications.decline",
      message: i18n("kuu_buddy.applications.confirm_decline", {
        username: application.user.username,
      }),
      didConfirm: () => this.#decide(application, "decline"),
    });
  }

  async #decide(application, decision) {
    this.busyId = application.id;

    try {
      const result = await ajax(
        `/kuu-buddy/activities/${this.activity.topic_id}/applications/${application.id}/${decision}.json`,
        { type: "PUT" }
      );
      this.args.onChange(result.activity);
      if (decision === "accept") {
        this.#announceAccepted(application, result.chat_delivery);
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busyId = null;
    }
  }

  // 拉不进群聊时照样成为成员，提示发起人私下联系
  #announceAccepted(application, chatDelivery) {
    const username = application.user.username;
    if (chatDelivery === "joined") {
      this.toasts.success({
        duration: "long",
        data: {
          message: i18n("kuu_buddy.applications.accepted", { username }),
        },
      });
    } else {
      this.dialog.alert(
        i18n(`kuu_buddy.applications.chat_${chatDelivery}`, { username })
      );
    }
  }

  <template>
    {{#if this.activity.applications.length}}
      <section class="kuu-buddy-applications">
        <header class="kuu-buddy-applications__header">
          <span class="kuu-buddy-applications__title">
            {{i18n
              "kuu_buddy.applications.title"
              count=this.activity.applications.length
            }}
          </span>
          <span class="kuu-buddy-applications__private">
            {{i18n "kuu_buddy.applications.only_you"}}
          </span>
        </header>
        <ul class="kuu-buddy-applications__list">
          {{#each this.activity.applications as |application|}}
            <li
              class="kuu-buddy-applications__item"
              data-application-id={{application.id}}
            >
              <a
                class="trigger-user-card kuu-buddy-applications__avatar"
                data-user-card={{application.user.username}}
              >
                {{dAvatar application.user imageSize="medium"}}
              </a>
              <div class="kuu-buddy-applications__body">
                <div class="kuu-buddy-applications__meta">
                  <span class="kuu-buddy-applications__name">
                    {{application.user.username}}
                  </span>
                  <UserLevel @user={{application.user}} />
                  <span class="kuu-buddy-applications__time">
                    {{dAgeWithTooltip application.created_at addAgo=true}}{{i18n
                      "kuu_buddy.applications.applied"
                    }}
                  </span>
                </div>
                <p
                  class="kuu-buddy-applications__message
                    {{unless application.message '--empty'}}"
                >
                  {{if
                    application.message
                    application.message
                    (i18n "kuu_buddy.applications.no_message")
                  }}
                </p>
                <div class="kuu-buddy-applications__actions">
                  <DButton
                    class="btn-default kuu-buddy-applications__decline"
                    @action={{fn this.decline application}}
                    @disabled={{eq this.busyId application.id}}
                    @label="kuu_buddy.applications.decline"
                  />
                  {{#if this.canAccept}}
                    <DButton
                      class="btn-primary kuu-buddy-applications__accept"
                      @action={{fn this.accept application}}
                      @disabled={{eq this.busyId application.id}}
                      @isLoading={{eq this.busyId application.id}}
                      @label="kuu_buddy.applications.accept"
                    />
                  {{/if}}
                </div>
              </div>
            </li>
          {{/each}}
        </ul>
      </section>
    {{/if}}
  </template>
}
