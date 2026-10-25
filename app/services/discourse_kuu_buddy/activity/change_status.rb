# frozen_string_literal: true

module DiscourseKuuBuddy
  # 发起人或管理员切换搭子帖的状态：开始活动、活动结束、过期后重新开放。
  # 已结束和过期的帖子隐藏，重新开放时公开（见 SyncTopic）。
  # 活动结束时发起人选择保留还是关闭群聊（界面 7）：保留的变成普通群聊，插件不再管；
  # 关闭用 chat 的「关闭频道」，大家还能看到聊天记录，但不能再发消息
  class Activity::ChangeStatus
    include Service::Base

    params do
      attribute :topic_id, :integer
      attribute :status, :string
      attribute :close_chat, :boolean, default: false

      validates :topic_id, presence: true
      validates :status, inclusion: { in: Activity.statuses.keys - %w[expired] }
    end

    model :activity
    policy :activity_in_category
    policy :can_change_status, class_name: Activity::Policy::CanManage
    policy :status_reachable

    transaction do
      step :change_status
      step :sync_topic
      step :save_activity
    end

    only_if(:closing_chat) { step :close_chat }
    step :publish_changes

    private

    def fetch_activity(params:)
      Activity.includes(topic: :first_post).find_by(topic_id: params.topic_id)
    end

    def activity_in_category(activity:)
      activity.in_category?
    end

    def status_reachable(activity:, params:)
      activity.can_change_to?(params.status)
    end

    def change_status(activity:, params:)
      activity.change_status(params.status)
    end

    def sync_topic(activity:)
      Activity::Action::SyncTopic.call(activity:)
    end

    def save_activity(activity:)
      activity.save!
    end

    def closing_chat(activity:, params:)
      activity.ended? && params.close_chat && activity.chat_channel.present?
    end

    # chat 只允许管理员关闭频道，由系统账号代发起人做（发起人的选择已经在帖子上确认过）
    def close_chat(activity:)
      result =
        Chat::UpdateChannelStatus.call(
          guardian: Discourse.system_user.guardian,
          params: {
            channel_id: activity.chat_channel_id,
            status: "closed",
          },
        )
      activity.update!(chat_closed: true) if result.success?
    end

    def publish_changes(activity:)
      Activity::Action::PublishChanges.call(activity:)
    end
  end
end
