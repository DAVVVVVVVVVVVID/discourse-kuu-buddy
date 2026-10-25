import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// 活动群聊的卡片（界面 6）：群名、最新一条消息、「进群」。只有发起人和成员拿得到 chat。
// 电脑上 chat 在右下角的抽屉里打开，手机上全屏，都按 chat 自己的习惯
export default class ChatCard extends Component {
  @service router;

  get chat() {
    return this.args.chat;
  }

  @action
  open() {
    this.router.transitionTo("chat.channel", "-", this.chat.id);
  }

  <template>
    <div class="kuu-buddy-chat {{if this.chat.closed '--closed'}}">
      <span class="kuu-buddy-chat__icon">{{dIcon "comments"}}</span>
      <div class="kuu-buddy-chat__body">
        <span class="kuu-buddy-chat__name">{{this.chat.name}}</span>
        <span class="kuu-buddy-chat__last">
          {{#if this.chat.closed}}
            {{i18n "kuu_buddy.chat.closed"}}
          {{else if this.chat.last_message}}
            {{this.chat.last_message.username}}：{{this.chat.last_message.excerpt}}
          {{else}}
            {{i18n "kuu_buddy.chat.no_messages"}}
          {{/if}}
        </span>
      </div>
      <DButton
        class="btn-primary kuu-buddy-chat__open"
        @action={{this.open}}
        @label="kuu_buddy.chat.open"
      />
    </div>
  </template>
}
