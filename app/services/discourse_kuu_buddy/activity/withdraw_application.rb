# frozen_string_literal: true

module DiscourseKuuBuddy
  # 撤回还没处理的申请。撤回以后可以再申请（和申请一起算每日次数）
  class Activity::WithdrawApplication
    include Service::Base

    params do
      attribute :topic_id, :integer

      validates :topic_id, presence: true
    end

    model :activity
    model :application
    policy :within_daily_limit, class_name: Activity::Policy::WithinDailyApplicationLimit
    step :withdraw
    step :publish_changes

    private

    def fetch_activity(params:)
      Activity.includes(:topic).find_by(topic_id: params.topic_id)
    end

    def fetch_application(guardian:, activity:)
      activity.applications.pending.find_by(user: guardian.user)
    end

    def withdraw(application:)
      application.update!(status: "withdrawn", withdrawn_at: Time.zone.now)
    end

    def publish_changes(activity:)
      Activity::Action::PublishChanges.call(activity:)
    end
  end
end
