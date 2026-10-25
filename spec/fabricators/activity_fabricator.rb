# frozen_string_literal: true

Fabricator(:kuu_buddy_activity, class_name: "DiscourseKuuBuddy::Activity") do
  topic { Fabricate(:topic_with_op) }
  status "recruiting"
  recruiting_since { Time.zone.now }
  title "周六一起打麻将"
  capacity 4
  schedule "这周六 19:00 左右"
end
