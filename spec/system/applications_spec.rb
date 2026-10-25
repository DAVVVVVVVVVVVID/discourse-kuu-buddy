# frozen_string_literal: true

RSpec.describe "Asking to join and managing members" do
  # 聊天都用普通用户测：管理员会跳过 chat 的不少权限检查
  fab!(:organizer) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:applicant) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:category) { Fabricate(:category, name: "Buddy board") }
  fab!(:topic) do
    Fabricate(:topic, user: organizer, category:, title: "Mahjong on Saturday night")
  end
  fab!(:first_post) { Fabricate(:post, topic:, user: organizer) }
  fab!(:activity) { Fabricate(:kuu_buddy_activity, topic:, title: "周六打麻将", capacity: 2) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:apply_form) { PageObjects::Modals::Base.new }

  before do
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
    SiteSetting.default_locale = "zh_CN"
    SiteSetting.chat_enabled = true
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]
  end

  def apply(message: nil)
    find(".kuu-buddy-join__apply").click
    expect(page).to have_css(".kuu-buddy-apply-modal", text: "申请加入「周六打麻将」")
    find(".kuu-buddy-apply-modal textarea").fill_in(with: message) if message
    find(".kuu-buddy-apply-modal__submit").click
    expect(page).to have_css(".kuu-buddy-join__pending", text: "已申请，等发起人确认")
  end

  it "lets someone apply with a message, withdraw, and apply again without one" do
    sign_in(applicant)
    topic_page.visit_topic(topic)

    apply(message: "我会打日麻")
    expect(activity.applications.last).to have_attributes(status: "pending", message: "我会打日麻")
    # 申请列表只给发起人看
    expect(page).to have_no_css(".kuu-buddy-applications")

    find(".kuu-buddy-join__withdraw").click
    dialog.click_yes
    expect(page).to have_css(".kuu-buddy-join__apply")

    apply
    expect(activity.applications.order(:id).last.message).to eq("")
  end

  it "sends visitors who are not logged in to log in" do
    topic_page.visit_topic(topic)

    find(".kuu-buddy-join__apply").click

    expect(page).to have_css(".login-modal, .login-fullpage, #login-form")
  end

  context "with a request waiting" do
    fab!(:application) do
      Fabricate(:kuu_buddy_application, activity:, user: applicant, message: "我会打日麻")
    end

    it "lets the organizer accept, which fills the activity and opens a group chat" do
      sign_in(organizer)
      topic_page.visit_topic(topic)

      item = find(".kuu-buddy-applications__item[data-application-id='#{application.id}']")
      expect(page).to have_css(".kuu-buddy-applications__private", text: "只有你能看到")
      expect(item).to have_css(".kuu-buddy-applications__message", text: "我会打日麻")

      item.find(".kuu-buddy-applications__accept").click

      expect(page).to have_css(".kuu-buddy-members__item[data-username='#{applicant.username}']")
      expect(page).to have_css(".kuu-buddy-status--started", text: "人数已满，活动开始！")
      expect(page).to have_css(".kuu-buddy-chat__name", text: "周六打麻将")
      expect(page).to have_no_css(".kuu-buddy-applications__item")

      find(".kuu-buddy-chat__open").click
      expect(page).to have_css(
        ".chat-drawer-container .chat-channel[data-id='#{activity.reload.chat_channel_id}']",
      )
    end

    it "lets the organizer decline politely" do
      sign_in(organizer)
      topic_page.visit_topic(topic)

      find(".kuu-buddy-applications__decline").click
      dialog.click_yes

      expect(page).to have_no_css(".kuu-buddy-applications__item")
      expect(application.reload.status).to eq("declined")

      sign_in(applicant)
      topic_page.visit_topic(topic)
      expect(page).to have_css(".kuu-buddy-join__barred", text: "这次没能加入，下次再约～")
      expect(page).to have_no_css(".kuu-buddy-join__apply")
    end
  end

  context "with a member" do
    before do
      activity.update!(capacity: 3)
      application = Fabricate(:kuu_buddy_application, activity:, user: applicant)
      DiscourseKuuBuddy::Activity::AcceptApplication.call(
        params: {
          topic_id: topic.id,
          application_id: application.id,
        },
        guardian: organizer.guardian,
      )
    end

    it "lets the member see the chat and leave" do
      sign_in(applicant)
      topic_page.visit_topic(topic)

      expect(page).to have_css(".kuu-buddy-chat__name", text: "周六打麻将")
      find(".kuu-buddy-join__leave").click
      dialog.click_yes

      expect(page).to have_css(".kuu-buddy-join__apply")
      expect(page).to have_no_css(".kuu-buddy-chat")
      expect(activity.applications.find_by(user: applicant).status).to eq("left")
    end

    it "lets the organizer remove the member" do
      sign_in(organizer)
      topic_page.visit_topic(topic)

      find(".kuu-buddy-members__item[data-username='#{applicant.username}'] .kuu-buddy-members__menu").click
      find(".kuu-buddy-members__remove").click
      dialog.click_yes

      expect(page).to have_no_css(".kuu-buddy-members__item[data-username='#{applicant.username}']")
      expect(activity.applications.find_by(user: applicant).status).to eq("removed")
    end

    it "lets the organizer end the activity and close the chat" do
      activity.update!(status: "started", start_reason: "manual")
      sign_in(organizer)
      topic_page.visit_topic(topic)

      find(".kuu-buddy-actions__change[data-status='ended']").click
      expect(page).to have_css(".kuu-buddy-end-modal", text: "群聊「周六打麻将」要保留吗？")
      find(".kuu-buddy-end-modal__choice input[value='close']").click
      find(".kuu-buddy-end-modal__confirm").click

      expect(page).to have_css(".kuu-buddy-status--ended", text: "已结束")
      expect(page).to have_css(".kuu-buddy-panel__status-detail", text: "2 人参加")
      expect(page).to have_css(".kuu-buddy-chat.--closed")
      expect(activity.reload.chat_channel).to be_closed
    end
  end

  it "shows member avatars and empty spots on the list card" do
    activity.update!(capacity: 4)
    Fabricate(:kuu_buddy_member, activity:, user: applicant)

    visit "/c/#{category.slug}/#{category.id}"

    card = find(".kuu-buddy-card[data-topic-id='#{topic.id}']")
    expect(card).to have_css(".kuu-buddy-card__avatar", count: 2)
    expect(card).to have_css(".kuu-buddy-card__slot", count: 2)
    expect(card).to have_css(".kuu-buddy-card__count", text: "2 / 4 人")
  end
end
