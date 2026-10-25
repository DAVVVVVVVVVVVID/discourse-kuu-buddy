# frozen_string_literal: true

RSpec.describe DiscourseKuuBuddy::Activity do
  fab!(:category)

  before do
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
  end

  describe "validations" do
    subject(:activity) { described_class.open(title: "爬山", capacity: 4, schedule: "周末") }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(40) }
    it { is_expected.to validate_presence_of(:schedule) }
    it { is_expected.to validate_length_of(:schedule).is_at_most(40) }
    it { is_expected.to validate_length_of(:requirements).is_at_most(100) }
    it { is_expected.to validate_length_of(:description).is_at_most(2000) }

    it "allows 2 up to the chat group limit of people" do
      SiteSetting.chat_max_direct_message_users = 20

      expect(activity).to allow_values(2, 20).for(:capacity)
      expect(activity).not_to allow_values(1, 21, nil).for(:capacity)
    end

    it "follows the chat group limit" do
      SiteSetting.chat_max_direct_message_users = 8

      expect(activity).not_to allow_value(9).for(:capacity)
    end

    it "lets an existing activity keep a capacity above a lowered limit" do
      saved = Fabricate(:kuu_buddy_activity, capacity: 20)
      SiteSetting.chat_max_direct_message_users = 8

      saved.change_status("started")

      expect(saved).to be_valid
    end
  end

  describe ".open" do
    it "starts recruiting now" do
      freeze_time

      activity = described_class.open(title: "爬山", capacity: 4, schedule: "周末")

      expect(activity.status).to eq("recruiting")
      expect(activity.recruiting_since).to eq_time(Time.zone.now)
    end
  end

  describe "#can_change_to?" do
    it "follows recruiting → started → ended, and expired → recruiting" do
      expect(Fabricate.build(:kuu_buddy_activity, status: "recruiting").statuses_reachable).to eq(
        %w[started],
      )
      expect(Fabricate.build(:kuu_buddy_activity, status: "started").statuses_reachable).to eq(
        %w[ended],
      )
      expect(Fabricate.build(:kuu_buddy_activity, status: "expired").statuses_reachable).to eq(
        %w[recruiting],
      )
      expect(Fabricate.build(:kuu_buddy_activity, status: "ended").statuses_reachable).to be_empty
    end
  end

  describe "#change_status" do
    fab!(:activity) { Fabricate(:kuu_buddy_activity, recruiting_since: 10.days.ago) }

    before { freeze_time }

    it "records when and why the activity started" do
      activity.change_status("started")

      expect(activity.start_reason).to eq("manual")
      expect(activity.started_at).to eq_time(Time.zone.now)
    end

    it "restarts the expiry clock when recruiting again" do
      activity.update!(status: "expired")

      activity.change_status("recruiting")

      expect(activity.recruiting_since).to eq_time(Time.zone.now)
    end

    it "records when the activity ended" do
      activity.update!(status: "started")

      activity.change_status("ended")

      expect(activity.ended_at).to eq_time(Time.zone.now)
    end
  end

  describe ".due_to_expire" do
    fab!(:topic) { Fabricate(:topic_with_op, category:) }
    fab!(:activity) { Fabricate(:kuu_buddy_activity, topic:) }

    it "includes activities recruiting for the whole period" do
      activity.update!(recruiting_since: 30.days.ago)

      expect(described_class.due_to_expire).to contain_exactly(activity)
    end

    it "skips activities recruiting for less" do
      activity.update!(recruiting_since: 29.days.ago)

      expect(described_class.due_to_expire).to be_empty
    end

    it "skips activities that already started" do
      activity.update!(recruiting_since: 31.days.ago, status: "started")

      expect(described_class.due_to_expire).to be_empty
    end

    it "skips deleted topics and topics moved elsewhere" do
      activity.update!(recruiting_since: 31.days.ago)
      other = Fabricate(:kuu_buddy_activity, recruiting_since: 31.days.ago)
      topic.trash!

      expect(described_class.due_to_expire).not_to include(activity, other)
    end
  end
  describe "members and fullness" do
    fab!(:activity) { Fabricate(:kuu_buddy_activity, capacity: 3) }

    def add_member
      Fabricate(:kuu_buddy_member, activity:)
      activity.members.reset
    end

    it "counts the organizer" do
      expect(activity.member_count).to eq(1)
      add_member
      expect(activity.member_count).to eq(2)
    end

    it "ignores pending and former members" do
      Fabricate(:kuu_buddy_application, activity:)
      Fabricate(:kuu_buddy_application, activity:, status: "left")

      expect(activity.member_count).to eq(1)
    end

    it "starts by itself when full, and recruits again when someone leaves" do
      2.times { add_member }

      expect(activity.follow_member_count).to eq(true)
      expect(activity).to have_attributes(status: "started", start_reason: "full")

      activity.members.first.update!(status: "left")
      activity.members.reset

      expect(activity.follow_member_count).to eq(true)
      expect(activity).to have_attributes(status: "recruiting", start_reason: nil)
    end

    it "stays started when the organizer started it by hand" do
      activity.change_status("started")

      expect(activity.follow_member_count).to eq(false)
      expect(activity).to be_started
    end

    it "does not let the capacity drop below the members" do
      2.times { add_member }
      activity.capacity = 2

      expect(activity).not_to be_valid
      expect(activity.errors[:capacity]).to be_present
    end
  end
end
