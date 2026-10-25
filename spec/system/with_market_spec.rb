# frozen_string_literal: true

# 二手插件和搭子插件同时开着（线上就是这样）。两个插件以前都包了 core 的 topic-link，
# 那是包裹型 outlet，只能用一个：二手卡片不见了，管理员每行都看到警告（Issue #6）。
# CI 通过 about.json 一起装二手插件
RSpec.describe "Buddy and market cards in the same topic list" do
  fab!(:admin)
  fab!(:buddy_category) { Fabricate(:category, name: "Buddy board") }
  fab!(:market_category) { Fabricate(:category, name: "Market") }
  fab!(:activity) do
    Fabricate(
      :kuu_buddy_activity,
      topic:
        Fabricate(:topic_with_op, category: buddy_category, title: "Mahjong on Saturday night"),
    )
  end
  fab!(:listing) do
    Fabricate(
      :kuu_market_listing,
      topic: Fabricate(:topic_with_op, category: market_category, title: "IKEA desk for sale"),
    )
  end

  before do
    skip("discourse-kuu-market is not installed") if !defined?(DiscourseKuuMarket)

    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = buddy_category.id
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market_category.id
    sign_in(admin)
  end

  shared_examples "both cards" do
    it "shows both kinds of cards without the outlet warning" do
      visit "/latest"

      expect(page).to have_css(".kuu-buddy-card[data-topic-id='#{activity.topic_id}']")
      expect(page).to have_css(".kuu-buddy-card-status[data-topic-id='#{activity.topic_id}']")
      expect(page).to have_css(".kuu-market-card[data-topic-id='#{listing.topic_id}']")
      expect(page).to have_no_text("Multiple connectors")
    end
  end

  context "with a desktop browser" do
    include_examples "both cards"
  end

  context "with a phone browser", mobile: true do
    include_examples "both cards"
  end
end
