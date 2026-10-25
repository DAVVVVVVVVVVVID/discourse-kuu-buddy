# frozen_string_literal: true

module DiscourseKuuBuddy
  # 成员在帖子上退出，同时离开群聊。人满自动开始的活动，人数不满时回到招募中。
  # 活动结束以后群聊不归插件管了，不能再在帖子上退出
  class Activity::Leave
    include Service::Base

    params do
      attribute :topic_id, :integer

      validates :topic_id, presence: true
    end

    model :activity
    policy :activity_in_category
    model :membership
    policy :not_ended

    transaction do
      step :leave
      step :follow_member_count
      step :save_activity
    end

    step :leave_chat
    step :publish_changes

    private

    def fetch_activity(params:)
      Activity.includes(:topic).find_by(topic_id: params.topic_id)
    end

    def activity_in_category(activity:)
      activity.in_category? && !activity.topic_deleted?
    end

    def fetch_membership(guardian:, activity:)
      activity.applications.accepted.find_by(user: guardian.user)
    end

    def not_ended(activity:)
      !activity.ended?
    end

    def leave(membership:)
      membership.update!(status: "left", left_at: Time.zone.now, in_chat: false)
    end

    def follow_member_count(activity:)
      activity.members.reset
      activity.follow_member_count
    end

    def save_activity(activity:)
      activity.save!
    end

    def leave_chat(guardian:, activity:)
      Activity::Action::RemoveFromChat.call(activity:, user: guardian.user)
    end

    def publish_changes(activity:)
      Activity::Action::PublishChanges.call(activity:)
    end
  end
end
