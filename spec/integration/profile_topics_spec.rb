# frozen_string_literal: true

# 二手插件也把自己隐藏的帖子（已出 / 已购买）放回个人主页，两个插件共用 KuuProfileTopics（二手 Issue #19）。
# CI 里只装了本插件，这里用一个假插件模拟二手：登记一个来源，并像二手一样注册自己的 modifier
RSpec.describe "Hidden topics revealed on profiles by several KUU plugins" do
  fab!(:organizer) { Fabricate(:user, refresh_auto_groups: true, created_at: 1.month.ago) }
  fab!(:viewer) { Fabricate(:user, refresh_auto_groups: true, created_at: 1.month.ago) }
  fab!(:category)
  fab!(:other_category, :category)

  # 「二手」那边插件隐藏的帖子，和一个管理员隐藏的帖子
  fab!(:sold) do
    Fabricate(:topic_with_op, user: organizer, category: other_category, visible: false)
  end
  fab!(:unlisted_by_staff) do
    Fabricate(:topic_with_op, user: organizer, category: other_category, visible: false)
  end

  let(:market_plugin) { Plugin::Instance.new }
  let(:market_modifier) do
    ->(topics, options, _topic_query) { KuuProfileTopics.reveal(topics, options) }
  end

  let!(:recruiting) { buddy_topic("Mahjong night") }
  let!(:ended) { buddy_topic("Mahjong party", status: "ended") }
  let!(:expired) { buddy_topic("Mahjong marathon", status: "expired") }

  before do
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
    SiteSetting.hide_new_user_profiles = false

    KuuProfileTopics::SOURCES[:market] = -> { Topic.where(id: sold.id).select(:id) }
    DiscoursePluginRegistry.register_modifier(
      market_plugin,
      :topic_query_create_list_topics,
      &market_modifier
    )
    sign_in(viewer)
  end

  after do
    KuuProfileTopics::SOURCES.delete(:market)
    DiscoursePluginRegistry.unregister_modifier(
      market_plugin,
      :topic_query_create_list_topics,
      &market_modifier
    )
  end

  def buddy_topic(title, status: nil)
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
    topic =
      DiscourseKuuBuddy::Activity::Create
        .call(params: { title:, capacity: 4, schedule: "Saturday" }, guardian: organizer.guardian)
        .new_post_result
        .post
        .topic
    if status
      activity = topic.kuu_buddy_activity
      activity.status = status
      DiscourseKuuBuddy::Activity::Action::SyncTopic.call(activity:)
      activity.save!
    end
    topic.reload
  end

  def profile_topic_ids
    get "/topics/created-by/#{organizer.username}.json"
    expect(response.status).to eq(200)
    response.parsed_body["topic_list"]["topics"].map { it["id"] }
  end

  it "shows both plugins' revealed topics, but not expired or staff-unlisted ones" do
    expect(profile_topic_ids).to contain_exactly(recruiting.id, ended.id, sold.id)
  end

  it "keeps the other plugin working when this one is turned off" do
    SiteSetting.kuu_buddy_enabled = false

    expect(profile_topic_ids).to contain_exactly(recruiting.id, sold.id)
  end

  it "keeps this plugin working when the other one is turned off" do
    KuuProfileTopics::SOURCES[:market] = -> { Topic.none.select(:id) }

    expect(profile_topic_ids).to contain_exactly(recruiting.id, ended.id)
  end

  it "leaves other topic lists alone" do
    get "/latest.json"

    ids = response.parsed_body["topic_list"]["topics"].map { it["id"] }
    expect(ids).to include(recruiting.id)
    expect(ids).not_to include(ended.id, sold.id)
  end
end
