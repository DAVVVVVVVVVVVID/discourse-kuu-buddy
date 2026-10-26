# frozen_string_literal: true

# 搭子帖只有发起人那一楼，又是表单生成的、普通用户看不到。以前把这一楼整个 display: none，
# 帖子流里没有任何可见内容，core 的帖子流反复进出状态，页面底部的按钮一直上下抖，
# 有时干脆不出来（Issue #9）
RSpec.describe "The buddy topic page staying still" do
  fab!(:organizer) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:viewer) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category) { Fabricate(:category, name: "Buddy board") }
  fab!(:topic) { Fabricate(:topic, user: organizer, category:, title: "Mahjong on Saturday night") }
  fab!(:first_post) { Fabricate(:post, topic:, user: organizer) }
  fab!(:activity) { Fabricate(:kuu_buddy_activity, topic:) }

  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
  end

  # 在页面里每 50ms 记一次底部按钮的位置和帖子流的高度，记 3 秒
  def sample_layout
    page.evaluate_async_script(<<~JS)
      const done = arguments[0];
      const samples = [];
      const timer = setInterval(() => {
        const footer = document.querySelector("#topic-footer-buttons");
        const stream = document.querySelector(".post-stream");
        samples.push({
          footer: footer ? Math.round(footer.getBoundingClientRect().top) : null,
          stream: stream ? stream.getBoundingClientRect().height : null,
          spinner: !!document.querySelector(".posts-wrapper .loading-container.visible"),
        });
      }, 50);
      setTimeout(() => { clearInterval(timer); done(samples); }, 3000);
    JS
  end

  [false, true].each do |mobile|
    context(mobile ? "with a phone browser" : "with a desktop browser", mobile:) do
      it "shows the footer buttons and keeps them still" do
        sign_in(viewer)
        topic_page.visit_topic(topic)

        expect(page).to have_css(".kuu-buddy-panel")
        expect(page).to have_css("#topic-footer-buttons")

        samples = sample_layout
        expect(samples.map { it["footer"] }.uniq.size).to eq(1), samples.inspect
        expect(samples.map { it["stream"] }.uniq.size).to eq(1), samples.inspect
        expect(samples.none? { it["spinner"] }).to eq(true), samples.inspect
      end
    end
  end
end
