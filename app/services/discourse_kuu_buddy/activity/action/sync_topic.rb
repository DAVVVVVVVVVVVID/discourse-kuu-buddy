# frozen_string_literal: true

module DiscourseKuuBuddy
  # 按搭子帖的状态隐藏 / 公开话题，不留「此话题已隐藏」之类的系统小帖（照二手插件的做法，
  # core 的 TopicStatusUpdater 一定会发小帖，所以这里照着它补做连带的数据更新）。
  # 回复不关：活动结束后大家可能还想在帖子下面聊。
  # 插件只公开自己隐藏的：管理员手动隐藏过的话题保持原样。移出搭子广场的帖子撤销插件的隐藏。
  # 只改数据库；改了 activity 上的标记，由调用方保存。通知浏览器刷新也由调用方在事务外做
  class Activity::Action::SyncTopic < Service::ActionBase
    option :activity

    delegate :topic, to: :activity, private: true

    def call
      if !activity.in_category? || !activity.hidden?
        return if !activity.unlisted_by_plugin

        make_visible(true) if !topic.visible
        activity.unlisted_by_plugin = false
      elsif topic.visible
        make_visible(false)
        activity.unlisted_by_plugin = true
      end
    end

    private

    def make_visible(visible)
      topic.update_columns(visible:, visibility_reason_id: Topic.visibility_reasons[:unknown])
      topic.update_category_topic_count_by(visible ? 1 : -1)
      UserStatCountUpdater.public_send(visible ? :increment! : :decrement!, topic.first_post)
      return if visible

      UserProfile.remove_featured_topic_from_all_profiles(topic)
      CategoryFeaturedTopic.where(topic_id: topic.id).delete_all
      TopicHotScore.where(topic_id: topic.id).delete_all
    end
  end
end
