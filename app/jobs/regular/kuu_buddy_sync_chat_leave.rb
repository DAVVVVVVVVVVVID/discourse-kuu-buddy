# frozen_string_literal: true

module Jobs
  class KuuBuddySyncChatLeave < ::Jobs::Base
    def execute(args)
      return if !SiteSetting.kuu_buddy_enabled

      DiscourseKuuBuddy::Activity::SyncChatLeave.call(
        params: {
          channel_id: args[:channel_id],
          user_id: args[:user_id],
        },
      )
    end
  end
end
