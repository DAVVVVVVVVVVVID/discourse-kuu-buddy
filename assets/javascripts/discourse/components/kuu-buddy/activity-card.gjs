import Component from "@glimmer/component";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";
import { spotsLeft } from "../../lib/kuu-buddy-card.js";

// 列表里搭子帖标题下方的卡片内容（界面 1）：时间和条件两行、成员头像叠放 + 虚线空位、人数。
// 标题用 core 自己的链接；这里挂在 topic-list-main-link-bottom，不占包裹型的 topic-link（Issue #6）。
// 整块是指向帖子的链接，手机上点哪里都能进帖子
export default class ActivityCard extends Component {
  get topic() {
    return this.args.outletArgs.topic;
  }

  get card() {
    return this.topic.kuu_buddy_card;
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

  get isRecruiting() {
    return this.card.status === "recruiting";
  }

  get emptySlots() {
    return this.isRecruiting
      ? Array.from({ length: spotsLeft(this.card) })
      : [];
  }

  get spotsLabel() {
    return this.isRecruiting
      ? i18n("kuu_buddy.card.spots_left", { count: spotsLeft(this.card) })
      : null;
  }

  get url() {
    return this.topic.linked_post_number
      ? this.topic.urlForPostNumber(this.topic.linked_post_number)
      : this.topic.lastUnreadUrl;
  }

  <template>
    {{#if this.card}}
      <a
        class="kuu-buddy-card"
        data-topic-id={{this.topic.id}}
        href={{this.url}}
        tabindex="-1"
      >
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
      </a>
    {{/if}}
  </template>
}
