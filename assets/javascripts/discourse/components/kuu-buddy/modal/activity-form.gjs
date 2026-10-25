import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import {
  DESCRIPTION_MAX_LENGTH,
  formDataFor,
  maxCapacity,
  MIN_CAPACITY,
  payloadFrom,
  REQUIREMENTS_MAX_LENGTH,
  SCHEDULE_MAX_LENGTH,
  TITLE_MAX_LENGTH,
} from "../../../lib/kuu-buddy.js";
import CapacityStepper from "../capacity-stepper.gjs";

// 发起找搭子（界面 2），发帖和修改共用。@model.activity 有值时是修改，提交后刷新帖子页
export default class ActivityForm extends Component {
  @service router;
  @service siteSettings;
  @service toasts;

  @tracked flash;
  @tracked isSubmitting = false;

  descriptionValidation = `length:0,${DESCRIPTION_MAX_LENGTH}`;
  formData = formDataFor(this.args.model.activity);
  requirementsValidation = `length:0,${REQUIREMENTS_MAX_LENGTH}`;
  scheduleValidation = `required:trim|length:1,${SCHEDULE_MAX_LENGTH}`;
  titleValidation = `required:trim|length:1,${TITLE_MAX_LENGTH}`;

  #formApi;

  get isEditing() {
    return !!this.args.model.activity;
  }

  get title() {
    return this.isEditing
      ? i18n("kuu_buddy.form.edit_title")
      : i18n("kuu_buddy.form.new_title");
  }

  // 修改时人数不能少于已经加入的人
  get minCapacity() {
    return Math.max(this.args.model.activity?.member_count ?? 0, MIN_CAPACITY);
  }

  get maxCapacity() {
    return Math.max(maxCapacity(this.siteSettings), this.minCapacity);
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
      if (this.isEditing) {
        await this.#update(data);
      } else {
        await this.#create(data);
      }
    } catch (error) {
      this.flash = extractError(error);
    } finally {
      this.isSubmitting = false;
    }
  }

  async #create(data) {
    const result = await ajax("/kuu-buddy/activities.json", {
      type: "POST",
      contentType: "application/json",
      data: JSON.stringify(payloadFrom(data)),
    });

    this.args.closeModal();

    if (result.action === "enqueued") {
      this.toasts.success({
        data: { message: i18n("kuu_buddy.form.pending_approval") },
      });
    } else {
      DiscourseURL.routeTo(result.post.post_url);
    }
  }

  async #update(data) {
    await ajax(
      `/kuu-buddy/activities/${this.args.model.activity.topic_id}.json`,
      {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify(payloadFrom(data)),
      }
    );

    this.args.closeModal();
    this.router.refresh();
  }

  <template>
    <DModal
      class="kuu-buddy-form-modal"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @flashType="error"
      @title={{this.title}}
    >
      <:body>
        <Form
          class="kuu-buddy-form"
          @data={{this.formData}}
          @onRegisterApi={{this.registerApi}}
          @onSubmit={{this.submit}}
          as |form|
        >
          <form.Field
            @format="full"
            @name="title"
            @title={{i18n "kuu_buddy.form.activity"}}
            @type="input"
            @validation={{this.titleValidation}}
            as |field|
          >
            <field.Control
              placeholder={{i18n "kuu_buddy.form.activity_placeholder"}}
            />
          </form.Field>

          <form.Field
            @format="full"
            @name="capacity"
            @title={{i18n "kuu_buddy.form.capacity"}}
            @type="custom"
            @validation="required"
            as |field|
          >
            <field.Control>
              <CapacityStepper
                @max={{this.maxCapacity}}
                @min={{this.minCapacity}}
                @onChange={{field.set}}
                @value={{field.value}}
              />
            </field.Control>
          </form.Field>

          <form.Field
            @format="full"
            @name="schedule"
            @title={{i18n "kuu_buddy.form.schedule"}}
            @type="input"
            @validation={{this.scheduleValidation}}
            as |field|
          >
            <field.Control
              placeholder={{i18n "kuu_buddy.form.schedule_placeholder"}}
            />
          </form.Field>

          <form.Field
            @format="full"
            @name="requirements"
            @title={{i18n "kuu_buddy.form.requirements"}}
            @type="input"
            @validation={{this.requirementsValidation}}
            as |field|
          >
            <field.Control
              placeholder={{i18n "kuu_buddy.form.requirements_placeholder"}}
            />
          </form.Field>

          <form.Field
            @format="full"
            @helpText={{i18n "kuu_buddy.form.privacy_hint"}}
            @name="description"
            @title={{i18n "kuu_buddy.form.description"}}
            @type="textarea"
            @validation={{this.descriptionValidation}}
            as |field|
          >
            <field.Control @height={{100}} />
          </form.Field>
        </Form>

        {{#unless this.isEditing}}
          <p class="kuu-buddy-form-modal__tip">
            {{i18n "kuu_buddy.form.chat_tip"}}
          </p>
        {{/unless}}
      </:body>

      <:footer>
        <DButton
          class="btn-primary kuu-buddy-form-modal__submit"
          @action={{this.submitForm}}
          @isLoading={{this.isSubmitting}}
          @label={{if
            this.isEditing
            "kuu_buddy.form.save"
            "kuu_buddy.form.publish"
          }}
        />
        <DButton class="btn-flat" @action={{@closeModal}} @label="cancel" />
      </:footer>
    </DModal>
  </template>
}
