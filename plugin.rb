# frozen_string_literal: true

# name: discourse-kuu-buddy
# about: 搭子广场：用专门的表单发帖找搭子，别人申请加入，发起人接受后自动建群聊
# version: 0.0.1
# authors: DAVVVVVVVVVVVID
# url: https://github.com/DAVVVVVVVVVVVID/discourse-kuu-buddy
# required_version: 2026.1.0

enabled_site_setting :kuu_buddy_enabled

register_asset "stylesheets/common/kuu-buddy.scss"

register_svg_icon "user-group"
register_svg_icon "clock-rotate-left"
register_svg_icon "flag-checkered"
register_svg_icon "rotate-left"

module ::DiscourseKuuBuddy
  PLUGIN_NAME = "discourse-kuu-buddy"

  def self.buddy_category?(category_id)
    buddy_category_id = SiteSetting.kuu_buddy_category.to_i
    buddy_category_id > 0 && category_id.to_i == buddy_category_id
  end
end

require_relative "lib/discourse_kuu_buddy/engine"

after_initialize do
  reloadable_patch do
    Topic.has_one :kuu_buddy_activity,
                  class_name: "DiscourseKuuBuddy::Activity",
                  dependent: :destroy,
                  autosave: true
  end

  # 移出搭子广场的帖子不再受插件管理
  add_to_class(:topic, :kuu_buddy_activity_in_category) do
    kuu_buddy_activity if DiscourseKuuBuddy.buddy_category?(category_id)
  end

  register_topic_preloader_associations(:kuu_buddy_activity) { SiteSetting.kuu_buddy_enabled }

  # 已结束的帖子是隐藏话题，列表和搜索里都没有；但发起人主页的「话题」里所有人都能看到（Issue #1）。
  # 只在这个列表、只在 core 按 visible 过滤了的时候把它们加回来，过期的不加
  register_modifier(:topic_query_create_list_topics) do |topics, options, _topic_query|
    next topics if !SiteSetting.kuu_buddy_enabled
    next topics if options[:filter] != :user_topics || options[:visible] != true

    DiscourseKuuBuddy::Activity.with_ended_visible(topics)
  end

  # 发起人和管理员可以随时修改帖子、切换状态，不受编辑时限限制；发起人被禁言时不行
  add_to_class(:guardian, :can_manage_kuu_buddy_activity?) do |activity|
    topic = activity.topic
    return false if anonymous? || topic.nil? || topic.trashed? || !can_see?(topic)
    return true if is_staff?

    topic.user_id == user.id && !user.silenced?
  end

  add_to_serializer(
    :topic_view,
    :kuu_buddy_activity,
    include_condition: -> { object.topic.kuu_buddy_activity_in_category.present? },
  ) do
    DiscourseKuuBuddy::TopicActivitySerializer.new(
      object.topic.kuu_buddy_activity_in_category,
      scope:,
      root: false,
    ).as_json
  end

  # 列表卡片用（界面 1）。只给搭子帖加，记录已经批量预加载
  add_to_serializer(
    :topic_list_item,
    :kuu_buddy_card,
    include_condition: -> { object.kuu_buddy_activity_in_category.present? },
  ) do
    activity = object.kuu_buddy_activity_in_category
    {
      status: activity.status,
      start_reason: activity.start_reason,
      schedule: activity.schedule,
      requirements: activity.requirements,
      capacity: activity.capacity,
      member_count: activity.member_count,
    }
  end

  # 搭子广场页顶部的筛选（界面 1）：网址里的 kuu_buddy。不认识的值、没登录时的「我发起的」不筛选
  TopicQuery.add_custom_filter(:kuu_buddy) do |results, topic_query|
    next results if !SiteSetting.kuu_buddy_enabled

    DiscourseKuuBuddy::Activity.filter_list(
      results,
      topic_query.options[:kuu_buddy],
      user: topic_query.user,
    )
  end

  NewPostManager.add_handler(100) { |manager| DiscourseKuuBuddy::NewTopicRules.check(manager) }

  # 需要审核的帖子，批准时由 core 按审核记录里存的参数建帖
  NewPostManager.add_plugin_payload_attribute(DiscourseKuuBuddy::NewTopicRules::ACTIVITY_ARG)

  # 发帖和审核通过建帖都会触发，搭子帖记录和话题在同一个事务里保存
  on(:before_create_topic) do |topic, creator|
    attributes = creator.opts[DiscourseKuuBuddy::NewTopicRules::ACTIVITY_ARG]
    if attributes.present? && DiscourseKuuBuddy.buddy_category?(topic.category_id)
      topic.kuu_buddy_activity = DiscourseKuuBuddy::Activity.open(attributes)
    end
  end

  on(:topic_category_changed) do |topic, _old_category|
    DiscourseKuuBuddy::Activity::FollowCategoryChange.call(params: { topic_id: topic.id })
  end

  # 排在 core 的标题校验之后、valid? 得出结果之前；after_validation 太晚
  add_model_callback(:topic, :validate) do
    DiscourseKuuBuddy::FormSubmission.forgive_title_errors(self)
    DiscourseKuuBuddy::EditRules.check_topic(self)
  end

  add_model_callback(:post, :validate) { DiscourseKuuBuddy::EditRules.check_post(self) }
end
