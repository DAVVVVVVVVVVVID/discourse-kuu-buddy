# frozen_string_literal: true

module DiscourseKuuBuddy
  # 按表单内容生成标题和第一楼的 Markdown。标题就是活动内容；正文是完整的帖子内容，
  # 邮件通知、搜索、RSS 和插件关掉以后都靠它显示
  class ActivityRenderer
    MARKDOWN_SPECIAL_CHARS = /([\\`*_{}\[\]<>()#+\-.!|~])/

    def initialize(activity)
      @activity = activity
    end

    def title
      @activity.title
    end

    def raw
      in_site_locale { [fields_markdown, @activity.description.strip].compact_blank.join("\n\n") }
    end

    private

    def fields_markdown
      fields = {
        schedule: escape(@activity.schedule),
        capacity: t("capacity", count: @activity.capacity),
        requirements:
          @activity.requirements.present? ? escape(@activity.requirements) : t("no_requirements"),
      }

      fields.map { |name, value| t("field_line", label: t("fields.#{name}"), value:) }.join("\n")
    end

    def escape(text)
      text.to_s.gsub(MARKDOWN_SPECIAL_CHARS, '\\\\\1')
    end

    def t(key, **args)
      I18n.t("kuu_buddy.activity.#{key}", **args)
    end

    def in_site_locale(&)
      I18n.with_locale(SiteSetting.default_locale, &)
    end
  end
end
