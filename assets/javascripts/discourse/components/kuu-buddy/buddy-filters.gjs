import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import routeAction from "discourse/helpers/route-action";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { buddyCategoryId, LIST_FILTERS } from "../../lib/kuu-buddy.js";
import ActivityForm from "./modal/activity-form.gjs";

// 搭子广场分类页顶部的筛选（界面 1）：招募中 / 我发起的。选中的值写在网址里（kuu_buddy），
// 再点一次取消。右下角樱花粉的「+ 找搭子」打开发帖表单。只在搭子广场分类页出现，
// 挂在主题「独立页面」顶栏下面、列表上面
export default class BuddyFilters extends Component {
  @service currentUser;
  @service modal;
  @service router;
  @service siteSettings;

  get category() {
    return this.args.outletArgs.category;
  }

  get show() {
    return (
      !!this.category && this.category.id === buddyCategoryId(this.siteSettings)
    );
  }

  // 没登录时只有「招募中」
  get options() {
    const current = this.router.currentRoute?.queryParams?.kuu_buddy;
    return LIST_FILTERS.filter(
      (value) => this.currentUser || value === "recruiting"
    ).map((value) => ({
      value,
      label: i18n(`kuu_buddy.filters.${value}`),
      isSelected: value === current,
    }));
  }

  get showNewButton() {
    return !this.currentUser || this.category.canCreateTopic;
  }

  @action
  select(option) {
    this.router.transitionTo({
      queryParams: { kuu_buddy: option.isSelected ? null : option.value },
    });
  }

  @action
  openForm() {
    this.modal.show(ActivityForm, { model: {} });
  }

  <template>
    {{#if this.show}}
      <div class="kuu-buddy-filters">
        {{#each this.options as |option|}}
          <DButton
            aria-pressed={{if option.isSelected "true" "false"}}
            class="btn-flat kuu-buddy-filters__option
              {{if option.isSelected '--selected'}}"
            data-value={{option.value}}
            @action={{fn this.select option}}
            @translatedLabel={{option.label}}
          />
        {{/each}}
      </div>

      {{#if this.showNewButton}}
        <DButton
          class="btn-primary kuu-buddy-new-button"
          @action={{if
            this.currentUser
            this.openForm
            (routeAction "showLogin")
          }}
          @icon="plus"
          @label="kuu_buddy.new_topic.button"
        />
      {{/if}}
    {{/if}}
  </template>
}
