# frozen_string_literal: true

module DiscourseKuuBuddy
  # 搭子广场的新话题只能用插件的表单发（表单接口会带上 ACTIVITY_ARG）。
  # 网页编辑器、API、邮件发帖都经过 NewPostManager，在这里拦下；管理员照常能用普通编辑器
  module NewTopicRules
    ACTIVITY_ARG = :kuu_buddy_activity

    def self.check(manager)
      return if !SiteSetting.kuu_buddy_enabled

      args = manager.args
      return if args[:topic_id].present? || args[ACTIVITY_ARG].present?
      return if manager.user.staff?
      return if !DiscourseKuuBuddy.buddy_category?(args[:category])

      result = NewPostResult.new(:created_post, false)
      result.errors.add(:base, I18n.t("kuu_buddy.errors.use_buddy_form"))
      result
    end
  end
end
