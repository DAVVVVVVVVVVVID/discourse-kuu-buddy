# frozen_string_literal: true

# 成员退出、被移出，以及在 chat 里自己离开群聊
RSpec.describe "Leaving a buddy activity" do
  fab!(:organizer) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:member) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:other_member) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, user: organizer, category:) }
  fab!(:first_post) { Fabricate(:post, topic:, user: organizer) }
  fab!(:activity) { Fabricate(:kuu_buddy_activity, topic:, capacity: 3) }

  before do
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
    SiteSetting.chat_enabled = true
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]

    # 走正常流程：申请、接受（建群、加群），两个人加入后人满自动开始
    [member, other_member].each do |user|
      application =
        DiscourseKuuBuddy::Activity::Apply.call(
          params: {
            topic_id: topic.id,
          },
          guardian: user.guardian,
        ).application
      DiscourseKuuBuddy::Activity::AcceptApplication.call(
        params: {
          topic_id: topic.id,
          application_id: application.id,
        },
        guardian: organizer.guardian,
      )
    end
    activity.reload
  end

  def channel
    activity.reload.chat_channel
  end

  def in_chat?(user)
    Chat::UserChatChannelMembership.exists?(user:, chat_channel: channel)
  end

  it "starts full, with everyone in the chat" do
    expect(activity).to have_attributes(status: "started", start_reason: "full")
    expect([organizer, member, other_member].map { in_chat?(it) }).to all(eq(true))
  end

  describe DiscourseKuuBuddy::Activity::Leave do
    subject(:result) do
      described_class.call(params: { topic_id: topic.id }, guardian: member.guardian)
    end

    it "lets the member leave the activity and the chat, recruiting again" do
      expect(result).to run_successfully

      expect(activity.applications.find_by(user: member).status).to eq("left")
      expect(in_chat?(member)).to eq(false)
      expect(activity.reload).to have_attributes(status: "recruiting", member_count: 2)
    end

    it "keeps an activity the organizer started by hand going" do
      activity.update!(start_reason: "manual")

      result

      expect(activity.reload.status).to eq("started")
    end

    it "refuses once the activity ended" do
      activity.update!(status: "ended")

      expect(result).to fail_a_policy(:not_ended)
    end

    it "lets them apply again" do
      result
      activity.update!(status: "recruiting")

      expect(
        DiscourseKuuBuddy::Activity::Apply.call(
          params: {
            topic_id: topic.id,
          },
          guardian: member.guardian,
        ),
      ).to run_successfully
    end
  end

  describe DiscourseKuuBuddy::Activity::RemoveMember do
    subject(:result) do
      described_class.call(params: { topic_id: topic.id, user_id: member.id }, guardian:)
    end

    let(:guardian) { organizer.guardian }

    it "removes the member from the activity and the chat, recruiting again" do
      expect(result).to run_successfully

      expect(activity.applications.find_by(user: member).status).to eq("removed")
      expect(in_chat?(member)).to eq(false)
      expect(in_chat?(other_member)).to eq(true)
      expect(activity.reload.status).to eq("recruiting")
    end

    it "keeps them from applying again" do
      result

      expect(
        DiscourseKuuBuddy::Activity::Apply.call(
          params: {
            topic_id: topic.id,
          },
          guardian: member.guardian,
        ),
      ).to fail_a_policy(:not_barred)
    end

    context "when someone else tries" do
      let(:guardian) { other_member.guardian }

      it { is_expected.to fail_a_policy(:can_manage) }
    end
  end

  describe "leaving the group chat in chat itself" do
    it "counts as leaving the activity" do
      Chat::LeaveChannel.call(guardian: member.guardian, params: { channel_id: channel.id })

      expect_job_enqueued(
        job: Jobs::KuuBuddySyncChatLeave,
        args: {
          channel_id: channel.id,
          user_id: member.id,
        },
      )
      Jobs::KuuBuddySyncChatLeave.new.execute(channel_id: channel.id, user_id: member.id)

      expect(activity.applications.find_by(user: member)).to have_attributes(
        status: "left",
        in_chat: false,
      )
      expect(activity.reload.status).to eq("recruiting")
    end

    it "forgets the chat when the organizer leaves it, making a new one on the next accept" do
      old_channel_id = channel.id
      Chat::LeaveChannel.call(guardian: organizer.guardian, params: { channel_id: old_channel_id })
      Jobs::KuuBuddySyncChatLeave.new.execute(channel_id: old_channel_id, user_id: organizer.id)

      expect(activity.reload.chat_channel_id).to be_nil
      expect(activity.members.map(&:in_chat)).to all(eq(false))
    end

    it "is left alone once the activity ended" do
      activity.update!(status: "ended")

      Chat::LeaveChannel.call(guardian: member.guardian, params: { channel_id: channel.id })

      expect_not_enqueued_with(job: Jobs::KuuBuddySyncChatLeave)
      expect(activity.applications.find_by(user: member).status).to eq("accepted")
    end
  end

  describe "ending the activity" do
    def end_activity(close_chat:)
      DiscourseKuuBuddy::Activity::ChangeStatus.call(
        params: {
          topic_id: topic.id,
          status: "ended",
          close_chat:,
        },
        guardian: organizer.guardian,
      )
    end

    it "keeps the chat open when asked" do
      expect(end_activity(close_chat: false)).to run_successfully

      expect(channel).to be_open
      expect(activity.reload.chat_closed).to eq(false)
    end

    it "closes the chat for everyone when asked" do
      expect(end_activity(close_chat: true)).to run_successfully

      expect(channel).to be_closed
      expect(activity.reload.chat_closed).to eq(true)
      expect(member.guardian.can_create_channel_message?(channel)).to eq(false)
    end
  end
end
