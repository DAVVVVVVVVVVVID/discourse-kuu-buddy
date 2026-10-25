# frozen_string_literal: true

module DiscourseKuuBuddy
  # 搭子帖被移出搭子广场时撤销插件做过的隐藏，移回来时按状态重新隐藏。
  # 在 core 改分类的事务里运行；改分类本身会通知浏览器刷新
  class Activity::FollowCategoryChange
    include Service::Base

    params do
      attribute :topic_id, :integer

      validates :topic_id, presence: true
    end

    model :activity

    transaction do
      step :sync_topic
      step :save_activity
    end

    private

    def fetch_activity(params:)
      Activity.includes(topic: :first_post).find_by(topic_id: params.topic_id)
    end

    def sync_topic(activity:)
      Activity::Action::SyncTopic.call(activity:)
    end

    def save_activity(activity:)
      activity.save!
    end
  end
end
