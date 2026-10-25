# frozen_string_literal: true

RSpec.describe DiscourseKuuBuddy::Activity::WithdrawApplication do
  subject(:result) do
    described_class.call(params: { topic_id: topic.id }, guardian: applicant.guardian)
  end

  fab!(:applicant, :user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic_with_op, category:) }
  fab!(:activity) { Fabricate(:kuu_buddy_activity, topic:) }

  before do
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
  end

  context "without a waiting request" do
    before { Fabricate(:kuu_buddy_member, activity:, user: applicant) }

    it { is_expected.to fail_to_find_a_model(:application) }
  end

  context "with a waiting request" do
    fab!(:application) { Fabricate(:kuu_buddy_application, activity:, user: applicant) }

    it "withdraws it" do
      freeze_time

      expect(result).to run_successfully
      expect(application.reload.status).to eq("withdrawn")
      expect(application.withdrawn_at).to eq_time(Time.zone.now)
    end

    it "counts towards the daily limit" do
      SiteSetting.kuu_buddy_application_actions_per_day = 1

      expect(result).to fail_a_policy(:within_daily_limit)
    end
  end
end
