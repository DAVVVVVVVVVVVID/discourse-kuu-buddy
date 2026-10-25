# frozen_string_literal: true

module DiscourseKuuBuddy
  # 搭子帖变了（状态、成员），正在看这个帖子的人刷新一下
  class Activity::Action::PublishChanges < Service::ActionBase
    option :activity

    def call
      topic = activity.topic
      MessageBus.publish(
        "/topic/#{topic.id}",
        { reload_topic: true },
        topic.secure_audience_publish_messages,
      )
    end
  end
end
