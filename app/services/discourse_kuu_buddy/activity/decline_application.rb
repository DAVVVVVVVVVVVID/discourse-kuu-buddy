# frozen_string_literal: true

module DiscourseKuuBuddy
  # 发起人婉拒申请：申请人收到委婉的站内通知（「这次没能加入，下次再约～」），不能再申请这个帖子
  class Activity::DeclineApplication
    include Service::Base

    params do
      attribute :topic_id, :integer
      attribute :application_id, :integer

      validates :topic_id, :application_id, presence: true
    end

    model :activity
    policy :activity_in_category
    policy :can_manage, class_name: Activity::Policy::CanManage
    model :application
    step :decline
    step :notify_applicant
    step :publish_changes

    private

    def fetch_activity(params:)
      Activity.includes(:topic).find_by(topic_id: params.topic_id)
    end

    def activity_in_category(activity:)
      activity.in_category? && !activity.topic_deleted?
    end

    def fetch_application(activity:, params:)
      activity.applications.pending.includes(:user).find_by(id: params.application_id)
    end

    def decline(application:)
      application.update!(status: "declined", decided_at: Time.zone.now)
    end

    def notify_applicant(activity:, application:)
      Activity::Action::Notify.call(activity:, user: application.user, message: "declined")
    end

    def publish_changes(activity:)
      Activity::Action::PublishChanges.call(activity:)
    end
  end
end
