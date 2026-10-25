# frozen_string_literal: true

# 已结束、过期的搭子帖靠 core 的「隐藏话题」从别人的列表和搜索里去掉；
# 已结束的在发起人主页「话题」里所有人都能看到（Issue #1）
RSpec.describe "Who sees buddy topics that are no longer recruiting" do
  fab!(:organizer) { Fabricate(:user, refresh_auto_groups: true, created_at: 1.month.ago) }
  fab!(:viewer) { Fabricate(:user, refresh_auto_groups: true, created_at: 1.month.ago) }
  fab!(:category)

  let(:recruiting) { buddy_topic("Mahjong night") }
  let(:started) { buddy_topic("Mahjong lunch", status: "started") }
  let(:ended) { buddy_topic("Mahjong party", status: "ended") }
  let(:expired) { buddy_topic("Mahjong marathon", status: "expired") }

  before do
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
    SiteSetting.hide_new_user_profiles = false
    SearchIndexer.enable
    [recruiting, started, ended, expired]
  end

  def buddy_topic(title, status: nil)
    result =
      DiscourseKuuBuddy::Activity::Create.call(
        params: {
          title:,
          capacity: 4,
          schedule: "Saturday evening",
        },
        guardian: organizer.guardian,
      )
    topic = result.new_post_result.post.topic
    activity = topic.kuu_buddy_activity

    if status
      activity.status = status
      DiscourseKuuBuddy::Activity::Action::SyncTopic.call(activity:)
      activity.save!
    end

    topic.reload
  end

  def topic_ids(path)
    get path
    expect(response.status).to eq(200)
    response.parsed_body["topic_list"]["topics"].map { it["id"] }
  end

  context "when someone else browses" do
    before { sign_in(viewer) }

    it "hides ended and expired topics from Latest and the category page" do
      expect(topic_ids("/latest.json")).to include(recruiting.id, started.id)
      expect(topic_ids("/latest.json")).not_to include(ended.id, expired.id)
      expect(topic_ids("/c/#{category.slug}/#{category.id}.json")).to contain_exactly(
        recruiting.id,
        started.id,
      )
    end

    it "hides them from search" do
      get "/search.json", params: { q: "Mahjong" }

      ids = response.parsed_body["topics"].map { it["id"] }
      expect(ids).to include(recruiting.id)
      expect(ids).not_to include(ended.id, expired.id)
    end

    it "shows ended topics, but not expired ones, on the organizer's profile" do
      expect(topic_ids("/topics/created-by/#{organizer.username}")).to contain_exactly(
        recruiting.id,
        started.id,
        ended.id,
      )
    end

    it "still opens them by link" do
      get "/t/#{ended.id}.json"

      expect(response.status).to eq(200)
    end
  end

  context "when a visitor who is not logged in browses" do
    it "shows ended topics on the organizer's profile" do
      expect(topic_ids("/topics/created-by/#{organizer.username}")).to include(ended.id)
    end
  end

  describe "the filters on the buddy board" do
    let(:path) { "/c/#{category.slug}/#{category.id}.json" }

    it "shows only recruiting topics, keeping other topics such as the rules" do
      rules = Fabricate(:topic_with_op, category:)

      expect(topic_ids("#{path}?kuu_buddy=recruiting")).to contain_exactly(recruiting.id, rules.id)
    end

    it "shows all of my own topics, including ended and expired ones" do
      Fabricate(:topic_with_op, category:)
      sign_in(organizer)

      expect(topic_ids("#{path}?kuu_buddy=mine")).to contain_exactly(
        recruiting.id,
        started.id,
        ended.id,
        expired.id,
      )
    end

    it "shows nothing of mine to someone who organized nothing" do
      sign_in(viewer)

      expect(topic_ids("#{path}?kuu_buddy=mine")).to be_empty
    end

    it "ignores unknown values" do
      expect(topic_ids("#{path}?kuu_buddy=everything")).to contain_exactly(
        recruiting.id,
        started.id,
      )
    end
  end

  describe "moving a topic out of the buddy board" do
    fab!(:admin)

    def move(topic, to)
      sign_in(admin)
      put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: to.id }
      expect(response.status).to eq(200)
    end

    it "undoes the plugin's unlisting, and redoes it when moved back" do
      move(ended, Fabricate(:category))
      expect(ended.reload.visible).to eq(true)
      expect(ended.kuu_buddy_activity).to have_attributes(
        status: "ended",
        unlisted_by_plugin: false,
      )

      move(ended, category)
      expect(ended.reload.visible).to eq(false)
    end
  end
end
