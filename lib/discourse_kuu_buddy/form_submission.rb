# frozen_string_literal: true

module DiscourseKuuBuddy
  # 插件的表单正在发帖或改帖。期间允许修改搭子帖的第一楼和标题（见 EditRules），
  # 并且标题可以过短、重名：活动内容就是标题，「爬山」「打麻将」过不了 core 的最短长度、
  # 标题质量、不能重名三条检查，只对这个标题去掉这三类错误，屏蔽词等其他检查照常。
  # core 改分类时也会重新检查标题，所以没改标题的搭子帖（比如管理员移动分类）同样放宽
  class FormSubmission < ActiveSupport::CurrentAttributes
    attribute :title

    LENGTH_ERRORS = %i[too_short].freeze
    QUALITY_ERRORS = %i[
      is_invalid
      is_invalid_meaningful
      is_invalid_unpretentious
      is_invalid_quiet
    ].freeze
    DUPLICATE_ERROR = :topic_title_already_used

    def self.submit(title, &)
      set(title:, &)
    end

    def self.active?
      title.present?
    end

    def self.forgive_title_errors(topic)
      return if topic.errors.empty?
      return if !(active? && topic.title == title) && !unchanged_buddy_title?(topic)

      (LENGTH_ERRORS + QUALITY_ERRORS).each { |type| topic.errors.delete(:title, type) }
      topic.errors.delete(:base, DUPLICATE_ERROR)
    end

    def self.unchanged_buddy_title?(topic)
      topic.persisted? && !topic.will_save_change_to_title? && Activity.exists?(topic_id: topic.id)
    end
  end
end
