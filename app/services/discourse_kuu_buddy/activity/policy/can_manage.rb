# frozen_string_literal: true

module DiscourseKuuBuddy
  class Activity::Policy::CanManage < Service::PolicyBase
    delegate :activity, to: :context, private: true

    def call
      guardian.can_manage_kuu_buddy_activity?(activity)
    end

    def reason
      I18n.t("kuu_buddy.errors.cannot_manage")
    end
  end
end
