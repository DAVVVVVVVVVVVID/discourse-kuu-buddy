import Component from "@glimmer/component";
import { get } from "@ember/object";
import { longDate } from "discourse/lib/formatter";
import { i18n } from "discourse-i18n";
import ActivityActions from "./activity-actions.gjs";

// 帖子页标题下方（界面 3、5、6）：状态、时间 / 人数 / 条件 / 说明四行，发起人和管理员的按钮。
// 第一楼正文和这里内容一样，由 CSS 藏起来（见初始化器里的 post-class）
export default class ActivityPanel extends Component {
  get activity() {
    return get(this.args.outletArgs.model, "kuu_buddy_activity");
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
          date: longDate(ended_at),
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
    return this.activity.expires_at && longDate(this.activity.expires_at);
  }

  <template>
    {{#if this.activity}}
      <div class="kuu-buddy-panel kuu-buddy-panel--{{this.status}}">
        <div class="kuu-buddy-panel__status">
          <span class="kuu-buddy-status kuu-buddy-status--{{this.status}}">
            {{this.statusLabel}}
          </span>
          {{#if this.statusDetail}}
            <span class="kuu-buddy-panel__status-detail">
              {{this.statusDetail}}
            </span>
          {{/if}}
        </div>

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
        {{/if}}
      </div>
    {{/if}}
  </template>
}
