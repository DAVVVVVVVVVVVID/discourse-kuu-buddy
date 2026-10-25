# frozen_string_literal: true

Fabricator(:kuu_buddy_activity, class_name: "DiscourseKuuBuddy::Activity") do
  topic { Fabricate(:topic_with_op) }
  status "recruiting"
  recruiting_since { Time.zone.now }
  title "周六一起打麻将"
  capacity 4
  schedule "这周六 19:00 左右"
end

Fabricator(:kuu_buddy_application, class_name: "DiscourseKuuBuddy::Application") do
  activity { Fabricate(:kuu_buddy_activity) }
  user
  status "pending"
end

Fabricator(:kuu_buddy_member, from: :kuu_buddy_application) do
  status "accepted"
  decided_at { Time.zone.now }
end
