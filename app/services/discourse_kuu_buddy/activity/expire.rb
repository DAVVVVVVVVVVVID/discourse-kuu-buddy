# frozen_string_literal: true

module DiscourseKuuBuddy
  # 系统把招募中满期限还没开始的帖子改成过期：隐藏话题，并给发起人发站内通知。
  # 时间是自由填写的一句话，没法按活动日期判断，只能按天数兜底（Issue #1）
  class Activity::Expire
    include Service::Base

    NOTIFICATION_MESSAGE = "kuu_buddy.notifications.expired"

    params do
      attribute :topic_id, :integer

      validates :topic_id, presence: true
    end

    model :activity
    policy :activity_in_category
    policy :expiry_due

    transaction do
      step :expire
      step :sync_topic
      step :save_activity
    end

    only_if(:author_present) { step :notify_author }
    step :publish_changes

    private

    def fetch_activity(params:)
      Activity.includes(topic: :first_post).find_by(topic_id: params.topic_id)
    end

    def activity_in_category(activity:)
      activity.in_category? && !activity.topic_deleted?
    end

    def expiry_due(activity:)
      activity.expiry_due?
    end

    def expire(activity:)
      activity.status = "expired"
    end

    def sync_topic(activity:)
      Activity::Action::SyncTopic.call(activity:)
    end

    def save_activity(activity:)
      activity.save!
    end

    def author_present(activity:)
      activity.topic.user.present?
    end

    def notify_author(activity:)
      topic = activity.topic
      Notification.create!(
        notification_type: Notification.types[:custom],
        user_id: topic.user_id,
        topic_id: topic.id,
        post_number: 1,
        data: { message: NOTIFICATION_MESSAGE, topic_title: topic.title }.to_json,
      )
    end

    def publish_changes(activity:)
      Activity::Action::PublishChanges.call(activity:)
    end
  end
end
