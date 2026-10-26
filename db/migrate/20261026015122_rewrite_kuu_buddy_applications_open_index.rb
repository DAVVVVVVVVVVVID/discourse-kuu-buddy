# frozen_string_literal: true

# 部分索引的条件从 status IN (...) 改成 OR，意思不变。IN 的写法 PostgreSQL 存下来以后，
# 从头迁移和载入数据库结构时打印出的格式不一样，CI 的 Schema 注释检查时过时不过；OR 的写法两种情况都一样
class RewriteKuuBuddyApplicationsOpenIndex < ActiveRecord::Migration[8.1]
  def up
    remove_index :kuu_buddy_applications, name: "index_kuu_buddy_applications_on_open"
    add_index :kuu_buddy_applications,
              %i[activity_id user_id],
              unique: true,
              where: "status = 'pending' OR status = 'accepted'",
              name: "index_kuu_buddy_applications_on_open"
  end

  def down
    remove_index :kuu_buddy_applications, name: "index_kuu_buddy_applications_on_open"
    add_index :kuu_buddy_applications,
              %i[activity_id user_id],
              unique: true,
              where: "status IN ('pending', 'accepted')",
              name: "index_kuu_buddy_applications_on_open"
  end
end
