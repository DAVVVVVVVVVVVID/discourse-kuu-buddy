# frozen_string_literal: true

module DiscourseKuuBuddy
  # 一次申请，以及接受以后的成员身份。记录不删：
  # - pending 等发起人处理；withdrawn 申请人撤回；declined 被婉拒（不能再申请这个帖子）
  # - accepted 是成员；left 成员自己退出（可以再申请）；removed 被发起人移出（不能再申请）
  # 防刷按这些记录的申请和撤回时间数
  class Application < ActiveRecord::Base
    self.table_name = "kuu_buddy_applications"

    MESSAGE_MAX_LENGTH = 100
    OPEN_STATUSES = %w[pending accepted].freeze
    # 被婉拒、被移出的人不能再申请这个帖子
    BARRED_STATUSES = %w[declined removed].freeze

    enum :status,
         {
           pending: "pending",
           withdrawn: "withdrawn",
           declined: "declined",
           accepted: "accepted",
           left: "left",
           removed: "removed",
         },
         validate: true

    belongs_to :activity
    belongs_to :user

    validates :message, length: { maximum: MESSAGE_MAX_LENGTH }

    scope :in_progress, -> { where(status: OPEN_STATUSES) }
    scope :ordered, -> { order(:created_at, :id) }

    # 防刷用：since（日本时间今天 0 点）之后的申请和撤回合计几次
    def self.actions_since(activity:, user:, since:)
      applications = where(activity:, user:)
      applications.where("created_at > ?", since).count +
        applications.where("withdrawn_at > ?", since).count
    end
  end
end

# == Schema Information
#
# Table name: kuu_buddy_applications
#
#  id           :bigint           not null, primary key
#  decided_at   :datetime
#  in_chat      :boolean          default(FALSE), not null
#  left_at      :datetime
#  message      :string           default(""), not null
#  status       :string           not null
#  withdrawn_at :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  activity_id  :bigint           not null
#  user_id      :integer          not null
#
# Indexes
#
#  index_kuu_buddy_applications_on_activity_id_and_status  (activity_id,status)
#  index_kuu_buddy_applications_on_open                    (activity_id,user_id) UNIQUE WHERE (((status)::text = 'pending'::text) OR ((status)::text = 'accepted'::text))
#  index_kuu_buddy_applications_on_user_id_and_status      (user_id,status)
#
