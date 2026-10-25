# frozen_string_literal: true

module DiscourseKuuBuddy
  # 用表单发搭子帖。标题就是活动内容，第一楼由插件生成；发帖照常经过 NewPostManager，
  # 屏蔽词、新用户审核、发帖频率等 core 规则都生效，需要审核时进审核队列
  class Activity::Create
    include Service::Base

    params do
      attribute :title, :string
      attribute :capacity, :integer
      attribute :schedule, :string
      attribute :requirements, :string, default: ""
      attribute :description, :string, default: ""

      validates :title, presence: true
      validates :capacity, presence: true
      validates :schedule, presence: true

      def activity_attributes
        {
          title: title&.squish,
          capacity:,
          schedule: schedule&.squish,
          requirements: requirements.to_s.squish,
          description: description.to_s.strip,
        }
      end
    end

    model :category
    policy :can_create_topic_in_category
    model :activity, :open_activity

    try(RateLimiter::LimitExceeded) { step :publish_activity }

    private

    def fetch_category
      Category.find_by(id: SiteSetting.kuu_buddy_category)
    end

    def can_create_topic_in_category(guardian:, category:)
      guardian.can_create_topic_on_category?(category)
    end

    def open_activity(params:)
      Activity.open(params.activity_attributes)
    end

    def publish_activity(guardian:, category:, activity:, params:)
      renderer = ActivityRenderer.new(activity)
      result =
        FormSubmission.submit(renderer.title) do
          NewPostManager.new(
            guardian.user,
            :title => renderer.title,
            :raw => renderer.raw,
            :category => category.id,
            :archetype => Archetype.default,
            :first_post_checks => true,
            NewTopicRules::ACTIVITY_ARG => params.activity_attributes,
          ).perform
        end

      fail!(result.errors.full_messages.join("\n")) if result.failed?
      context[:new_post_result] = result
    end
  end
end
