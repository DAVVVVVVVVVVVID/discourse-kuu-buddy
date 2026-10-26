import Component from "@glimmer/component";
import { action, get, set } from "@ember/object";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { shortDate } from "discourse/lib/formatter";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";
import ActivityActions from "./activity-actions.gjs";
import ApplicationsList from "./applications-list.gjs";
import ChatCard from "./chat-card.gjs";
import JoinBar from "./join-bar.gjs";
import MembersRow from "./members-row.gjs";
import UserLevel from "./user-level.gjs";

// 帖子页标题下方（界面 3、5、6）：状态、发起人、时间 / 人数 / 条件 / 说明四行、已加入的成员、
// 群聊卡片（成员才有）、发起人的按钮和申请列表，其他人底部的「申请加入」。
// 第一楼正文和这里内容一样，由 CSS 藏起来（见初始化器里的 post-class）
export default class ActivityPanel extends Component {
  @service currentUser;
  @service dialog;

  // 用 get 读：申请、接受后 set 进来的新值，以及帖子重新加载时的新值，才会重新渲染
  get activity() {
    return get(this.args.outletArgs.model, "kuu_buddy_activity");
  }

  get topic() {
    return this.args.outletArgs.model;
  }

  get status() {
    return this.activity.status;
  }

  // 人满自动开始的叫「人数已满，活动开始！」，发起人提前开始的叫「活动开始」
  get statusLabel() {
    if (this.status === "started" && this.activity.start_reason === "full") {
      return i18n("kuu_buddy.statuses.started_full");
    }
    return i18n(`kuu_buddy.statuses.${this.status}`);
  }

  get statusDetail() {
    const { status, member_count, capacity, spots_left, ended_at } =
      this.activity;

    switch (status) {
      case "recruiting":
        return i18n("kuu_buddy.panel.spots_left", { count: spots_left });
      case "started":
        return i18n("kuu_buddy.panel.started_detail", {
          count: member_count,
          capacity,
        });
      case "ended":
        return i18n("kuu_buddy.panel.ended_detail", {
          count: member_count,
          date: shortDate(ended_at),
        });
      default:
        return null;
    }
  }

  get requirements() {
    return (
      this.activity.requirements || i18n("kuu_buddy.panel.no_requirements")
    );
  }

  get capacityLabel() {
    return i18n("kuu_buddy.panel.capacity", { count: this.activity.capacity });
  }

  get expiresOn() {
    return this.activity.expires_at && shortDate(this.activity.expires_at);
  }

  // 管理员能管理所有搭子帖，但在别人的帖子上和普通用户一样可以申请（Issue #1：鲸仔、运营号和普通用户一样）。
  // 只有发起人本人没有申请那一栏
  get isOrganizer() {
    return (
      !!this.currentUser && this.currentUser.id === this.activity.organizer?.id
    );
  }

  // 发起人看到：有成员没能拉进群聊（关了私聊、屏蔽了发起人等）
  get outOfChatCount() {
    if (!this.activity.can_manage || this.activity.status === "ended") {
      return 0;
    }
    return this.activity.members.filter((member) => member.in_chat === false)
      .length;
  }

  @action
  updateActivity(activity) {
    set(this.topic, "kuu_buddy_activity", activity);
  }

  @action
  removeMember(member) {
    this.dialog.yesNoConfirm({
      message: i18n("kuu_buddy.members.confirm_remove", {
        username: member.username,
      }),
      didConfirm: async () => {
        try {
          const result = await ajax(
            `/kuu-buddy/activities/${this.activity.topic_id}/members/${member.id}.json`,
            { type: "DELETE" }
          );
          this.updateActivity(result.activity);
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  <template>
    {{#if this.activity}}
      {{! 第一楼和标题由表单生成：普通用户这里藏掉第一楼和标题旁的编辑笔，管理员照常看到 }}
      {{#unless this.currentUser.staff}}
        {{bodyClass "kuu-buddy-topic"}}
      {{/unless}}
      <div class="kuu-buddy-panel kuu-buddy-panel--{{this.status}}">
        <div class="kuu-buddy-panel__banner">
          <span class="kuu-buddy-status kuu-buddy-status--{{this.status}}">
            {{this.statusLabel}}
          </span>
          {{#if this.statusDetail}}
            <span class="kuu-buddy-panel__status-detail">
              {{this.statusDetail}}
            </span>
          {{/if}}
        </div>

        {{#if this.activity.organizer}}
          <div class="kuu-buddy-panel__organizer">
            <a
              class="trigger-user-card"
              data-user-card={{this.activity.organizer.username}}
            >
              {{dAvatar this.activity.organizer imageSize="medium"}}
            </a>
            <div class="kuu-buddy-panel__organizer-text">
              <span class="kuu-buddy-panel__organizer-name">
                {{this.activity.organizer.username}}
                <UserLevel @user={{this.activity.organizer}} />
              </span>
              <span class="kuu-buddy-panel__organizer-meta">
                {{i18n "kuu_buddy.members.organizer"}}
                ·
                {{dAgeWithTooltip this.topic.created_at addAgo=true}}
              </span>
            </div>
          </div>
        {{/if}}

        <dl class="kuu-buddy-panel__fields">
          <div class="kuu-buddy-panel__field" data-field="schedule">
            <dt>{{i18n "kuu_buddy.fields.schedule"}}</dt>
            <dd>{{this.activity.schedule}}</dd>
          </div>
          <div class="kuu-buddy-panel__field" data-field="capacity">
            <dt>{{i18n "kuu_buddy.fields.capacity"}}</dt>
            <dd>{{this.capacityLabel}}</dd>
          </div>
          <div class="kuu-buddy-panel__field" data-field="requirements">
            <dt>{{i18n "kuu_buddy.fields.requirements"}}</dt>
            <dd>{{this.requirements}}</dd>
          </div>
          {{#if this.activity.description}}
            <div class="kuu-buddy-panel__field" data-field="description">
              <dt>{{i18n "kuu_buddy.fields.description"}}</dt>
              <dd>{{this.activity.description}}</dd>
            </div>
          {{/if}}
        </dl>

        <MembersRow
          @activity={{this.activity}}
          @onRemove={{this.removeMember}}
        />

        {{#if this.outOfChatCount}}
          <p class="kuu-buddy-panel__chat-warning">
            {{i18n "kuu_buddy.panel.out_of_chat" count=this.outOfChatCount}}
          </p>
        {{/if}}

        {{#if this.activity.chat}}
          <ChatCard @chat={{this.activity.chat}} />
        {{/if}}

        <p class="kuu-buddy-panel__safety">
          {{i18n "kuu_buddy.panel.safety_tip"}}
        </p>

        {{#if this.expiresOn}}
          <p class="kuu-buddy-panel__expiry">
            {{i18n "kuu_buddy.panel.expires_on" date=this.expiresOn}}
          </p>
        {{/if}}

        {{#if this.activity.can_manage}}
          <ActivityActions @activity={{this.activity}} />
          <ApplicationsList
            @activity={{this.activity}}
            @onChange={{this.updateActivity}}
          />
        {{/if}}
        {{#unless this.isOrganizer}}
          <JoinBar
            @activity={{this.activity}}
            @onChange={{this.updateActivity}}
          />
        {{/unless}}
      </div>
    {{/if}}
  </template>
}
