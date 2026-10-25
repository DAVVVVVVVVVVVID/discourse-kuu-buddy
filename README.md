# discourse-kuu-buddy

京大中文论坛「京圈」（KUU）的搭子广场插件。

- 「搭子广场」分类里用插件的表单发帖找搭子：活动内容、人数（含发起人）、时间、参加条件、补充说明。标题和第一楼由插件生成
- 状态：招募中 → 活动开始（人满或发起人手动开始）→ 已结束；招募中满 30 天没开始自动过期，发起人可以重新开放
- 已结束、过期的帖子不再出现在列表和搜索里，链接仍能打开；已结束的留在发起人主页
- 别人申请加入，发起人接受后自动建聊天群聊（开发中）

需求见 [Issue #1](https://github.com/DAVVVVVVVVVVVID/discourse-kuu-buddy/issues/1)。依赖 [discourse-kuu-new-topic](https://github.com/DAVVVVVVVVVVVID/discourse-kuu-new-topic)（「新建话题」按钮）和 Discourse 自带的 chat。

## 站点设置

| 设置 | 默认 | 说明 |
|---|---|---|
| `kuu_buddy_enabled` | 关 | 总开关 |
| `kuu_buddy_category` | 空 | 搭子广场分类 |
| `kuu_buddy_expire_days` | 30 | 招募中多少天没开始自动过期 |

人数上限读 chat 的 `chat_max_direct_message_users`。

## 许可证

MIT
