# frozen_string_literal: true

module Jobs
  class KuuBuddyExpireActivities < ::Jobs::Scheduled
    every 1.hour

    def execute(_args)
      return if !SiteSetting.kuu_buddy_enabled

      DiscourseKuuBuddy::Activity
        .due_to_expire
        .pluck(:topic_id)
        .each { |topic_id| DiscourseKuuBuddy::Activity::Expire.call(params: { topic_id: }) }
    end
  end
end
