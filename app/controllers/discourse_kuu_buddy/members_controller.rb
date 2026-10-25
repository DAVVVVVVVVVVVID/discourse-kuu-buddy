# frozen_string_literal: true

module DiscourseKuuBuddy
  # 成员自己退出、发起人移出成员，都同时移出群聊
  class MembersController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    def leave
      Activity::Leave.call(service_params) do
        on_success { |activity:| render_activity(activity) }
        on_failed_contract { raise Discourse::InvalidParameters }
        on_model_not_found(:activity) { raise Discourse::NotFound }
        on_failed_policy(:activity_in_category) { raise Discourse::NotFound }
        on_model_not_found(:membership) { raise Discourse::NotFound }
        on_failed_policy(:not_ended) { render_ended }
      end
    end

    def remove
      Activity::RemoveMember.call(service_params) do
        on_success { |activity:| render_activity(activity) }
        on_failed_contract { raise Discourse::InvalidParameters }
        on_model_not_found(:activity) { raise Discourse::NotFound }
        on_failed_policy(:activity_in_category) { raise Discourse::NotFound }
        on_failed_policy(:can_manage) { raise Discourse::InvalidAccess }
        on_model_not_found(:membership) { raise Discourse::NotFound }
        on_failed_policy(:not_ended) { render_ended }
      end
    end

    private

    def render_activity(activity)
      render json: {
               activity:
                 TopicActivitySerializer.new(activity.reload, scope: guardian, root: false).as_json,
             }
    end

    def render_ended
      render(
        json: failed_json.merge(errors: [I18n.t("kuu_buddy.errors.activity_ended")]),
        status: :unprocessable_content,
      )
    end
  end
end
