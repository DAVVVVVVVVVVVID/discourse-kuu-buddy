# frozen_string_literal: true

RSpec.describe DiscourseKuuBuddy::Activity::AcceptApplication do
  subject(:result) { described_class.call(params:, **dependencies) }

  # 聊天都用普通用户测：管理员会跳过 chat 的不少权限检查
  fab!(:organizer) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:applicant) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, user: organizer, category:) }
  fab!(:first_post) { Fabricate(:post, topic:, user: organizer) }
  fab!(:activity) { Fabricate(:kuu_buddy_activity, topic:, title: "周六打麻将", capacity: 3) }
  fab!(:application) { Fabricate(:kuu_buddy_application, activity:, user: applicant) }

  let(:params) { { topic_id: topic.id, application_id: application.id } }
  let(:dependencies) { { guardian: organizer.guardian } }

  before do
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
    SiteSetting.chat_enabled = true
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]
  end

  # chat 加人时以系统账号发「某某邀请了某某」，系统账号因此也进了群（chat 自己的行为），这里不算它
  def chat_user_ids
    activity.reload.chat_channel.chatable.users.human_users.pluck(:id)
  end

  context "when someone else accepts" do
    let(:dependencies) { { guardian: applicant.guardian } }

    it { is_expected.to fail_a_policy(:can_manage) }
  end

  context "when the request is not waiting" do
    before { application.update!(status: "withdrawn") }

    it { is_expected.to fail_to_find_a_model(:application) }
  end

  context "when the request belongs to another activity" do
    let(:params) { { topic_id: topic.id, application_id: Fabricate(:kuu_buddy_application).id } }

    it { is_expected.to fail_to_find_a_model(:application) }
  end

  context "when the activity already started" do
    before { activity.update!(status: "started", start_reason: "manual") }

    it { is_expected.to fail_a_policy(:has_spot) }
  end

  context "when accepting the first person" do
    it { is_expected.to run_successfully }

    it "makes them a member and notifies them" do
      expect { result }.to change { applicant.notifications.count }.by(1)

      expect(application.reload).to have_attributes(status: "accepted", in_chat: true)
      expect(applicant.notifications.last.data_hash[:message]).to eq(
        "kuu_buddy.notifications.accepted",
      )
    end

    it "creates a group chat named after the activity, with a link to the topic" do
      expect(result.chat_delivery).to eq(:joined)

      channel = activity.reload.chat_channel
      expect(channel).to be_direct_message_channel
      expect(channel.chatable).to be_group
      expect(channel.name).to eq("周六打麻将")
      expect(chat_user_ids).to contain_exactly(organizer.id, applicant.id)
      expect(channel.chat_messages.first.message).to include(topic.url)
    end
  end

  context "when the group chat already exists" do
    fab!(:member) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }

    before do
      Fabricate(:kuu_buddy_application, activity:, user: member).tap do
        described_class.call(params: { topic_id: topic.id, application_id: it.id }, **dependencies)
      end
    end

    it "adds the person to it" do
      channel_id = activity.reload.chat_channel_id

      expect(result.chat_delivery).to eq(:joined)
      expect(activity.reload.chat_channel_id).to eq(channel_id)
      expect(chat_user_ids).to contain_exactly(organizer.id, member.id, applicant.id)
    end

    it "starts the activity once it is full" do
      result

      expect(activity.reload).to have_attributes(status: "started", start_reason: "full")
    end
  end

  context "when the person does not accept direct messages" do
    before { applicant.user_option.update!(allow_private_messages: false) }

    it "still makes them a member, and says they could not be added to the chat" do
      expect(result).to run_successfully
      expect(result.chat_delivery).to eq(:unavailable)
      expect(application.reload).to have_attributes(status: "accepted", in_chat: false)
      expect(activity.reload.chat_channel_id).to be_nil
    end
  end

  context "when the person ignores the organizer" do
    before do
      Fabricate(
        :ignored_user,
        user: applicant,
        ignored_user: organizer,
        expiring_at: 1.year.from_now,
      )
    end

    it "says they could not be added" do
      expect(result.chat_delivery).to eq(:unavailable)
    end
  end

  context "when the person turned chat off" do
    before { applicant.user_option.update!(chat_enabled: false) }

    it "says they could not be added" do
      expect(result.chat_delivery).to eq(:unavailable)
    end
  end

  context "when the organizer cannot send direct messages" do
    before { organizer.user_option.update!(allow_private_messages: false) }

    it "says the chat failed" do
      expect(result.chat_delivery).to eq(:failed)
      expect(application.reload.status).to eq("accepted")
    end
  end

  context "when chat is off for the site" do
    before { SiteSetting.chat_enabled = false }

    it "still accepts" do
      expect(result.chat_delivery).to eq(:failed)
      expect(application.reload.status).to eq("accepted")
    end
  end
end
