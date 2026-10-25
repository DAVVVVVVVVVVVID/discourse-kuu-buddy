# frozen_string_literal: true

module DiscourseKuuBuddy
  # 插件的站内通知（core 的 custom 类型），点开到帖子。前端按 message 显示文案和图标，
  # display_username 是通知里出现的那个人（比如申请人）
  class Activity::Action::Notify < Service::ActionBase
    MESSAGES = %w[applied accepted declined expired].freeze

    option :activity
    option :user
    option :message
    option :actor, optional: true

    def call
      raise ArgumentError, "unknown message #{message}" if MESSAGES.exclude?(message)
      return if user.nil?

      topic = activity.topic
      Notification.create!(
        notification_type: Notification.types[:custom],
        user_id: user.id,
        topic_id: topic.id,
        post_number: 1,
        data: {
          message: "kuu_buddy.notifications.#{message}",
          display_username: actor&.username,
          topic_title: topic.title,
        }.compact.to_json,
      )
    end
  end
end
