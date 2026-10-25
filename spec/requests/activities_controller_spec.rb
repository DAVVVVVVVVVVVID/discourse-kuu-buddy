# frozen_string_literal: true

RSpec.describe DiscourseKuuBuddy::ActivitiesController do
  fab!(:author) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:category)

  before do
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
    SiteSetting.default_locale = "zh_CN"
  end

  describe "#create" do
    let(:params) { { title: "爬山", capacity: 3, schedule: "这周日上午" } }

    it "requires login" do
      post "/kuu-buddy/activities.json", params: params

      expect(response.status).to eq(403)
    end

    it "is not found when the plugin is off" do
      SiteSetting.kuu_buddy_enabled = false
      sign_in(author)

      post "/kuu-buddy/activities.json", params: params

      expect(response.status).to eq(404)
    end

    context "when signed in" do
      before { sign_in(author) }

      it "creates the topic and returns its URL" do
        post "/kuu-buddy/activities.json", params: params

        expect(response.status).to eq(200)
        topic = Topic.last
        expect(response.parsed_body["post"]["post_url"]).to eq(topic.first_post.url)
        expect(topic.kuu_buddy_activity.capacity).to eq(3)
      end

      it "rejects missing fields" do
        post "/kuu-buddy/activities.json", params: params.except(:schedule)

        expect(response.status).to eq(400)
      end

      it "rejects a capacity over the chat group limit" do
        SiteSetting.chat_max_direct_message_users = 5

        post "/kuu-buddy/activities.json", params: params.merge(capacity: 6)

        expect(response.status).to eq(422)
      end
    end
  end

  describe "#update and #update_status" do
    fab!(:topic) { Fabricate(:topic, user: author, category:) }
    fab!(:first_post) { Fabricate(:post, topic:, user: author) }
    fab!(:activity) { Fabricate(:kuu_buddy_activity, topic:) }

    it "lets the author edit" do
      sign_in(author)

      put "/kuu-buddy/activities/#{topic.id}.json",
          params: {
            title: "爬大文字山",
            capacity: 6,
            schedule: "周日",
          }

      expect(response.status).to eq(204)
      expect(topic.reload.title).to eq("爬大文字山")
    end

    it "forbids others from editing" do
      sign_in(Fabricate(:user))

      put "/kuu-buddy/activities/#{topic.id}.json",
          params: {
            title: "x",
            capacity: 2,
            schedule: "y",
          }

      expect(response.status).to eq(403)
    end

    it "changes the status and returns the activity" do
      sign_in(author)

      put "/kuu-buddy/activities/#{topic.id}/status.json", params: { status: "started" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["activity"]).to include(
        "status" => "started",
        "statuses_reachable" => ["ended"],
      )
    end

    it "refuses unreachable statuses" do
      sign_in(author)

      put "/kuu-buddy/activities/#{topic.id}/status.json", params: { status: "ended" }

      expect(response.status).to eq(422)
    end
  end

  describe "topic and list serializers" do
    fab!(:topic) { Fabricate(:topic, user: author, category:) }
    fab!(:first_post) { Fabricate(:post, topic:, user: author) }
    fab!(:activity) { Fabricate(:kuu_buddy_activity, topic:, requirements: "会打日麻") }

    it "shows the activity on the topic, with the buttons only for the author" do
      get "/t/#{topic.id}.json"

      expect(response.parsed_body["kuu_buddy_activity"]).to include(
        "status" => "recruiting",
        "capacity" => 4,
        "member_count" => 1,
        "spots_left" => 3,
        "can_manage" => false,
      )
      expect(response.parsed_body["kuu_buddy_activity"]).not_to have_key("statuses_reachable")

      sign_in(author)
      get "/t/#{topic.id}.json"

      expect(response.parsed_body["kuu_buddy_activity"]).to include(
        "can_manage" => true,
        "statuses_reachable" => ["started"],
      )
    end

    it "puts the card data on the list" do
      get "/c/#{category.slug}/#{category.id}.json"

      item = response.parsed_body["topic_list"]["topics"].find { it["id"] == topic.id }
      expect(item["kuu_buddy_card"]).to include(
        "status" => "recruiting",
        "schedule" => "这周六 19:00 左右",
        "requirements" => "会打日麻",
        "capacity" => 4,
        "member_count" => 1,
        "members" => [include("username" => author.username)],
      )
    end

    it "puts the organizer first, then the members, without extra queries per topic" do
      member = Fabricate(:kuu_buddy_member, activity:).user
      get "/c/#{category.slug}/#{category.id}.json"

      other = Fabricate(:kuu_buddy_activity, topic: Fabricate(:topic_with_op, category:))
      2.times { Fabricate(:kuu_buddy_member, activity: other) }
      queries = track_sql_queries { get "/c/#{category.slug}/#{category.id}.json" }
      initial = queries.count { it.include?("kuu_buddy") }

      3.times do
        extra = Fabricate(:kuu_buddy_activity, topic: Fabricate(:topic_with_op, category:))
        Fabricate(:kuu_buddy_member, activity: extra)
      end
      queries = track_sql_queries { get "/c/#{category.slug}/#{category.id}.json" }

      expect(queries.count { it.include?("kuu_buddy") }).to eq(initial)
      item = response.parsed_body["topic_list"]["topics"].find { it["id"] == topic.id }
      expect(item["kuu_buddy_card"]["members"].map { it["username"] }).to eq(
        [author.username, member.username],
      )
    end

    it "drops the activity once the topic leaves the buddy board" do
      topic.update!(category: Fabricate(:category))

      get "/t/#{topic.id}.json"

      expect(response.parsed_body).not_to have_key("kuu_buddy_activity")
    end
  end
end
