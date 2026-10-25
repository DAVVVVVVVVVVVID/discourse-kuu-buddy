# frozen_string_literal: true

module DiscourseKuuBuddy
  class ActivitySerializer < ApplicationSerializer
    attributes :topic_id,
               :status,
               :title,
               :capacity,
               :schedule,
               :requirements,
               :description,
               :member_count,
               :spots_left,
               :started_at,
               :start_reason,
               :ended_at
  end
end
