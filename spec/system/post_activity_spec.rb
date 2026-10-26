# frozen_string_literal: true

RSpec.describe "Posting and managing a buddy topic" do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:category) { Fabricate(:category, name: "Buddy board") }

  let(:form) { PageObjects::Modals::KuuBuddyActivityForm.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
    SiteSetting.default_locale = "zh_CN"
    SiteSetting.chat_max_direct_message_users = 5
    sign_in(user)
  end

  it "posts from the buddy board's own button" do
    visit "/c/#{category.slug}/#{category.id}"
    find(".kuu-buddy-new-button").click

    expect(form).to be_open
    expect(form).to have_capacity(4)
    expect(form).to have_capacity_hint("还要找 3 个人（2～5 人）")

    form.increase_capacity
    expect(form).to have_capacity(5)
    expect(page).to have_css(".kuu-buddy-stepper__increase[disabled]")

    form.fill_in("title", "爬大文字山").fill_in("schedule", "这周日上午").submit

    expect(page).to have_css(".kuu-buddy-panel .kuu-buddy-status--recruiting", text: "招募中")
    expect(page).to have_css(".kuu-buddy-panel__status-detail", text: "还差 4 人")
    expect(page).to have_css(
      ".kuu-buddy-panel__field[data-field='requirements'] dd",
      text: "无条件，欢迎所有人",
    )
    # 第一楼正文和面板重复，藏起来
    expect(page).to have_no_css(".topic-post.kuu-buddy-first-post .cooked", visible: :visible)

    topic = Topic.last
    expect(topic.title).to eq("爬大文字山")
    expect(topic.kuu_buddy_activity.capacity).to eq(5)
  end

  it "asks for the required fields" do
    visit "/c/#{category.slug}/#{category.id}"
    find(".kuu-buddy-new-button").click
    form.submit

    expect(form).to have_field_error("title")
    expect(form).to have_field_error("schedule")
  end

  context "with a topic of their own" do
    fab!(:topic) { Fabricate(:topic, user:, category:, title: "Mahjong on Saturday night") }
    fab!(:first_post) { Fabricate(:post, topic:, user:) }
    fab!(:activity) { Fabricate(:kuu_buddy_activity, topic:) }

    it "edits it with the form" do
      topic_page.visit_topic(topic)
      find(".kuu-buddy-actions__edit").click

      expect(form).to have_capacity(4)
      form.fill_in("schedule", "周日下午").submit

      expect(page).to have_css(".kuu-buddy-panel__field[data-field='schedule'] dd", text: "周日下午")
    end

    it "starts and ends it" do
      topic_page.visit_topic(topic)

      find(".kuu-buddy-actions__change[data-status='started']").click
      dialog.click_yes
      expect(page).to have_css(".kuu-buddy-panel .kuu-buddy-status--started", text: "活动开始！")

      find(".kuu-buddy-actions__change[data-status='ended']").click
      # 没有群聊时不问保不保留
      expect(page).to have_css(".kuu-buddy-end-modal")
      expect(page).to have_no_css(".kuu-buddy-end-modal__chat")
      find(".kuu-buddy-end-modal__confirm").click
      expect(page).to have_css(".kuu-buddy-panel .kuu-buddy-status--ended", text: "已结束")
      expect(page).to have_no_css(".kuu-buddy-actions__change")
      expect(activity.reload.status).to eq("ended")
    end

    # 第一楼和标题由表单生成：发起人看不到第一楼和标题旁的编辑笔，管理员照常能看到、能编辑
    it "hides the generated first post and the title pencil from the organizer, not from staff" do
      topic_page.visit_topic(topic)

      expect(page).to have_css(".kuu-buddy-panel")
      # 视觉隐藏（1px 高、内容裁掉），不是 display: none，见 Issue #9
      expect(page).to have_css("body.kuu-buddy-topic .topic-post.kuu-buddy-first-post")
      expect(
        page.evaluate_script(
          "document.querySelector('.topic-post.kuu-buddy-first-post').getBoundingClientRect().height",
        ),
      ).to be <= 1
      expect(page).to have_no_css("#topic-title .edit-topic", visible: :visible)

      sign_in(Fabricate(:admin))
      topic_page.visit_topic(topic)

      expect(page).to have_css("#post_1", visible: :visible)
      expect(page).to have_no_css("body.kuu-buddy-topic")
    end
  end

  it "shows buddy topics as cards and filters them" do
    recruiting =
      Fabricate(
        :kuu_buddy_activity,
        topic: Fabricate(:topic_with_op, category:, title: "Mahjong on Saturday night"),
        requirements: "会打日麻",
      )
    Fabricate(
      :kuu_buddy_activity,
      topic: Fabricate(:topic_with_op, category:, title: "Hiking on Sunday morning"),
      status: "started",
    )

    visit "/c/#{category.slug}/#{category.id}"

    card = find(".kuu-buddy-card[data-topic-id='#{recruiting.topic_id}']")
    expect(page).to have_css(
      ".kuu-buddy-card-status[data-topic-id='#{recruiting.topic_id}'].kuu-buddy-status--recruiting",
      text: "招募中",
    )
    expect(card).to have_css(".kuu-buddy-card__line[data-field='requirements']", text: "会打日麻")
    expect(card).to have_css(".kuu-buddy-card__count", text: "1 / 4 人")
    expect(card).to have_css(".kuu-buddy-card__spots", text: "还差 3 人")
    expect(page).to have_css(".kuu-buddy-card", count: 2)

    find(".kuu-buddy-filters__option[data-value='recruiting']").click

    expect(page).to have_current_path(/kuu_buddy=recruiting/)
    expect(page).to have_css(".kuu-buddy-card", count: 1)
  end
end
