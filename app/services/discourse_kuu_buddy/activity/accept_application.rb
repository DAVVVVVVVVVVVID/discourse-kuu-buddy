# frozen_string_literal: true

module DiscourseKuuBuddy
  # 发起人接受申请（界面 5「接受，拉进群聊」）：成为成员，拉进群聊（第一次接受时建群），
  # 申请人收到站内通知。人数凑满时活动自动开始。
  # 拉不进群聊（对方关了私聊、屏蔽了发起人等）时照样成为成员，由 chat_delivery 告诉前端提示
  class Activity::AcceptApplication
    include Service::Base

    params do
      attribute :topic_id, :integer
      attribute :application_id, :integer

      validates :topic_id, :application_id, presence: true
    end

    model :activity
    policy :activity_in_category
    policy :can_manage, class_name: Activity::Policy::CanManage
    model :application
    policy :has_spot

    transaction do
      step :accept
      step :follow_member_count
      step :save_activity
    end

    step :add_to_chat
    step :notify_applicant
    step :publish_changes

    private

    def fetch_activity(params:)
      Activity.includes(:topic).find_by(topic_id: params.topic_id)
    end

    def activity_in_category(activity:)
      activity.in_category? && !activity.topic_deleted?
    end

    def fetch_application(activity:, params:)
      activity.applications.pending.includes(:user).find_by(id: params.application_id)
    end

    def has_spot(activity:)
      activity.accepting_applications?
    end

    def accept(application:)
      application.update!(status: "accepted", decided_at: Time.zone.now)
    end

    def follow_member_count(activity:)
      activity.members.reset
      activity.follow_member_count
    end

    def save_activity(activity:)
      activity.save!
    end

    def add_to_chat(activity:, application:)
      context[:chat_delivery] = Activity::Action::AddToChat.call(activity:, user: application.user)
      application.update!(in_chat: true) if context[:chat_delivery] == :joined
    end

    def notify_applicant(activity:, application:)
      Activity::Action::Notify.call(activity:, user: application.user, message: "accepted")
    end

    def publish_changes(activity:)
      Activity::Action::PublishChanges.call(activity:)
    end
  end
end
