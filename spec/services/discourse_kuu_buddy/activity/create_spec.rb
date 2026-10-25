# frozen_string_literal: true

RSpec.describe DiscourseKuuBuddy::Activity::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:capacity) }
    it { is_expected.to validate_presence_of(:schedule) }

    it "squishes the one-line fields and strips the description" do
      contract =
        described_class.new(
          title: "  周六  打麻将 ",
          capacity: 4,
          schedule: " 周末 ",
          requirements: " 会打日麻 ",
          description: "  新手也欢迎\n地点在百万遍  ",
        )

      expect(contract.activity_attributes).to eq(
        title: "周六 打麻将",
        capacity: 4,
        schedule: "周末",
        requirements: "会打日麻",
        description: "新手也欢迎\n地点在百万遍",
      )
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
    fab!(:category)

    let(:params) { { title: "爬山", capacity: 3, schedule: "这周日上午" } }
    let(:dependencies) { { guardian: user.guardian } }

    before do
      SiteSetting.kuu_buddy_enabled = true
      SiteSetting.kuu_buddy_category = category.id
      SiteSetting.default_locale = "zh_CN"
    end

    context "when the category is not set" do
      before { SiteSetting.kuu_buddy_category = "" }

      it { is_expected.to fail_to_find_a_model(:category) }
    end

    context "when the user cannot post in the category" do
      before { category.set_permissions(everyone: :readonly).tap { category.save! } }

      it { is_expected.to fail_a_policy(:can_create_topic_in_category) }
    end

    context "when the capacity is out of range" do
      before { params[:capacity] = 1 }

      it { is_expected.to fail_with_an_invalid_model(:activity) }
    end

    context "when the title has a watched word" do
      before { Fabricate(:watched_word, word: "爬山", action: WatchedWord.actions[:block]) }

      it { is_expected.to fail_a_step(:publish_activity) }
    end

    context "when everything is fine" do
      it { is_expected.to run_successfully }

      # 「爬山」两个字过不了 core 的最短标题长度，插件的表单只对自己生成的标题放宽
      it "posts a short title with the generated first post" do
        topic = result.new_post_result.post.topic

        expect(topic).to have_attributes(title: "爬山", category:, user:)
        expect(topic.first_post.raw).to include("- **人数**：3 人（含发起人）")
        expect(topic.kuu_buddy_activity).to have_attributes(
          status: "recruiting",
          capacity: 3,
          schedule: "这周日上午",
          requirements: "",
        )
      end

      it "allows the same title twice" do
        described_class.call(params:, **dependencies)

        expect(result).to run_successfully
      end
    end

    context "when new users' posts need approval" do
      before { SiteSetting.approve_post_count = 1 }

      it "queues the topic and creates the activity once approved" do
        expect(result.new_post_result.action).to eq(:enqueued)

        result.new_post_result.reviewable.perform(Fabricate(:moderator), :approve_post)

        topic = Topic.last
        expect(topic.title).to eq("爬山")
        expect(topic.kuu_buddy_activity).to have_attributes(capacity: 3, status: "recruiting")
      end
    end
  end
end
