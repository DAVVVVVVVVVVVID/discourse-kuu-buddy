# frozen_string_literal: true

module DiscourseKuuBuddy
  # 申请加入、撤回（申请人），接受、婉拒（发起人）。成功时返回帖子页用的搭子帖数据，前端直接换上
  class ApplicationsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    def create
      Activity::Apply.call(service_params) do
        on_success { |activity:| render_activity(activity) }
        on_failed_contract { |contract| render_errors(contract.errors.full_messages, :bad_request) }
        on_model_not_found(:activity) { raise Discourse::NotFound }
        on_failed_policy(:can_apply) { raise Discourse::InvalidAccess }
        on_failed_policy(:not_applied) { render_error_message("kuu_buddy.errors.already_applied") }
        on_failed_policy(:not_barred) do
          render_error_message("kuu_buddy.errors.cannot_apply_again")
        end
        on_failed_policy(:within_daily_limit) do |policy|
          render_errors([policy.reason], :too_many_requests)
        end
        on_model_errors(:application) do |application|
          render_errors(application.errors.full_messages)
        end
      end
    end

    def withdraw
      Activity::WithdrawApplication.call(service_params) do
        on_success { |activity:| render_activity(activity) }
        on_failed_contract { |contract| render_errors(contract.errors.full_messages, :bad_request) }
        on_model_not_found(:activity) { raise Discourse::NotFound }
        on_model_not_found(:application) { raise Discourse::NotFound }
        on_failed_policy(:within_daily_limit) do |policy|
          render_errors([policy.reason], :too_many_requests)
        end
      end
    end

    def accept
      Activity::AcceptApplication.call(service_params) do
        on_success { |activity:, chat_delivery:| render_activity(activity, chat_delivery:) }
        on_failed_contract { |contract| render_errors(contract.errors.full_messages, :bad_request) }
        on_model_not_found(:activity) { raise Discourse::NotFound }
        on_failed_policy(:activity_in_category) { raise Discourse::NotFound }
        on_failed_policy(:can_manage) { raise Discourse::InvalidAccess }
        on_model_not_found(:application) { raise Discourse::NotFound }
        on_failed_policy(:has_spot) { render_error_message("kuu_buddy.errors.no_spot") }
      end
    end

    def decline
      Activity::DeclineApplication.call(service_params) do
        on_success { |activity:| render_activity(activity) }
        on_failed_contract { |contract| render_errors(contract.errors.full_messages, :bad_request) }
        on_model_not_found(:activity) { raise Discourse::NotFound }
        on_failed_policy(:activity_in_category) { raise Discourse::NotFound }
        on_failed_policy(:can_manage) { raise Discourse::InvalidAccess }
        on_model_not_found(:application) { raise Discourse::NotFound }
      end
    end

    private

    def render_activity(activity, **extra)
      render json: {
               activity:
                 TopicActivitySerializer.new(activity.reload, scope: guardian, root: false).as_json,
               **extra,
             }
    end

    def render_errors(messages, status = :unprocessable_content)
      render(json: failed_json.merge(errors: messages), status:)
    end

    def render_error_message(key)
      render_errors([I18n.t(key)])
    end
  end
end
