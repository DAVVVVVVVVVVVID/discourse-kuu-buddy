# frozen_string_literal: true

RSpec.describe DiscourseKuuBuddy::Activity::DeclineApplication do
  subject(:result) { described_class.call(params:, **dependencies) }

  fab!(:organizer, :user)
  fab!(:applicant, :user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, user: organizer, category:) }
  fab!(:first_post) { Fabricate(:post, topic:, user: organizer) }
  fab!(:activity) { Fabricate(:kuu_buddy_activity, topic:) }
  fab!(:application) { Fabricate(:kuu_buddy_application, activity:, user: applicant) }

  let(:params) { { topic_id: topic.id, application_id: application.id } }
  let(:dependencies) { { guardian: organizer.guardian } }

  before do
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
  end

  context "when someone else declines" do
    let(:dependencies) { { guardian: applicant.guardian } }

    it { is_expected.to fail_a_policy(:can_manage) }
  end

  it "declines and notifies the applicant gently" do
    expect { result }.to change { applicant.notifications.count }.by(1)

    expect(application.reload.status).to eq("declined")
    expect(applicant.notifications.last.data_hash[:message]).to eq(
      "kuu_buddy.notifications.declined",
    )
  end
end
