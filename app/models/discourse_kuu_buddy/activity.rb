# frozen_string_literal: true

module DiscourseKuuBuddy
  # 搭子帖：一个插件发的话题对应一条记录。不是插件发的帖子（比如分类的规则帖）没有记录，插件不管。
  # 人数是总人数，含发起人
  class Activity < ActiveRecord::Base
    self.table_name = "kuu_buddy_activities"

    TITLE_MAX_LENGTH = 40
    SCHEDULE_MAX_LENGTH = 40
    REQUIREMENTS_MAX_LENGTH = 100
    DESCRIPTION_MAX_LENGTH = 2000
    MIN_CAPACITY = 2

    # 招募中 →（人满或发起人点「开始活动」）→ 活动开始 →（发起人点「活动结束」）→ 已结束。
    # 招募中满期限没开始的由系统改成过期，发起人可以重新开放
    MANUAL_TRANSITIONS = {
      "recruiting" => %w[started],
      "started" => %w[ended],
      "expired" => %w[recruiting],
      "ended" => [],
    }.freeze
    HIDDEN_STATUSES = %w[ended expired].freeze

    # 网址里的 kuu_buddy（界面 1 顶部的筛选）
    LIST_FILTERS = %w[recruiting mine].freeze

    enum :status,
         { recruiting: "recruiting", started: "started", ended: "ended", expired: "expired" },
         validate: true
    # 人满自动开始的，有人退出后会回到招募中；发起人手动开始的不会
    enum :start_reason,
         { full: "full", manual: "manual" },
         prefix: :started_when,
         validate: {
           allow_nil: true,
         }

    # 表单内容在话题建出来之前就要校验，所以这里不要求 topic；数据库里 topic_id 不能为空
    belongs_to :topic, -> { with_deleted }, optional: true

    validates :topic_id, uniqueness: { allow_nil: true }
    validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH }
    validates :schedule, presence: true, length: { maximum: SCHEDULE_MAX_LENGTH }
    validates :requirements, length: { maximum: REQUIREMENTS_MAX_LENGTH }
    validates :description, length: { maximum: DESCRIPTION_MAX_LENGTH }
    validates :capacity, :recruiting_since, presence: true
    # 上限跟着 chat 的群聊人数上限走。设置调低以后，旧帖子切换状态、过期时不能因此失败，所以只在改人数时检查
    validates :capacity,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: MIN_CAPACITY,
                less_than_or_equal_to: ->(_) { max_capacity },
              },
              if: :will_save_change_to_capacity?

    # chat 的多人私聊最多 chat_max_direct_message_users 人（含发起人），见 Issue #1
    def self.max_capacity
      [SiteSetting.chat_max_direct_message_users, MIN_CAPACITY].max
    end

    def self.open(attributes)
      new(attributes).tap do |activity|
        activity.assign_attributes(status: "recruiting", recruiting_since: Time.zone.now)
      end
    end

    # 招募中满 kuu_buddy_expire_days 天的帖子（刚好满的也算）。已删除的帖子不算（见 #topic_deleted?）
    def self.due_to_expire(at: Time.zone.now)
      joins(:topic)
        .where(topics: { category_id: SiteSetting.kuu_buddy_category.to_i, deleted_at: nil })
        .where.not(topic_id: Post.where(post_number: 1, user_deleted: true).select(:topic_id))
        .recruiting
        .where("kuu_buddy_activities.recruiting_since <= ?", expiry_cutoff(at))
    end

    def self.expiry_cutoff(at)
      at - SiteSetting.kuu_buddy_expire_days.days
    end

    # 在按 visible 过滤过的话题列表里，加回插件隐藏的已结束帖子。管理员手动隐藏的仍然不显示
    def self.with_ended_visible(topics)
      topics.unscope(where: :visible).where(
        "topics.visible OR topics.id IN (?)",
        ended_by_plugin.select(:topic_id),
      )
    end

    def self.ended_by_plugin
      ended
        .where(unlisted_by_plugin: true)
        .joins(:topic)
        .where(topics: { category_id: SiteSetting.kuu_buddy_category.to_i })
    end

    # 「招募中」只去掉不在招募的搭子帖，分类里的规则帖等照常显示。
    # 「我发起的」连自己已结束、过期的帖子一起显示（它们是隐藏话题，平时列表里没有）
    def self.filter_list(topics, filter, user:)
      case filter
      when "recruiting"
        topics.where.not(id: where.not(status: "recruiting").select(:topic_id))
      when "mine"
        return topics if user.nil?

        mine = joins(:topic).where(topics: { user_id: user.id }).select(:topic_id)
        topics.unscope(where: :visible).where(id: mine)
      else
        topics
      end
    end

    # 发起人算一个人；接受的成员在第二期加上
    def member_count
      1
    end

    def spots_left
      [capacity - member_count, 0].max
    end

    def hidden?
      HIDDEN_STATUSES.include?(status)
    end

    def can_change_to?(new_status)
      MANUAL_TRANSITIONS.fetch(status, []).include?(new_status)
    end

    def statuses_reachable
      MANUAL_TRANSITIONS.fetch(status, [])
    end

    def change_status(new_status, reason: nil, at: Time.zone.now)
      self.status = new_status

      case new_status
      when "recruiting"
        # 重新开放和回到招募中，30 天过期都重新计时
        self.recruiting_since = at
        self.start_reason = nil
        self.started_at = nil
      when "started"
        self.started_at = at
        self.start_reason = reason || "manual"
      when "ended"
        self.ended_at = at
      end
    end

    def expiry_due?(at: Time.zone.now)
      recruiting? && recruiting_since <= self.class.expiry_cutoff(at)
    end

    def expires_at
      recruiting_since + SiteSetting.kuu_buddy_expire_days.days
    end

    # 删帖时记录保留，恢复帖子时原样回来；删掉期间插件不碰它。发起人自己删帖时 core 先标记第一楼、
    # 过一段时间才真正删除话题，这段时间也算已删除。永久删除话题时记录随话题删除（Topic has_one）
    def topic_deleted?
      topic.nil? || topic.trashed? || !!topic.first_post&.user_deleted
    end

    # 移出搭子广场的帖子不再受插件管理
    def in_category?
      DiscourseKuuBuddy.buddy_category?(topic&.category_id)
    end
  end
end

# == Schema Information
#
# Table name: kuu_buddy_activities
#
#  id                 :bigint           not null, primary key
#  capacity           :integer          not null
#  description        :text             default(""), not null
#  ended_at           :datetime
#  recruiting_since   :datetime         not null
#  requirements       :string           default(""), not null
#  schedule           :string           not null
#  start_reason       :string
#  started_at         :datetime
#  status             :string           not null
#  title              :string           not null
#  unlisted_by_plugin :boolean          default(FALSE), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  topic_id           :integer          not null
#
# Indexes
#
#  index_kuu_buddy_activities_on_status_and_recruiting_since  (status,recruiting_since)
#  index_kuu_buddy_activities_on_topic_id                     (topic_id) UNIQUE
#
