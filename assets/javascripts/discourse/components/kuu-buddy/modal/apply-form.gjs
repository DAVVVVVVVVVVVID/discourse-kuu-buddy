import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import { APPLICATION_MESSAGE_MAX_LENGTH } from "../../../lib/kuu-buddy.js";

// 申请加入（界面 4）：标题「申请加入「…」」、留言（选填）、只有发起人能看到的提示
export default class ApplyForm extends Component {
  @service toasts;

  @tracked flash;
  @tracked isSubmitting = false;

  formData = { message: "" };
  maxLength = APPLICATION_MESSAGE_MAX_LENGTH;
  messageValidation = `length:0,${APPLICATION_MESSAGE_MAX_LENGTH}`;

  #formApi;

  get activity() {
    return this.args.model.activity;
  }

  get title() {
    return i18n("kuu_buddy.apply.title", { title: this.activity.title });
  }

  @action
  registerApi(api) {
    this.#formApi = api;
  }

  @action
  submitForm() {
    this.#formApi.submit();
  }

  @action
  async submit(data) {
    this.flash = null;
    this.isSubmitting = true;

    try {
      const result = await ajax(
        `/kuu-buddy/activities/${this.activity.topic_id}/applications.json`,
        { type: "POST", data: { message: data.message?.trim() ?? "" } }
      );
      this.args.model.onApplied(result.activity);
      this.args.closeModal();
      this.toasts.success({
        data: { message: i18n("kuu_buddy.apply.sent") },
      });
    } catch (error) {
      this.flash = extractError(error);
    } finally {
      this.isSubmitting = false;
    }
  }

  <template>
    <DModal
      class="kuu-buddy-apply-modal"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @flashType="error"
      @title={{this.title}}
    >
      <:body>
        <Form
          class="kuu-buddy-apply-form"
          @data={{this.formData}}
          @onRegisterApi={{this.registerApi}}
          @onSubmit={{this.submit}}
          as |form|
        >
          <form.Field
            @format="full"
            @name="message"
            @title={{i18n "kuu_buddy.apply.message"}}
            @type="textarea"
            @validation={{this.messageValidation}}
            as |field|
          >
            <field.Control
              maxlength={{this.maxLength}}
              placeholder={{i18n "kuu_buddy.apply.message_placeholder"}}
              @height={{80}}
            />
          </form.Field>
        </Form>
        <p class="kuu-buddy-apply-modal__tip">
          {{i18n "kuu_buddy.apply.tip"}}
        </p>
      </:body>

      <:footer>
        <DButton class="btn-flat" @action={{@closeModal}} @label="cancel" />
        <DButton
          class="btn-primary kuu-buddy-apply-modal__submit"
          @action={{this.submitForm}}
          @isLoading={{this.isSubmitting}}
          @label="kuu_buddy.apply.submit"
        />
      </:footer>
    </DModal>
  </template>
}
