# frozen_string_literal: true

module DiscourseKuuBuddy
  # 有人在 chat 里自己离开了活动的群聊（chat 删掉了这个人的群聊成员记录）：
  # - 成员：当作在帖子上退出，人满自动开始的活动人数不满时回到招募中
  # - 发起人：插件没法再往这个群里拉人了，忘掉这个群聊，下次接受申请时重新建一个
  # 在帖子上退出、被移出时插件自己让成员离开群聊，也会走到这里，那时成员身份已经改过了，什么都不做。
  # 活动结束以后群聊不归插件管
  class Activity::SyncChatLeave
    include Service::Base

    params do
      attribute :channel_id, :integer
      attribute :user_id, :integer

      validates :channel_id, :user_id, presence: true
    end

    model :activity
    model :user

    transaction do
      only_if(:organizer_left) { step :forget_chat }
      only_if(:member_left) do
        step :leave
        step :follow_member_count
      end
      step :save_activity
    end

    step :publish_changes

    private

    def fetch_activity(params:)
      Activity.managing_chat(params.channel_id).includes(:topic).first
    end

    def fetch_user(params:)
      User.find_by(id: params.user_id)
    end

    def organizer_left(activity:, user:)
      activity.topic&.user_id == user.id
    end

    def forget_chat(activity:)
      activity.chat_channel_id = nil
      activity.applications.accepted.update_all(in_chat: false)
    end

    def member_left(activity:, user:)
      context[:membership] = activity.applications.accepted.find_by(user:)
      context[:membership].present?
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

    def publish_changes(activity:)
      Activity::Action::PublishChanges.call(activity:)
    end
  end
end
