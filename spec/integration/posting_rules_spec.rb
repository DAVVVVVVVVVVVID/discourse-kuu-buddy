# frozen_string_literal: true

# 搭子广场只能用表单发新帖；发起人只能用表单改第一楼和标题（管理员除外）
RSpec.describe "Posting in the buddy board" do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:category)

  before do
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
  end

  def create_topic(as)
    sign_in(as)
    post "/posts.json",
         params: {
           title: "Anyone up for mahjong this weekend?",
           raw: "Looking for three more people to play.",
           category: category.id,
         }
  end

  it "rejects topics from the normal composer" do
    create_topic(user)

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to include(I18n.t("kuu_buddy.errors.use_buddy_form"))
  end

  it "lets staff use the normal composer" do
    create_topic(admin)

    expect(response.status).to eq(200)
  end

  it "keeps the normal composer elsewhere and for replies" do
    sign_in(user)
    post "/posts.json",
         params: {
           title: "Anyone up for mahjong this weekend?",
           raw: "Looking for three more people to play.",
         }
    expect(response.status).to eq(200)

    topic = Fabricate(:topic_with_op, category:)
    post "/posts.json", params: { topic_id: topic.id, raw: "I would love to join you all!" }
    expect(response.status).to eq(200)
  end

  it "does nothing when the plugin is off" do
    SiteSetting.kuu_buddy_enabled = false

    create_topic(user)

    expect(response.status).to eq(200)
  end

  describe "editing the first post by hand" do
    fab!(:topic) { Fabricate(:topic, user:, category:, title: "Mahjong on Saturday night") }
    fab!(:first_post) { Fabricate(:post, topic:, user:) }
    fab!(:activity) { Fabricate(:kuu_buddy_activity, topic:) }

    it "stops the author" do
      sign_in(user)

      put "/posts/#{first_post.id}.json", params: { post: { raw: "Changed by hand, not by form" } }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("kuu_buddy.errors.edit_with_buddy_form"),
      )
    end

    it "stops the author from renaming the topic" do
      sign_in(user)

      put "/t/#{topic.id}.json", params: { title: "A brand new title for the topic" }

      expect(response.status).to eq(422)
    end

    it "lets staff edit" do
      sign_in(admin)

      put "/posts/#{first_post.id}.json", params: { post: { raw: "Phone number removed by staff" } }

      expect(response.status).to eq(200)
    end
  end
end
