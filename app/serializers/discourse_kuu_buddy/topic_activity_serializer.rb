# frozen_string_literal: true

module DiscourseKuuBuddy
  # 帖子页用：状态、四行信息、切换按钮，以及修改表单回填的字段
  class TopicActivitySerializer < ActivitySerializer
    attributes :can_manage, :statuses_reachable, :expires_at

    def can_manage
      scope.can_manage_kuu_buddy_activity?(object)
    end

    def statuses_reachable
      object.statuses_reachable
    end

    def include_statuses_reachable?
      can_manage
    end

    def include_expires_at?
      can_manage && object.recruiting?
    end
  end
end
