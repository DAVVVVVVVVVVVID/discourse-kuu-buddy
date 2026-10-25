import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";

// 包在 core 话题列表标题（topic-list/topic-link）外面：搭子帖的标题链接画成卡片（界面 1）：
// 标题、状态标签、时间和条件两行、成员头像叠放 + 虚线空位、人数。其他帖子直接交回 core 的渲染（yield）。
// core 的两处调用都传了 raw-topic-link 类名和 focus / blur 处理，这里照抄，键盘浏览列表时的高亮才不会丢
export default class ActivityTopicLink extends Component {
  get topic() {
    return this.args.outletArgs.topic;
  }

  get card() {
    return this.topic.kuu_buddy_card;
  }

  get statusLabel() {
    const { status, start_reason } = this.card;
    if (status === "started" && start_reason === "full") {
      return i18n("kuu_buddy.card_statuses.started_full");
    }
    return i18n(`kuu_buddy.card_statuses.${status}`);
  }

  get requirements() {
    return this.card.requirements || i18n("kuu_buddy.panel.no_requirements");
  }

  get countLabel() {
    return i18n("kuu_buddy.card.count", {
      count: this.card.member_count,
      capacity: this.card.capacity,
    });
  }

  get members() {
    return this.card.members ?? [];
  }

  get emptySlots() {
    if (this.card.status !== "recruiting") {
      return [];
    }
    return Array.from({
      length: Math.max(this.card.capacity - this.card.member_count, 0),
    });
  }

  get spotsLabel() {
    if (this.card.status !== "recruiting") {
      return null;
    }
    return i18n("kuu_buddy.card.spots_left", {
      count: Math.max(this.card.capacity - this.card.member_count, 0),
    });
  }

  get url() {
    return this.topic.linked_post_number
      ? this.topic.urlForPostNumber(this.topic.linked_post_number)
      : this.topic.lastUnreadUrl;
  }

  @action
  highlightItem(event) {
    event.target.closest(".topic-list-item")?.classList.add("selected");
  }

  @action
  unhighlightItem(event) {
    event.target.closest(".topic-list-item")?.classList.remove("selected");
  }

  <template>
    {{~#if this.card~}}
      <a
        class="title raw-link raw-topic-link kuu-buddy-card"
        data-topic-id={{this.topic.id}}
        href={{this.url}}
        {{on "focus" this.highlightItem}}
        {{on "blur" this.unhighlightItem}}
      >
        <span class="kuu-buddy-card__header">
          <span class="kuu-buddy-card__title">{{this.topic.title}}</span>
          <span class="kuu-buddy-status kuu-buddy-status--{{this.card.status}}">
            {{this.statusLabel}}
          </span>
        </span>
        <span class="kuu-buddy-card__line" data-field="schedule">
          <span class="kuu-buddy-card__label">
            {{i18n "kuu_buddy.fields.schedule"}}
          </span>
          {{this.card.schedule}}
        </span>
        <span class="kuu-buddy-card__line" data-field="requirements">
          <span class="kuu-buddy-card__label">
            {{i18n "kuu_buddy.fields.requirements_short"}}
          </span>
          {{this.requirements}}
        </span>
        <span class="kuu-buddy-card__footer">
          <span class="kuu-buddy-card__avatars">
            {{#each this.members as |member|}}
              <span class="kuu-buddy-card__avatar">
                {{dAvatar member imageSize="tiny"}}
              </span>
            {{/each}}
            {{#each this.emptySlots}}
              <span class="kuu-buddy-card__slot"></span>
            {{/each}}
          </span>
          <span class="kuu-buddy-card__count">{{this.countLabel}}</span>
          {{#if this.spotsLabel}}
            <span class="kuu-buddy-card__spots">{{this.spotsLabel}}</span>
          {{/if}}
        </span>
        {{~#if this.topic.visited~}}
          <span class="sr-only">&nbsp;{{i18n "topic.sr_read"}}</span>
        {{~/if~}}
      </a>
    {{~else~}}
      {{yield}}
    {{~/if~}}
  </template>
}
