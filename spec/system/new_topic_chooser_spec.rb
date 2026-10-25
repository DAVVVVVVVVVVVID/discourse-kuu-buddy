# frozen_string_literal: true

RSpec.describe "Choosing a buddy topic from the new topic chooser" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category) { Fabricate(:category, name: "Buddy board") }

  let(:form) { PageObjects::Modals::KuuBuddyActivityForm.new }
  let(:category_page) { PageObjects::Pages::Category.new }
  let(:chooser) { ".kuu-new-topic-choice" }
  let(:buddy_option) do
    "#{chooser} .kuu-new-topic-choice__option[data-type-id='kuu-buddy-activity']"
  end

  before do
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
    sign_in(user)
  end

  it "offers it on Latest and posts it in the buddy board" do
    visit("/latest")
    find("#create-topic").click
    find(buddy_option).click

    expect(form).to be_open
    form.fill_in("title", "Mahjong").fill_in("schedule", "Saturday evening").submit

    expect(page).to have_css("#topic-title", text: "Mahjong")
    expect(DiscourseKuuBuddy::Activity.last.topic.category).to eq(category)
  end

  it "opens the form straight away in the buddy board" do
    category_page.visit(category)
    category_page.new_topic_button.click

    expect(form).to be_open
    expect(page).to have_no_css(chooser)
  end

  it "leaves it out for users who cannot post in the buddy board" do
    category.set_permissions(everyone: :readonly)
    category.save!

    visit("/latest")
    find("#create-topic").click

    expect(page).to have_css("#{chooser}, #reply-control.open")
    expect(page).to have_no_css(buddy_option)
  end
end
