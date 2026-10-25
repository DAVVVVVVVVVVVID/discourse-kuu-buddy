# frozen_string_literal: true

RSpec.describe DiscourseKuuBuddy::Activity::Update do
  subject(:result) { described_class.call(params:, **dependencies) }

  fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, user: author, category:, title: "Mahjong on Saturday night") }
  fab!(:first_post) { Fabricate(:post, topic:, user: author) }
  fab!(:activity) { Fabricate(:kuu_buddy_activity, topic:, recruiting_since: 3.days.ago) }

  let(:params) do
    { topic_id: topic.id, title: "爬山", capacity: 5, schedule: "周日", description: "带水" }
  end
  let(:dependencies) { { guardian: author.guardian } }

  before do
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
    SiteSetting.default_locale = "zh_CN"
  end

  context "when the activity is not found" do
    before { params[:topic_id] = 0 }

    it { is_expected.to fail_to_find_a_model(:activity) }
  end

  context "when the topic was moved out of the buddy board" do
    before { topic.update!(category: Fabricate(:category)) }

    it { is_expected.to fail_a_policy(:activity_in_category) }
  end

  context "when someone else edits" do
    let(:dependencies) { { guardian: Fabricate(:user).guardian } }

    it { is_expected.to fail_a_policy(:can_edit_activity) }
  end

  context "when everything is fine" do
    it { is_expected.to run_successfully }

    it "regenerates the title and first post, keeping the expiry clock" do
      recruiting_since = activity.recruiting_since

      result

      expect(topic.reload.title).to eq("爬山")
      expect(first_post.reload.raw).to include("- **人数**：5 人（含发起人）").and include("带水")
      expect(activity.reload).to have_attributes(capacity: 5, schedule: "周日")
      expect(activity.recruiting_since).to eq_time(recruiting_since)
    end

    it "ignores the edit time limit" do
      SiteSetting.post_edit_time_limit = 1
      first_post.update_columns(created_at: 1.day.ago)

      expect(result).to run_successfully
    end

    it "keeps omitted fields" do
      params.delete(:description)
      activity.update!(description: "带水")

      result

      expect(activity.reload.description).to eq("带水")
    end
  end
end
