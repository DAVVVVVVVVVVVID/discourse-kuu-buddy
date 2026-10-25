# frozen_string_literal: true

class CreateKuuBuddyApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :kuu_buddy_applications do |t|
      t.bigint :activity_id, null: false
      t.integer :user_id, null: false
      t.string :status, null: false
      t.string :message, null: false, default: ""
      t.datetime :decided_at
      t.datetime :withdrawn_at
      t.datetime :left_at
      t.boolean :in_chat, null: false, default: false
      t.timestamps
    end

    add_index :kuu_buddy_applications, %i[activity_id status]
    add_index :kuu_buddy_applications, %i[user_id status]
    add_index :kuu_buddy_applications,
              %i[activity_id user_id],
              unique: true,
              where: "status IN ('pending', 'accepted')",
              name: "index_kuu_buddy_applications_on_open"
    add_check_constraint :kuu_buddy_applications,
                         "status IN ('pending', 'withdrawn', 'declined', 'accepted', 'left', 'removed')",
                         name: "kuu_buddy_applications_status"

    add_column :kuu_buddy_activities, :chat_channel_id, :bigint
    add_column :kuu_buddy_activities, :chat_closed, :boolean, null: false, default: false
    add_index :kuu_buddy_activities, :chat_channel_id, unique: true
  end
end
