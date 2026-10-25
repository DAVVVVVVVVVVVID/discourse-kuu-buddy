# frozen_string_literal: true

module DiscourseKuuBuddy
  # 发起人或管理员切换搭子帖的状态：开始活动、活动结束、过期后重新开放。
  # 已结束和过期的帖子隐藏，重新开放时公开（见 SyncTopic）
  class Activity::ChangeStatus
    include Service::Base

    params do
      attribute :topic_id, :integer
      attribute :status, :string

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

    def publish_changes(activity:)
      Activity::Action::PublishChanges.call(activity:)
    end
  end
end
