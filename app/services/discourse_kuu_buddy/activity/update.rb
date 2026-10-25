# frozen_string_literal: true

module DiscourseKuuBuddy
  # 发起人或管理员用表单修改搭子帖，不受编辑时限限制。标题和第一楼按表单重新生成，
  # 照常留下编辑记录；不顶帖，也不重新计算过期时间。改人数以后人满了自动开始，
  # 人满自动开始的改多了人数回到招募中
  class Activity::Update
    include Service::Base

    model :activity
    params default_values_from: :activity, base_class: Activity::Create::Contract
    policy :activity_in_category
    policy :can_edit_activity, class_name: Activity::Policy::CanManage
    model :revised_activity, :revise_activity
    # 不包事务：PostRevisor 自己会发 MessageBus、排后台任务，包进来会在提交前发出去。
    # 先改帖：改帖失败（比如屏蔽词）时记录不动；记录已校验过，save! 只会因数据库故障失败
    step :revise_first_post
    step :save_activity

    private

    def fetch_activity(params:)
      Activity.includes(topic: :first_post).find_by(topic_id: params.topic_id)
    end

    def activity_in_category(activity:)
      activity.in_category?
    end

    def revise_activity(activity:, params:)
      activity.tap do
        it.assign_attributes(params.activity_attributes)
        it.follow_member_count
      end
    end

    def revise_first_post(guardian:, revised_activity:)
      renderer = ActivityRenderer.new(revised_activity)
      post = revised_activity.topic.first_post

      FormSubmission.submit(renderer.title) do
        PostRevisor.new(post, revised_activity.topic).revise!(
          guardian.user,
          { title: renderer.title, raw: renderer.raw },
          bypass_bump: true,
        )
      end

      fail!(post.errors.full_messages.join("\n")) if post.errors.present?
    end

    def save_activity(revised_activity:)
      revised_activity.save!
    end
  end
end
