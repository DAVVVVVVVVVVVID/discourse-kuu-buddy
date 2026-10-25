# frozen_string_literal: true

RSpec.describe Jobs::KuuBuddyExpireActivities do
  fab!(:category)
  fab!(:due) do
    Fabricate(
      :kuu_buddy_activity,
      topic: Fabricate(:topic_with_op, category:),
      recruiting_since: 31.days.ago,
    )
  end
  fab!(:fresh) { Fabricate(:kuu_buddy_activity, topic: Fabricate(:topic_with_op, category:)) }

  before do
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
  end

  it "expires only the activities that are due" do
    described_class.new.execute({})

    expect(due.reload.status).to eq("expired")
    expect(fresh.reload.status).to eq("recruiting")
  end

  it "does nothing when the plugin is off" do
    SiteSetting.kuu_buddy_enabled = false

    described_class.new.execute({})

    expect(due.reload.status).to eq("recruiting")
  end
end
