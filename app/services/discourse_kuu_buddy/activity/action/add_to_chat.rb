# frozen_string_literal: true

module DiscourseKuuBuddy
  # 把被接受的人拉进活动的群聊，以发起人的身份、走 chat 自己的服务和权限检查：
  # 还没有群聊时建一个多人私聊（名字用活动内容，发起人 + 这个人），有了就加进去。返回：
  # - :joined 进群了
  # - :unavailable 这个人收不到：关了聊天或私聊、拉黑 / 屏蔽了发起人、只允许特定的人私信
  # - :failed 其他原因，比如发起人自己没有私聊权限、关了私聊、已经退出了群聊，或者站点关了聊天
  class Activity::Action::AddToChat < Service::ActionBase
    option :activity
    option :user

    delegate :organizer, to: :activity, private: true

    def call
      return :failed if !SiteSetting.chat_enabled || organizer.nil?
      return :unavailable if !organizer.guardian.recipient_can_chat?(user)

      result = channel ? add_to_channel : create_channel
      return :joined if result.success?

      result["result.policy.targets_allow_dms_from_user"]&.failure? ? :unavailable : :failed
    end

    private

    def channel
      @channel ||= activity.chat_channel
    end

    def add_to_channel
      Chat::AddUsersToChannel.call(
        guardian: organizer.guardian,
        params: {
          channel_id: channel.id,
          usernames: [user.username],
        },
      )
    end

    def create_channel
      Chat::CreateDirectMessageChannel
        .call(
          guardian: organizer.guardian,
          params: {
            target_usernames: [user.username],
            name: activity.title,
          },
        )
        .tap do |result|
          next if result.failure?

          activity.update!(chat_channel_id: result.channel.id)
          post_welcome(result.channel)
        end
    end

    # 群聊里第一条是帖子链接，以后大家从群聊也能回到帖子。以发起人的身份发：
    # 系统账号在多人私聊里发言会被加进群，占掉一个人数
    def post_welcome(channel)
      message =
        I18n.with_locale(SiteSetting.default_locale) do
          I18n.t("kuu_buddy.chat.welcome", title: activity.title, url: activity.topic.url)
        end
      Chat::CreateMessage.call(
        guardian: organizer.guardian,
        params: {
          chat_channel_id: channel.id,
          message:,
        },
      )
    end
  end
end
