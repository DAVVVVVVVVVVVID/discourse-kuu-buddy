# frozen_string_literal: true

class CreateKuuBuddyActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :kuu_buddy_activities do |t|
      t.integer :topic_id, null: false
      t.string :status, null: false
      t.string :title, null: false
      t.integer :capacity, null: false
      t.string :schedule, null: false
      t.string :requirements, null: false, default: ""
      t.text :description, null: false, default: ""
      t.datetime :recruiting_since, null: false
      t.datetime :started_at
      t.string :start_reason
      t.datetime :ended_at
      t.boolean :unlisted_by_plugin, null: false, default: false
      t.timestamps
    end

    add_index :kuu_buddy_activities, :topic_id, unique: true
    add_index :kuu_buddy_activities, %i[status recruiting_since]
    add_check_constraint :kuu_buddy_activities,
                         "status IN ('recruiting', 'started', 'ended', 'expired')",
                         name: "kuu_buddy_activities_status"
  end
end
