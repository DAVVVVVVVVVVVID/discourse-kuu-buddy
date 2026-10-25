# frozen_string_literal: true

module DiscourseKuuBuddy
  # 成员在帖子上退出、被发起人移出时，同时把这个成员移出群聊，走 chat 自己的服务：
  # - 自己退出：以成员自己的身份离开（Chat::LeaveChannel，chat 里点「离开」也是它）
  # - 被移出：chat 只允许管理员把人移出多人私聊，由系统账号代发起人做（Chat::RemoveUserFromChannel）
  # 成员早就自己离开了群聊、群聊不在了时什么都不做
  class Activity::Action::RemoveFromChat < Service::ActionBase
    option :activity
    option :user
    option :by_organizer, default: -> { false }

    def call
      channel = activity.chat_channel
      return if channel.nil? || !channel.joined_by?(user)

      if by_organizer
        Chat::RemoveUserFromChannel.call(
          guardian: Discourse.system_user.guardian,
          params: {
            channel_id: channel.id,
            user_id: user.id,
          },
        )
      else
        Chat::LeaveChannel.call(guardian: user.guardian, params: { channel_id: channel.id })
      end
    end
  end
end
