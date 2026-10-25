import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// 「已加入（3）」一排头像（界面 3、5、6）：发起人在最前面并标注，然后按加入顺序，后面是虚线空位。
// 发起人看到每个成员头像旁的菜单，可以移出；没能拉进群聊的成员头像上有标记
export default class MembersRow extends Component {
  get activity() {
    return this.args.activity;
  }

  get emptySlots() {
    if (this.activity.status !== "recruiting") {
      return [];
    }
    return Array.from({ length: this.activity.spots_left });
  }

  get canRemove() {
    return (
      this.activity.can_manage &&
      ["recruiting", "started"].includes(this.activity.status)
    );
  }

  @action
  isOutOfChat(member) {
    return this.activity.can_manage && member.in_chat === false;
  }

  @action
  remove(member, menu) {
    menu.close();
    this.args.onRemove(member);
  }

  <template>
    <div class="kuu-buddy-members">
      <div class="kuu-buddy-members__title">
        {{i18n "kuu_buddy.members.title" count=this.activity.member_count}}
      </div>
      <ul class="kuu-buddy-members__list">
        {{#if this.activity.organizer}}
          <li class="kuu-buddy-members__item --organizer">
            <a
              class="trigger-user-card kuu-buddy-members__avatar"
              data-user-card={{this.activity.organizer.username}}
              title={{this.activity.organizer.username}}
            >
              {{dAvatar this.activity.organizer imageSize="medium"}}
            </a>
            <span class="kuu-buddy-members__badge">
              {{i18n "kuu_buddy.members.organizer"}}
            </span>
          </li>
        {{/if}}
        {{#each this.activity.members as |member|}}
          <li
            class="kuu-buddy-members__item
              {{if (this.isOutOfChat member) '--out-of-chat'}}"
            data-username={{member.username}}
          >
            <a
              class="trigger-user-card kuu-buddy-members__avatar"
              data-user-card={{member.username}}
              title={{member.username}}
            >
              {{dAvatar member imageSize="medium"}}
            </a>
            {{#if this.canRemove}}
              <DMenu
                @icon="ellipsis"
                @identifier="kuu-buddy-member-menu"
                @modalForMobile={{true}}
                @title={{i18n "kuu_buddy.members.menu"}}
                @triggerClass="btn-flat btn-small kuu-buddy-members__menu"
              >
                <:content as |menu|>
                  <DButton
                    class="btn-transparent btn-danger kuu-buddy-members__remove"
                    @action={{fn this.remove member menu}}
                    @icon="user-xmark"
                    @translatedLabel={{i18n
                      "kuu_buddy.members.remove"
                      username=member.username
                    }}
                  />
                </:content>
              </DMenu>
            {{/if}}
          </li>
        {{/each}}
        {{#each this.emptySlots}}
          <li class="kuu-buddy-members__item --empty">
            <span class="kuu-buddy-members__slot">{{dIcon "plus"}}</span>
          </li>
        {{/each}}
      </ul>
    </div>
  </template>
}
