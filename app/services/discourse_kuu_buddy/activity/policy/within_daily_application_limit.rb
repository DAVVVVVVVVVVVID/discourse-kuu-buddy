# frozen_string_literal: true

module DiscourseKuuBuddy
  # 每次申请都会通知发起人，所以同一个帖子每人每天申请 + 撤回合计只能做几次。
  # 「每天」按日本时间 0 点清零，和二手插件的举手一样
  class Activity::Policy::WithinDailyApplicationLimit < Service::PolicyBase
    TIME_ZONE = "Asia/Tokyo"

    delegate :activity, to: :context, private: true

    def self.day_start(at = Time.zone.now)
      at.in_time_zone(TIME_ZONE).beginning_of_day
    end

    def call
      Application.actions_since(activity:, user: guardian.user, since: self.class.day_start) <
        SiteSetting.kuu_buddy_application_actions_per_day
    end

    def reason
      I18n.t("kuu_buddy.errors.too_many_application_actions")
    end
  end
end
