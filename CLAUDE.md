# discourse-kuu-buddy（给 Claude Code）

## 这是什么
- 京大中文论坛「京圈」（KUU，京都大学学生论坛，Discourse 自托管，https://kyotooo.com ）的「搭子广场」插件：发帖找搭子（麻将组局、爬山、饭搭子……），别人申请加入，发起人接受后自动建群聊
- 需求以 GitHub Issue #1 为准（https://github.com/DAVVVVVVVVVVVID/discourse-kuu-buddy/issues/1 ，规则和 David 确认的 7 个界面都写在里面）。技术方案在 Notion「项目中心 › 项目文档 › 京大论坛｜搭子广场插件技术方案」（https://app.notion.com/p/40443ea2113c81c9a370d177784d76fe ），方案有变化要同步，在改动处写日期
- 参考实现：二手市场插件 `~/discourse/plugins/discourse-kuu-market`（结构几乎一样：专用表单发帖、帖子上的面板和按钮、状态切换、隐藏话题、chat 私聊）。**不要改别的插件**，需要它们配合的写进 PR 交给 KUU
- 线上部署不归本仓库管，由 KUU 运维那边负责（David 的私有仓库 kuu-forum，另一个 Claude Code 会话）。本仓库只写部署说明
- 本仓库是**公开**的：不要提交密钥、敏感信息、用户数据

## 已确定的规则（不要自行改，要改先问 David）
1. 新分类「搭子广场」（设置 `kuu_buddy_category`），**只能用表单发新帖**（普通编辑器发到这个分类会在后端被拒，管理员除外）。发帖照常走 NewPostManager
2. 表单字段：活动内容（必填，就是标题，≤40 字）、人数（必填，**总人数含发起人**，2～`chat_max_direct_message_users`，线上是 20）、时间（必填，自由填一句话）、参加条件（选填，空着显示「无条件，欢迎所有人」）、补充说明（选填）。标题和第一楼由表单生成，发起人随时能「修改」，不受编辑时限
3. 状态：**招募中** →（人满自动，或发起人点「开始活动」）→ **活动开始** →（发起人点「活动结束」）→ **已结束**。人满 / 开始后不接受新申请。**人满自动开始的**，有成员退出或被移出、人数不满时自动回到招募中
4. 招募中满 **30 天**（`kuu_buddy_expire_days`）没开始自动过期，站内通知发起人；过期的帖子发起人可以「重新开放」（回到招募中，30 天重新计时）
5. 已结束：不出现在列表和搜索里（core 的隐藏话题），链接能打开，所有人能在发起人主页的「话题」里看到
6. 状态切换只有发起人和管理员能做
7. 申请（第二期）：弹窗可写一句话（选填，≤100 字）；每人每帖只能有一个进行中的申请，可以撤回；被婉拒后不能再申请这个帖子；发起人自己没有按钮；未登录点击跳登录。**申请列表只有发起人和管理员能看到**。发起人收到站内通知；被接受 / 婉拒时申请人收到通知（婉拒说法委婉：「这次没能加入，下次再约～」）。防刷：同一帖子每人每天申请 + 撤回合计有上限（设置，默认 5，日本时间 0 点清零）
8. 群聊（第二期）：发起人**接受第一个人**时用 chat 的服务建多人私聊（名字用活动内容），之后每接受一个人加进群。插件记住发起人是群主；移出成员只能在帖子上由发起人操作，成员可以在帖子上退出，在 chat 里自己退出也要同步。对方关了私聊 / 屏蔽了发起人时加不进去，帖子上提示。活动结束时发起人选择保留（变成普通群聊，插件不再管）或关闭群聊
9. 公开范围：已加入的成员（头像、人数）所有人能看到；申请只给发起人看
10. 不是插件发的帖子（比如分类置顶的规则帖），插件一律不管；移出搭子广场的帖子也不再管
11. 不做：按时间提醒、评价搭子、站内通知以外的通知渠道

## 开发中自己定的技术细节（PR 里说明过，David 可以改）
- 已结束的帖子**不关闭回复**（Issue 只要求不出现在列表和搜索里）
- 过期的帖子和已结束一样隐藏，但主页上只有发起人自己看得到（和二手的过期一致）
- 只有人满自动开始的才会在有人退出时回到招募中；发起人手动「开始活动」的不会（`start_reason`）
- 招募中不能直接「活动结束」（Issue 的状态流程没有这一步），发起人不办了可以删帖
- 列表筛选（`kuu_buddy` 参数）：「招募中」「我发起的」，都不选时显示全部（招募中 + 活动开始）。「我发起的」连自己已结束、过期的一起显示
- 第一楼正文和帖子上方的面板内容一样，插件开着时由 CSS 藏起来（`post-class` 加 `kuu-buddy-first-post`）
- 个人主页放出隐藏帖：和二手插件共用 `KuuProfileTopics`（plugin.rb 开头那一段，两个插件要保持一样，二手 Issue #19）。各插件往 `SOURCES` 登记自己的来源、各自注册 modifier，条件由 `reveal` 合成一个 OR。**不能只注册一次**：core 只在登记 modifier 的插件开着时才执行它
- **不要用包裹型的 `topic-link` outlet**：它只能有一个插件用，二手插件在用。搭子以前也包了它，结果二手卡片不见、管理员每行看到警告（Issue #6，2026-10-25 线上事故）。`about.json` 让 CI 一起装二手插件，`spec/system/with_market_spec.rb` 测两种卡片同时在
- custom 类型的站内通知只能登记一种显示，二手插件也登记了。本插件等第一次换页时在当时登记的显示上再包一层（`lib/kuu-buddy-notifications.js`），不会覆盖二手的
- 申请和成员是同一张表 `kuu_buddy_applications`：pending / withdrawn / declined / accepted（成员）/ left（自己退出，可以再申请）/ removed（被移出，不能再申请）
- 群聊（PR #3 起）：
  - 建群、加人都以**发起人的身份**调 chat 的服务（`Chat::CreateDirectMessageChannel`、`Chat::AddUsersToChannel`），chat 的权限检查照常；对方关了私聊、屏蔽了发起人、关了聊天时照样成为成员，帖子上提示发起人
  - 群里第一条消息是帖子链接，以发起人的身份发（系统账号在多人私聊里发言会被加进群）。chat 自己加人时会以系统账号发「某某邀请了某某」，系统账号因此也在群里（chat 的行为，人数上限算上它刚好是 20）
  - 成员自己退出：以成员的身份 `Chat::LeaveChannel`；被移出：chat 只允许管理员移出多人私聊的成员，由系统账号 `Chat::RemoveUserFromChannel`
  - 在 chat 里自己离开群聊：群聊成员记录被删时（`Chat::UserChatChannelMembership` 的 after_commit）排后台任务 `KuuBuddySyncChatLeave`，成员当作退出；**发起人**离开的话插件忘掉这个群，下次接受时重新建
  - 活动结束时「关闭群聊」：系统账号 `Chat::UpdateChannelStatus` 改成 `closed`（大家还能看记录，不能发消息）。没选归档（chat 的归档是把消息搬进话题，只给公开频道用）、也没选删除频道（聊天记录就没了）
  - 活动结束以后插件不再管群聊：不再同步退出，帖子上也不能退出 / 移出

## 「新建话题」按钮
- 由插件 `discourse-kuu-new-topic` 统一处理，本插件**不要**自己注册 `create-topic-button-click` / `can-create-topic-button`，只向它登记类型（`kuu-buddy-activity`）：在搭子广场分类里直接打开表单，其他地方出现在选择框里（「找搭子」）
- 它是硬依赖：`about.json` 里声明了 CI 测试时一起安装；部署时要一起装（线上已经装了）
- 搭子广场分类页右下角还有樱花粉的「+ 找搭子」按钮（插件自己画的，界面 1）

## 和主题的分工
- 主题组件「KUU 自定义组件」（`~/discourse/plugins/discourse-kuu-theme`）负责：把搭子广场加进「独立页面」（「‹ 首页 搭子广场」顶栏）、侧边栏入口、手机瀑布流排除这个分类（`waterfall_excluded_category_ids`，否则手机上卡片被瀑布流接管）。KUU 给主题开 Issue
- 插件负责：列表卡片（标题旁的状态挂 `topic-list-after-title`，标题下方的内容挂 `topic-list-main-link-bottom`）、筛选、帖子页面板、表单、样式。话题列表项上加类名 `kuu-buddy-activity`、`kuu-buddy-status-<状态>`，主题需要时照着写 CSS
- 品牌色：藏青 `#0A2D56`、樱花粉 `#ED8690`、浅雾蓝 `#C0D1E4`、米白 `#FCF9F2`；招募中标签绿 `#1E7B3C` 底 `#E6F4EA`

## 开发环境（共用，先读 `~/.claude/CLAUDE.md`）
- 本仓库在 WSL 的 `~/discourse/plugins/discourse-kuu-buddy`，Discourse 源码在 `~/discourse`（官方仓库，不要改）
- **容器、开发服务器、内存是几个会话共用的**：`discourse_dev` 在跑就直接用，不停、不重启；开发服务器在跑就直接用，不要 kill。重任务（系统测试、截图、重启开发服务器）用 `flock ~/discourse/tmp/kuu-heavy.lock` 排队，跑之前看 `free -m`，可用不到 1G 先等
- 测试：在本目录执行 `kuu-rspec spec/xxx_spec.rb`（本插件用 `discourse_test_9`），加了迁移先 `kuu-rspec --migrate`。只跑和改动相关的文件，整套交给 GitHub CI
- 系统测试要前端构建：
  - core 的前端由 Rolldown 构建（`bin/dev` 里的 ember 那一半，或者单独 `docker exec -d -u discourse -w /src discourse_dev bash -lc 'pnpm --dir frontend/discourse start'`），进程不在时系统测试报 `Frontend build error`。Rolldown 起来以后约占 2.8GB
  - **插件的 JS 不归 Rolldown 管**，由 Rails 开发服务器里的监视进程编译到 `~/discourse/app/assets/generated/discourse-kuu-buddy`。没开 `bin/dev` 时，改了插件 JS 要手动编译一次：`docker exec -u discourse -w /src -e LOAD_PLUGINS=1 discourse_dev bin/rake assets:precompile:build_plugins`，否则系统测试跑的是旧代码（新插件第一次连页面都不显示）
- **测试环境的样式表只在第一次跑系统测试时算一次版本号**，之后改了 SCSS 不会重新编译（现象：系统测试、截图里插件的新样式缺失）。删掉本插件那份清单再跑：`rm -f ~/discourse/tmp/cache/assets/test/stylesheet-manifest-test_9`（只删 `_9`，别的编号是别的会话的）
- 截图（7 个界面，电脑 + iPhone 宽度）：本地的 `spec/system/screenshots_spec.rb`（写在 `.git/info/exclude` 里，不提交），`kuu-rspec spec/system/screenshots_spec.rb`，图片在 `screenshots/`。用的是测试库，不碰共用的开发库；测试环境没有 FKB Pro 和 KUU 主题，样式以插件自己的为准
- lint 在容器里跑：`docker exec -u discourse -w /src discourse_dev bin/lint --fix plugins/discourse-kuu-buddy/<文件...>`。CI 还会跑插件自己的 `pnpm lint`（含类型检查）：`docker exec -u discourse -w /src/plugins/discourse-kuu-buddy discourse_dev pnpm lint`
  - `bin/lint` 会不带 `--frozen-lockfile` 装一次依赖，把 `pnpm-lock.yaml` 改掉。提交前 `git checkout pnpm-lock.yaml`
  - `pnpm-lock.yaml` 开头那一段（`packageManagerDependencies`，记录 `package.json` 锁定的 pnpm 12.11.2）不能删：CI 镜像里的 pnpm 版本和它不一样时要靠这一段切换，少了会在 CI 的 lint 报 `ERR_PNPM_FROZEN_LOCKFILE_WITH_OUTDATED_LOCKFILE`（2026-10-26）。重新生成用别的 pnpm 版本装一次：`npx -y pnpm@12.10.0 install`
  - rubocop 自动改出的长行 stree 不会再格式化，看到 rubocop 有 `corrected` 时再跑一遍 `bin/lint --fix`
- 改了数据库要更新模型末尾的 Schema 注释（CI 的 annotations 检查）。**以 CI 的输出为准**：CI 的测试镜像（`discourse/discourse_test:slim`）2026-10-26 更新后，PostgreSQL 打印部分索引条件的格式和本地容器（PG 18.6）不一样，本地生成的注释可能过不了 CI，照 CI 失败日志里给的 diff 改。本地生成：`docker exec -u discourse -w /src -e RAILS_ENV=test -e TEST_ENV_NUMBER=9 -e LOAD_PLUGINS=1 -e SKIP_OPTIMIZE_ICONS=1 discourse_dev bin/annotaterb models --force --model-dir plugins/discourse-kuu-buddy/app/models`
- 开发库（`discourse_development`）大家共用：为了测试改了站点设置、用户设置，测完改回来，并在回复里写明
- 截图、临时文件放 `screenshots/`（不提交）或 `~/discourse/tmp/discourse-kuu-buddy/`
- `plugin.rb` 的 `required_version` 保持 `2026.1.0`，**不要写当前版本号**（开发和线上是 `2026.10.0-latest`，比 `2026.10.0` 低，写高了插件不激活、Rails 启动报错）
- 插件总开关 `kuu_buddy_enabled` 默认关闭，开发环境要在后台打开

## 约定
- 插件名 `discourse-kuu-buddy`，Ruby 模块 `DiscourseKuuBuddy`，接口挂在 `/kuu-buddy`，站点设置以 `kuu_buddy_` 开头，前端类名以 `kuu-buddy-` 开头（BEM）
- 代码标识符用英文；面向用户的文案放在 `config/locales/`（zh_CN 和 en 都要有）
- 跟着 Discourse 官方插件的写法走：Service::Base 服务、Glimmer 组件（.gjs）、plugin outlet、FormKit 表单、ui-kit（`discourse/ui-kit/*`），**不要改 core**
- 每个功能都要写测试：后端 RSpec，表单、按钮这类前端交互用 system spec
- 涉及聊天、通知的测试用**普通用户**跑，不要用管理员（管理员会跳过 chat 的很多权限检查）。线上 `direct_message_enabled_groups` 包含信任等级 0、1，测试里照这个设
- 提交信息用中文；推送前跑相关测试
- `main` 有保护（PR + 1 人批准 + CI），从 `main` 开分支、走 PR；**main 必须随时能上线**（线上 rebuild 直接 clone main）
- 部署到线上（改 `app.yml`、rebuild、建分类、改设置）由 KUU 那边负责，必须先得到 David 的同意。部署说明里不要替 David 表态
- 规则相关的改动先问 David；纯技术细节自己定，写进 PR 和 Notion 方案
- 用中文交流
