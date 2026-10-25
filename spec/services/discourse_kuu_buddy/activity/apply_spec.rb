# frozen_string_literal: true

RSpec.describe DiscourseKuuBuddy::Activity::Apply do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to validate_length_of(:message).is_at_most(100) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:organizer) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
    fab!(:applicant) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, user: organizer, category:) }
    fab!(:first_post) { Fabricate(:post, topic:, user: organizer) }
    fab!(:activity) { Fabricate(:kuu_buddy_activity, topic:) }

    let(:params) { { topic_id: topic.id, message: "  我会打日麻  " } }
    let(:dependencies) { { guardian: applicant.guardian } }

    before do
      SiteSetting.kuu_buddy_enabled = true
      SiteSetting.kuu_buddy_category = category.id
    end

    context "when the applicant is the organizer" do
      let(:dependencies) { { guardian: organizer.guardian } }

      it { is_expected.to fail_a_policy(:can_apply) }
    end

    context "when the applicant is silenced" do
      before { applicant.update!(silenced_till: 1.day.from_now) }

      it { is_expected.to fail_a_policy(:can_apply) }
    end

    context "when the activity is not recruiting" do
      before { activity.update!(status: "started") }

      it { is_expected.to fail_a_policy(:can_apply) }
    end

    context "when the activity is full" do
      before do
        activity.update!(capacity: 2)
        Fabricate(:kuu_buddy_member, activity:)
      end

      it { is_expected.to fail_a_policy(:can_apply) }
    end

    context "when the topic was moved out of the buddy board" do
      before { topic.update!(category: Fabricate(:category)) }

      it { is_expected.to fail_a_policy(:can_apply) }
    end

    context "when the applicant already has a request waiting" do
      before { Fabricate(:kuu_buddy_application, activity:, user: applicant) }

      it { is_expected.to fail_a_policy(:not_applied) }
    end

    context "when the applicant is already a member" do
      before { Fabricate(:kuu_buddy_member, activity:, user: applicant) }

      it { is_expected.to fail_a_policy(:not_applied) }
    end

    context "when the applicant was declined before" do
      before { Fabricate(:kuu_buddy_application, activity:, user: applicant, status: "declined") }

      it { is_expected.to fail_a_policy(:not_barred) }
    end

    context "when the applicant was removed before" do
      before { Fabricate(:kuu_buddy_application, activity:, user: applicant, status: "removed") }

      it { is_expected.to fail_a_policy(:not_barred) }
    end

    context "when the applicant withdrew or left before" do
      before do
        Fabricate(:kuu_buddy_application, activity:, user: applicant, status: "withdrawn")
        Fabricate(:kuu_buddy_application, activity:, user: applicant, status: "left")
      end

      it { is_expected.to run_successfully }
    end

    # 时间固定在日本时间下午三点，免得测试跑在半夜时跨天
    context "with earlier requests today" do
      let(:tokyo) { ActiveSupport::TimeZone["Asia/Tokyo"] }

      before do
        freeze_time(tokyo.parse("2026-10-25 15:00"))
        SiteSetting.kuu_buddy_application_actions_per_day = 3
        # 申请在昨天、撤回在今天：只算撤回这一次
        Fabricate(
          :kuu_buddy_application,
          activity:,
          user: applicant,
          status: "withdrawn",
          created_at: tokyo.parse("2026-10-24 20:00"),
          withdrawn_at: tokyo.parse("2026-10-25 09:00"),
        )
        Fabricate(
          :kuu_buddy_application,
          activity:,
          user: applicant,
          status: "withdrawn",
          created_at: tokyo.parse("2026-10-25 10:00"),
          withdrawn_at: tokyo.parse("2026-10-25 11:00"),
        )
      end

      it { is_expected.to fail_a_policy(:within_daily_limit) }

      it "lets them again from midnight Japan time" do
        freeze_time(tokyo.parse("2026-10-26 00:00"))

        expect(result).to run_successfully
      end
    end

    context "when everything is fine" do
      it { is_expected.to run_successfully }

      it "records the request with the message" do
        expect(result.application).to have_attributes(
          user: applicant,
          status: "pending",
          message: "我会打日麻",
        )
      end

      it "allows no message" do
        params[:message] = nil

        expect(result.application.message).to eq("")
      end

      it "notifies the organizer" do
        expect { result }.to change { organizer.notifications.count }.by(1)

        notification = organizer.notifications.last
        expect(notification).to have_attributes(
          notification_type: Notification.types[:custom],
          topic_id: topic.id,
        )
        expect(notification.data_hash).to include(
          message: "kuu_buddy.notifications.applied",
          display_username: applicant.username,
        )
      end

      it "lets staff apply too" do
        moderator = Fabricate(:moderator)

        expect(described_class.call(params:, guardian: moderator.guardian)).to run_successfully
      end
    end
  end
end
