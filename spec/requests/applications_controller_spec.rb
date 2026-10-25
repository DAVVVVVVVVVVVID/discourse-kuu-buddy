# frozen_string_literal: true

RSpec.describe DiscourseKuuBuddy::ApplicationsController do
  fab!(:organizer) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:applicant) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:viewer) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, user: organizer, category:) }
  fab!(:first_post) { Fabricate(:post, topic:, user: organizer) }
  fab!(:activity) { Fabricate(:kuu_buddy_activity, topic:) }

  before do
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
    SiteSetting.chat_enabled = true
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]
  end

  def topic_activity
    get "/t/#{topic.id}.json"
    response.parsed_body["kuu_buddy_activity"]
  end

  def apply(message: "我会打日麻")
    post "/kuu-buddy/activities/#{topic.id}/applications.json", params: { message: }
  end

  it "requires login to apply" do
    apply

    expect(response.status).to eq(403)
  end

  describe "applying and withdrawing" do
    before { sign_in(applicant) }

    it "applies and shows the request as waiting" do
      apply

      expect(response.status).to eq(200)
      expect(response.parsed_body["activity"]).to include(
        "can_apply" => false,
        "my_application" => include("status" => "pending", "message" => "我会打日麻"),
      )
    end

    it "refuses a second request" do
      apply
      apply

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(I18n.t("kuu_buddy.errors.already_applied"))
    end

    it "refuses a long message" do
      apply(message: "啊" * 101)

      expect(response.status).to eq(400)
    end

    it "says when the daily limit is reached" do
      SiteSetting.kuu_buddy_application_actions_per_day = 1
      apply
      delete "/kuu-buddy/activities/#{topic.id}/applications/mine.json"

      expect(response.status).to eq(429)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("kuu_buddy.errors.too_many_application_actions"),
      )
    end

    it "withdraws" do
      apply
      delete "/kuu-buddy/activities/#{topic.id}/applications/mine.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["activity"]).to include(
        "can_apply" => true,
        "my_application" => include("status" => "withdrawn"),
      )
    end
  end

  describe "who sees the requests" do
    fab!(:application) do
      Fabricate(:kuu_buddy_application, activity:, user: applicant, message: "我会打日麻")
    end

    it "shows them, with the message, only to the organizer and staff" do
      sign_in(organizer)
      expect(topic_activity["applications"]).to contain_exactly(
        include("id" => application.id, "message" => "我会打日麻"),
      )

      sign_in(Fabricate(:admin))
      expect(topic_activity["applications"].size).to eq(1)

      sign_in(viewer)
      expect(topic_activity).not_to have_key("applications")

      sign_in(applicant)
      expect(topic_activity).not_to have_key("applications")
    end

    it "hides them from visitors who are not logged in" do
      expect(topic_activity).not_to have_key("applications")
      expect(topic_activity).not_to have_key("my_application")
    end
  end

  describe "accepting and declining" do
    fab!(:application) { Fabricate(:kuu_buddy_application, activity:, user: applicant) }

    it "only lets the organizer accept" do
      sign_in(viewer)

      put "/kuu-buddy/activities/#{topic.id}/applications/#{application.id}/accept.json"

      expect(response.status).to eq(403)
    end

    it "accepts, shows the member to everyone and the chat only to members" do
      sign_in(organizer)

      put "/kuu-buddy/activities/#{topic.id}/applications/#{application.id}/accept.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["chat_delivery"]).to eq("joined")
      expect(response.parsed_body["activity"]).to include(
        "member_count" => 2,
        "members" => [include("username" => applicant.username, "in_chat" => true)],
        "applications" => [],
        "chat" => include("name" => activity.title),
      )

      sign_in(viewer)
      expect(topic_activity["members"]).to match(
        [include("username" => applicant.username).and(exclude("in_chat"))],
      )
      expect(topic_activity).not_to have_key("chat")

      sign_in(applicant)
      expect(topic_activity["chat"]).to include("id" => activity.reload.chat_channel_id)
      expect(topic_activity["chat"]["last_message"]["excerpt"]).to include(activity.title)
    end

    it "says when the activity is full" do
      activity.update!(capacity: 2)
      Fabricate(:kuu_buddy_member, activity:)
      sign_in(organizer)

      put "/kuu-buddy/activities/#{topic.id}/applications/#{application.id}/accept.json"

      expect(response.status).to eq(422)
    end

    it "declines" do
      sign_in(organizer)

      put "/kuu-buddy/activities/#{topic.id}/applications/#{application.id}/decline.json"

      expect(response.status).to eq(200)
      expect(application.reload.status).to eq("declined")
    end
  end

  describe DiscourseKuuBuddy::MembersController do
    fab!(:membership) { Fabricate(:kuu_buddy_member, activity:, user: applicant) }

    it "lets a member leave" do
      sign_in(applicant)

      delete "/kuu-buddy/activities/#{topic.id}/membership.json"

      expect(response.status).to eq(200)
      expect(membership.reload.status).to eq("left")
    end

    it "lets the organizer remove a member" do
      sign_in(organizer)

      delete "/kuu-buddy/activities/#{topic.id}/members/#{applicant.id}.json"

      expect(response.status).to eq(200)
      expect(membership.reload.status).to eq("removed")
    end

    it "forbids others from removing members" do
      sign_in(viewer)

      delete "/kuu-buddy/activities/#{topic.id}/members/#{applicant.id}.json"

      expect(response.status).to eq(403)
    end

    it "refuses once the activity ended" do
      activity.update!(status: "ended")
      sign_in(applicant)

      delete "/kuu-buddy/activities/#{topic.id}/membership.json"

      expect(response.status).to eq(422)
    end
  end
end
