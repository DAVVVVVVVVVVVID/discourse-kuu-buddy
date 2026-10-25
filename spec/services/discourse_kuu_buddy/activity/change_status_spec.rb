# frozen_string_literal: true

RSpec.describe DiscourseKuuBuddy::Activity::ChangeStatus do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to allow_values("recruiting", "started", "ended").for(:status) }
    it { is_expected.not_to allow_value("expired").for(:status) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, user: author, category:) }
    fab!(:first_post) { Fabricate(:post, topic:, user: author) }
    fab!(:activity) { Fabricate(:kuu_buddy_activity, topic:) }

    let(:params) { { topic_id: topic.id, status: } }
    let(:status) { "started" }
    let(:dependencies) { { guardian: author.guardian } }

    before do
      SiteSetting.kuu_buddy_enabled = true
      SiteSetting.kuu_buddy_category = category.id
    end

    context "when someone else changes it" do
      let(:dependencies) { { guardian: Fabricate(:user).guardian } }

      it { is_expected.to fail_a_policy(:can_change_status) }
    end

    context "when the author is silenced" do
      before { author.update!(silenced_till: 1.day.from_now) }

      it { is_expected.to fail_a_policy(:can_change_status) }
    end

    context "when the transition is not allowed" do
      let(:status) { "ended" }

      it { is_expected.to fail_a_policy(:status_reachable) }
    end

    context "when staff changes it" do
      let(:dependencies) { { guardian: Fabricate(:moderator).guardian } }

      it { is_expected.to run_successfully }
    end

    context "when starting" do
      it "starts the activity and keeps it listed" do
        expect(result).to run_successfully
        expect(activity.reload).to have_attributes(status: "started", start_reason: "manual")
        expect(topic.reload.visible).to eq(true)
      end

      it "tells open topic pages to reload" do
        messages = MessageBus.track_publish("/topic/#{topic.id}") { result }

        expect(messages.map(&:data)).to include(reload_topic: true)
      end
    end

    context "when ending" do
      let(:status) { "ended" }

      before { activity.update!(status: "started") }

      it "unlists the topic without a small action post, keeping replies open" do
        expect { result }.not_to change { topic.posts.count }

        expect(activity.reload).to have_attributes(status: "ended", unlisted_by_plugin: true)
        expect(topic.reload).to have_attributes(visible: false, closed: false)
      end
    end

    context "when reopening an expired activity" do
      let(:status) { "recruiting" }

      before do
        activity.update!(status: "expired", recruiting_since: 40.days.ago)
        DiscourseKuuBuddy::Activity::Action::SyncTopic.call(activity:)
        activity.save!
      end

      it "lists the topic again and restarts the expiry clock" do
        freeze_time

        result

        expect(activity.reload).to have_attributes(status: "recruiting", unlisted_by_plugin: false)
        expect(activity.recruiting_since).to eq_time(Time.zone.now)
        expect(topic.reload.visible).to eq(true)
      end

      it "leaves a topic unlisted by staff alone" do
        activity.update!(unlisted_by_plugin: false)

        result

        expect(topic.reload.visible).to eq(false)
      end
    end
  end
end
