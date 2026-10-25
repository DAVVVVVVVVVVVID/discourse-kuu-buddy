# frozen_string_literal: true

module DiscourseKuuBuddy
  # 帖子页用：状态、四行信息、成员、自己的申请、发起人的按钮和申请列表、群聊入口，
  # 以及修改表单回填的字段。申请列表只给发起人和管理员；群聊只给发起人和成员
  class TopicActivitySerializer < ActivitySerializer
    attributes :can_manage,
               :statuses_reachable,
               :expires_at,
               :organizer,
               :members,
               :can_apply,
               :my_application,
               :applications,
               :chat

    def can_manage
      @can_manage ||= scope.can_manage_kuu_buddy_activity?(object)
    end

    def statuses_reachable
      object.statuses_reachable
    end

    def include_statuses_reachable?
      can_manage
    end

    def include_expires_at?
      can_manage && object.recruiting?
    end

    def organizer
      user_json(object.organizer)
    end

    # 已加入的成员所有人都能看到；有没有进群聊只告诉发起人（拉不进去时提示）
    def members
      object
        .members
        .includes(:user)
        .map do |membership|
          json = user_json(membership.user)
          json[:in_chat] = membership.in_chat if can_manage
          json
        end
    end

    # 最近一次是撤回或退出的可以再申请；等待中、已加入、被婉拒、被移出的不行
    def can_apply
      scope.can_apply_to_kuu_buddy_activity?(object) &&
        (own_application.nil? || own_application.withdrawn? || own_application.left?)
    end

    # 自己最近一次申请，决定底部显示「申请加入」「已申请，等发起人确认」「退出」还是别的
    def my_application
      return if own_application.nil?

      { id: own_application.id, status: own_application.status, message: own_application.message }
    end

    def include_my_application?
      scope.authenticated?
    end

    def applications
      object
        .applications
        .pending
        .ordered
        .includes(:user)
        .map do |application|
          {
            id: application.id,
            user: user_json(application.user),
            message: application.message,
            created_at: application.created_at,
          }
        end
    end

    def include_applications?
      can_manage
    end

    # 群聊卡片（界面 6）：群名、最新一条消息、「进群」
    def chat
      channel = object.chat_channel
      return if channel.nil? || channel.trashed?

      # 用原文截短，前端按纯文字显示（chat 存的 excerpt 是转义过的 HTML）
      last_message = Chat::Message.includes(:user).find_by(id: channel.last_message_id)
      {
        id: channel.id,
        name: channel.name,
        closed: object.chat_closed,
        last_message:
          if last_message
            {
              excerpt: last_message.message.truncate(60),
              username: last_message.user&.username,
              created_at: last_message.created_at,
            }
          end,
      }
    end

    def include_chat?
      object.chat_channel_id.present? &&
        (can_manage || own_application&.accepted? || chat_joined_by_viewer?)
    end

    private

    def own_application
      return @own_application if defined?(@own_application)

      @own_application =
        scope.user && object.applications.where(user: scope.user).order(:created_at, :id).last
    end

    # 活动结束后成员身份还在；但保留下来的群聊也可能有发起人后来拉进去的人，进了群的也能看到入口
    def chat_joined_by_viewer?
      scope.user &&
        Chat::UserChatChannelMembership.exists?(
          user: scope.user,
          chat_channel_id: object.chat_channel_id,
        )
    end

    def user_json(user)
      BasicUserSerializer.new(user, root: false).as_json if user
    end
  end
end
