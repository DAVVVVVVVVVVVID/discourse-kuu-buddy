# frozen_string_literal: true

RSpec.describe DiscourseKuuBuddy::Activity::Expire do
  subject(:result) { described_class.call(params: { topic_id: topic.id }) }

  fab!(:author, :user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, user: author, category:) }
  fab!(:first_post) { Fabricate(:post, topic:, user: author) }
  fab!(:activity) { Fabricate(:kuu_buddy_activity, topic:, recruiting_since: 31.days.ago) }

  before do
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
  end

  context "when the activity is not due yet" do
    before { activity.update!(recruiting_since: 1.day.ago) }

    it { is_expected.to fail_a_policy(:expiry_due) }
  end

  context "when the activity already started" do
    before { activity.update!(status: "started") }

    it { is_expected.to fail_a_policy(:expiry_due) }
  end

  context "when the topic is deleted" do
    before { topic.trash! }

    it { is_expected.to fail_a_policy(:activity_in_category) }
  end

  context "when it is due" do
    it { is_expected.to run_successfully }

    it "expires and unlists the topic" do
      result

      expect(activity.reload).to have_attributes(status: "expired", unlisted_by_plugin: true)
      expect(topic.reload.visible).to eq(false)
    end

    it "notifies the author on the site only" do
      expect { result }.to change { author.notifications.count }.by(1)

      notification = author.notifications.last
      expect(notification).to have_attributes(
        notification_type: Notification.types[:custom],
        topic_id: topic.id,
        post_number: 1,
      )
      expect(notification.data_hash[:message]).to eq("kuu_buddy.notifications.expired")
    end
  end
end
