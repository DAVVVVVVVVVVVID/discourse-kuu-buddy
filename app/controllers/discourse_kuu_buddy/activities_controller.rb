# frozen_string_literal: true

module DiscourseKuuBuddy
  class ActivitiesController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    def create
      Activity::Create.call(service_params) do
        on_success do |new_post_result:|
          render json: serialize_data(new_post_result, NewPostResultSerializer, root: false)
        end
        on_failed_contract { |contract| render_errors(contract.errors, :bad_request) }
        on_model_not_found(:category) { raise Discourse::NotFound }
        on_failed_policy(:can_create_topic_in_category) { raise Discourse::InvalidAccess }
        on_model_errors(:activity) { |activity| render_errors(activity.errors) }
        on_exceptions(RateLimiter::LimitExceeded) { |exception| raise exception }
        on_failed_step(:publish_activity) do |step|
          render(json: failed_json.merge(errors: [step.error]), status: :unprocessable_content)
        end
      end
    end

    def update
      Activity::Update.call(service_params) do
        on_success { head :no_content }
        on_model_not_found(:activity) { raise Discourse::NotFound }
        on_failed_contract { |contract| render_errors(contract.errors, :bad_request) }
        on_failed_policy(:activity_in_category) { raise Discourse::NotFound }
        on_failed_policy(:can_edit_activity) { raise Discourse::InvalidAccess }
        on_model_errors(:revised_activity) { |activity| render_errors(activity.errors) }
        on_failed_step(:revise_first_post) do |step|
          render(json: failed_json.merge(errors: [step.error]), status: :unprocessable_content)
        end
      end
    end

    def update_status
      Activity::ChangeStatus.call(service_params) do
        on_success do |activity:|
          render json: {
                   activity:
                     TopicActivitySerializer.new(activity, scope: guardian, root: false).as_json,
                 }
        end
        on_failed_contract { |contract| render_errors(contract.errors, :bad_request) }
        on_model_not_found(:activity) { raise Discourse::NotFound }
        on_failed_policy(:activity_in_category) { raise Discourse::NotFound }
        on_failed_policy(:can_change_status) { raise Discourse::InvalidAccess }
        on_failed_policy(:status_reachable) do
          render_error_message("kuu_buddy.errors.status_unreachable")
        end
      end
    end

    private

    def render_errors(errors, status = :unprocessable_content)
      render(json: failed_json.merge(errors: errors.full_messages), status:)
    end

    def render_error_message(key, status = :unprocessable_content)
      render(json: failed_json.merge(errors: [I18n.t(key)]), status:)
    end
  end
end
