# frozen_string_literal: true

# Issue #1 验收清单的第一条，按顺序走一遍：发帖 → 申请（有 / 没有留言）→ 撤回 → 再申请 →
# 接受（建群）→ 再接受（加群）→ 婉拒 → 人满自动开始 → 成员退出回到招募中 → 发起人手动开始 →
# 结束（保留 / 关闭群聊两种）→ 过期。都用普通用户
RSpec.describe "The whole buddy flow from Issue #1" do
  fab!(:organizer) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:alice) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:bob) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:carol) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:dave) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:category)

  before do
    SiteSetting.kuu_buddy_enabled = true
    SiteSetting.kuu_buddy_category = category.id
    SiteSetting.chat_enabled = true
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]
  end

  def post_activity(title, capacity: 4)
    DiscourseKuuBuddy::Activity::Create
      .call(params: { title:, capacity:, schedule: "这周六 19:00 左右" }, guardian: organizer.guardian)
      .new_post_result
      .post
      .topic
      .kuu_buddy_activity
  end

  def apply(activity, user, message = "")
    DiscourseKuuBuddy::Activity::Apply.call(
      params: {
        topic_id: activity.topic_id,
        message:,
      },
      guardian: user.guardian,
    )
  end

  def decide(service, activity, application)
    service.call(
      params: {
        topic_id: activity.topic_id,
        application_id: application.id,
      },
      guardian: organizer.guardian,
    )
  end

  def change_status(activity, status, close_chat: false)
    DiscourseKuuBuddy::Activity::ChangeStatus.call(
      params: {
        topic_id: activity.topic_id,
        status:,
        close_chat:,
      },
      guardian: organizer.guardian,
    )
  end

  def chat_users(activity)
    activity.reload.chat_channel.chatable.users.human_users
  end

  it "works from posting to ending" do
    activity = post_activity("周六打麻将")
    expect(activity).to be_recruiting

    # 申请：有留言、没有留言
    alice_application = apply(activity, alice, "我会打日麻").application
    bob_application = apply(activity, bob).application
    expect([alice_application.message, bob_application.message]).to eq(["我会打日麻", ""])

    # 撤回 → 再申请
    DiscourseKuuBuddy::Activity::WithdrawApplication.call(
      params: {
        topic_id: activity.topic_id,
      },
      guardian: bob.guardian,
    )
    bob_application = apply(activity, bob).application
    expect(bob_application).to be_pending

    # 接受第一个人：建群
    expect(
      decide(DiscourseKuuBuddy::Activity::AcceptApplication, activity, alice_application),
    ).to run_successfully
    expect(chat_users(activity)).to contain_exactly(organizer, alice)

    # 再接受：加群
    decide(DiscourseKuuBuddy::Activity::AcceptApplication, activity, bob_application)
    expect(chat_users(activity)).to contain_exactly(organizer, alice, bob)

    # 婉拒
    carol_application = apply(activity, carol).application
    decide(DiscourseKuuBuddy::Activity::DeclineApplication, activity, carol_application)
    expect(apply(activity, carol)).to fail_a_policy(:not_barred)

    # 人满自动开始
    dave_application = apply(activity, dave).application
    decide(DiscourseKuuBuddy::Activity::AcceptApplication, activity, dave_application)
    expect(activity.reload).to have_attributes(status: "started", start_reason: "full")
    expect(apply(activity, Fabricate(:user, refresh_auto_groups: true))).to fail_a_policy(
      :can_apply,
    )

    # 成员退出 → 回到招募中
    DiscourseKuuBuddy::Activity::Leave.call(
      params: {
        topic_id: activity.topic_id,
      },
      guardian: dave.guardian,
    )
    expect(activity.reload).to be_recruiting
    expect(chat_users(activity)).not_to include(dave)

    # 发起人手动开始 → 结束，保留群聊
    expect(change_status(activity, "started")).to run_successfully
    expect(activity.reload).to have_attributes(status: "started", start_reason: "manual")
    expect(change_status(activity, "ended")).to run_successfully
    expect(activity.reload).to be_ended
    expect(activity.chat_channel).to be_open
    expect(activity.topic.reload.visible).to eq(false)

    # 另一个活动：结束时关闭群聊
    other = post_activity("周日爬山", capacity: 2)
    decide(DiscourseKuuBuddy::Activity::AcceptApplication, other, apply(other, alice).application)
    change_status(other, "ended", close_chat: true)
    expect(other.reload.chat_channel).to be_closed

    # 过期：招募中满 30 天
    stale = post_activity("找饭搭子")
    stale.update!(recruiting_since: 31.days.ago)
    Jobs::KuuBuddyExpireActivities.new.execute({})
    expect(stale.reload).to be_expired
    expect(organizer.notifications.last.data_hash[:message]).to eq(
      "kuu_buddy.notifications.expired",
    )
    expect(change_status(stale, "recruiting")).to run_successfully
    expect(stale.reload).to be_recruiting
  end
end
