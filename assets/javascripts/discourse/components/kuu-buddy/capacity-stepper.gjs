import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

// 表单里的人数：− / + 按钮，旁边提示「还要找 3 个人（2～20 人）」（界面 2）。人数含发起人
export default class CapacityStepper extends Component {
  get value() {
    return this.args.value;
  }

  get canDecrease() {
    return this.value > this.args.min;
  }

  get canIncrease() {
    return this.value < this.args.max;
  }

  get hint() {
    return i18n("kuu_buddy.form.capacity_hint", {
      count: this.value - 1,
      min: this.args.min,
      max: this.args.max,
    });
  }

  @action
  decrease() {
    this.args.onChange(this.value - 1);
  }

  @action
  increase() {
    this.args.onChange(this.value + 1);
  }

  <template>
    <div class="kuu-buddy-stepper">
      <DButton
        aria-label={{i18n "kuu_buddy.form.capacity_decrease"}}
        class="btn-default kuu-buddy-stepper__decrease"
        @action={{this.decrease}}
        @disabled={{if this.canDecrease false true}}
        @icon="minus"
      />
      <span aria-live="polite" class="kuu-buddy-stepper__value">
        {{this.value}}
      </span>
      <DButton
        aria-label={{i18n "kuu_buddy.form.capacity_increase"}}
        class="btn-default kuu-buddy-stepper__increase"
        @action={{this.increase}}
        @disabled={{if this.canIncrease false true}}
        @icon="plus"
      />
      <span class="kuu-buddy-stepper__hint">{{this.hint}}</span>
    </div>
  </template>
}
