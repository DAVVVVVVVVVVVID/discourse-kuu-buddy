# frozen_string_literal: true

module DiscourseKuuBuddy
  # 申请加入（界面 4）：可以写一句话（选填），发起人收到站内通知。
  # 每人每帖只能有一个进行中的申请；被婉拒、被移出过的不能再申请
  class Activity::Apply
    include Service::Base

    params do
      attribute :topic_id, :integer
      attribute :message, :string, default: ""

      validates :topic_id, presence: true
      validates :message, length: { maximum: Application::MESSAGE_MAX_LENGTH }

      def message_text
        message.to_s.squish
      end
    end

    model :activity
    policy :can_apply
    policy :not_applied
    policy :not_barred
    policy :within_daily_limit, class_name: Activity::Policy::WithinDailyApplicationLimit
    model :application, :create_application
    step :notify_organizer
    step :publish_changes

    private

    def fetch_activity(params:)
      Activity.includes(:topic).find_by(topic_id: params.topic_id)
    end

    def can_apply(guardian:, activity:)
      guardian.can_apply_to_kuu_buddy_activity?(activity)
    end

    def not_applied(guardian:, activity:)
      !activity.applications.in_progress.exists?(user: guardian.user)
    end

    def not_barred(guardian:, activity:)
      !activity.applications.exists?(user: guardian.user, status: Application::BARRED_STATUSES)
    end

    def create_application(guardian:, activity:, params:)
      activity.applications.create(
        user: guardian.user,
        status: "pending",
        message: params.message_text,
      )
    end

    def notify_organizer(guardian:, activity:)
      Activity::Action::Notify.call(
        activity:,
        user: activity.organizer,
        message: "applied",
        actor: guardian.user,
      )
    end

    def publish_changes(activity:)
      Activity::Action::PublishChanges.call(activity:)
    end
  end
end
