import Component from "@glimmer/component";
import { cardStatusLabel } from "../../lib/kuu-buddy-card.js";

// 列表里搭子帖标题旁的状态标签（界面 1）。挂在 topic-list-after-title：
// 不包 core 的 topic-link，那是包裹型 outlet，只能有一个插件用，二手插件在用（Issue #6）
export default class ActivityCardStatus extends Component {
  get card() {
    return this.args.outletArgs.topic.kuu_buddy_card;
  }

  get label() {
    return cardStatusLabel(this.card);
  }

  <template>
    {{#if this.card}}
      <span
        class="kuu-buddy-status kuu-buddy-status--{{this.card.status}}
          kuu-buddy-card-status"
        data-topic-id={{@outletArgs.topic.id}}
      >
        {{this.label}}
      </span>
    {{/if}}
  </template>
}
