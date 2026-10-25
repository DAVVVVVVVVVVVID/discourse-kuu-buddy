import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const CHAT_CHOICES = ["keep", "close"];

// 活动结束（界面 7）：「活动结束了吗？」+ 说明；有群聊时问要不要保留：
// 保留（变成普通群聊，大家可以继续聊、下次再约）或关闭。「还没结束」「确认结束」
export default class EndActivity extends Component {
  @service router;
  @service toasts;

  @tracked chatChoice = "keep";
  @tracked flash;
  @tracked isSubmitting = false;

  chatChoices = CHAT_CHOICES;

  get activity() {
    return this.args.model.activity;
  }

  get chatName() {
    return this.activity.chat?.name;
  }

  @action
  choose(choice) {
    this.chatChoice = choice;
  }

  @action
  async confirm() {
    this.flash = null;
    this.isSubmitting = true;

    try {
      await ajax(
        `/kuu-buddy/activities/${this.activity.topic_id}/status.json`,
        {
          type: "PUT",
          data: { status: "ended", close_chat: this.chatChoice === "close" },
        }
      );
      this.args.closeModal();
      this.toasts.success({
        duration: "long",
        data: { message: i18n("kuu_buddy.actions.changed.ended") },
      });
      this.router.refresh();
    } catch (error) {
      this.flash = extractError(error);
    } finally {
      this.isSubmitting = false;
    }
  }

  <template>
    <DModal
      class="kuu-buddy-end-modal"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @flashType="error"
      @title={{i18n "kuu_buddy.end.title"}}
    >
      <:body>
        <p class="kuu-buddy-end-modal__intro">{{i18n "kuu_buddy.end.intro"}}</p>

        {{#if this.chatName}}
          <fieldset class="kuu-buddy-end-modal__chat">
            <legend>
              {{i18n "kuu_buddy.end.chat_question" name=this.chatName}}
            </legend>
            {{#each this.chatChoices as |choice|}}
              <label
                class="kuu-buddy-end-modal__choice
                  {{if (eq this.chatChoice choice) '--selected'}}"
              >
                <input
                  checked={{eq this.chatChoice choice}}
                  name="kuu-buddy-chat-choice"
                  type="radio"
                  value={{choice}}
                  {{on "change" (fn this.choose choice)}}
                />
                <span class="kuu-buddy-end-modal__choice-text">
                  <strong>{{i18n
                      (concat "kuu_buddy.end.chat_" choice "_label")
                    }}</strong>
                  <span>{{i18n
                      (concat "kuu_buddy.end.chat_" choice "_hint")
                    }}</span>
                </span>
              </label>
            {{/each}}
          </fieldset>
        {{/if}}
      </:body>

      <:footer>
        <DButton
          class="btn-flat"
          @action={{@closeModal}}
          @label="kuu_buddy.end.not_yet"
        />
        <DButton
          class="btn-primary kuu-buddy-end-modal__confirm"
          @action={{this.confirm}}
          @isLoading={{this.isSubmitting}}
          @label="kuu_buddy.end.confirm"
        />
      </:footer>
    </DModal>
  </template>
}
