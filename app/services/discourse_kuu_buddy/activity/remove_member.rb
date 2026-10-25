# frozen_string_literal: true

module DiscourseKuuBuddy
  # 发起人在帖子上移出成员（界面 5），同时把这个成员移出群聊；被移出的人不能再申请这个帖子。
  # 人满自动开始的活动，人数不满时回到招募中
  class Activity::RemoveMember
    include Service::Base

    params do
      attribute :topic_id, :integer
      attribute :user_id, :integer

      validates :topic_id, :user_id, presence: true
    end

    model :activity
    policy :activity_in_category
    policy :can_manage, class_name: Activity::Policy::CanManage
    model :membership
    policy :not_ended

    transaction do
      step :remove
      step :follow_member_count
      step :save_activity
    end

    step :remove_from_chat
    step :publish_changes

    private

    def fetch_activity(params:)
      Activity.includes(:topic).find_by(topic_id: params.topic_id)
    end

    def activity_in_category(activity:)
      activity.in_category? && !activity.topic_deleted?
    end

    def fetch_membership(activity:, params:)
      activity.applications.accepted.includes(:user).find_by(user_id: params.user_id)
    end

    def not_ended(activity:)
      !activity.ended?
    end

    def remove(membership:)
      membership.update!(status: "removed", left_at: Time.zone.now, in_chat: false)
    end

    def follow_member_count(activity:)
      activity.members.reset
      activity.follow_member_count
    end

    def save_activity(activity:)
      activity.save!
    end

    def remove_from_chat(activity:, membership:)
      Activity::Action::RemoveFromChat.call(activity:, user: membership.user, by_organizer: true)
    end

    def publish_changes(activity:)
      Activity::Action::PublishChanges.call(activity:)
    end
  end
end
