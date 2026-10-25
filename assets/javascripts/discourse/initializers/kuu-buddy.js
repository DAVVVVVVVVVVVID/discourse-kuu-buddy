import { withPluginApi } from "discourse/lib/plugin-api";
import Category from "discourse/models/category";
import ActivityCard from "../components/kuu-buddy/activity-card.gjs";
import ActivityCardStatus from "../components/kuu-buddy/activity-card-status.gjs";
import ActivityPanel from "../components/kuu-buddy/activity-panel.gjs";
import BuddyFilters from "../components/kuu-buddy/buddy-filters.gjs";
import ActivityForm from "../components/kuu-buddy/modal/activity-form.gjs";
import { buddyCategoryId } from "../lib/kuu-buddy.js";
import { registerBuddyNotifications } from "../lib/kuu-buddy-notifications.js";

export default {
  name: "kuu-buddy",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.kuu_buddy_enabled) {
      return;
    }

    const modal = container.lookup("service:modal");

    // 「新建话题」按钮由 discourse-kuu-new-topic 统一处理：在搭子广场分类里直接打开表单，
    // 其他地方出现在选择框里（「找搭子」）。不管从哪里打开，帖子都发到搭子广场分类。
    // 在搭子广场没有发帖权限的人看不到这一项
    container.lookup("service:kuu-new-topic")?.register({
      id: "kuu-buddy-activity",
      label: "kuu_buddy.new_topic.label",
      description: "kuu_buddy.new_topic.description",
      icon: "user-group",
      categoryIds: () => [buddyCategoryId(siteSettings)].filter(Boolean),
      inChooser: () =>
        !!Category.findById(buddyCategoryId(siteSettings))?.canCreateTopic,
      order: 0,
      open: () => modal.show(ActivityForm, { model: {} }),
    });

    withPluginApi((api) => {
      api.renderInOutlet("topic-above-posts", ActivityPanel);

      api.addDiscoveryQueryParam("kuu_buddy", {
        replace: true,
        refreshModel: true,
      });
      api.renderInOutlet("discovery-list-container-top", BuddyFilters);
      // 列表卡片：标题旁的状态 + 标题下方的内容。不用包裹型的 topic-link（二手插件在用，Issue #6）
      api.renderInOutlet("topic-list-after-title", ActivityCardStatus);
      api.renderInOutlet("topic-list-main-link-bottom", ActivityCard);

      // 第一楼由表单生成，发起人用「修改」按钮改；管理员保留普通编辑
      api.registerValueTransformer(
        "post-menu-buttons",
        ({ value: dag, context: { post, state } }) => {
          if (
            post.post_number === 1 &&
            post.topic?.kuu_buddy_activity &&
            !state.currentUser?.staff
          ) {
            dag.delete("edit");
          }
        }
      );

      // 第一楼的正文就是帖子上方面板里的四行信息，藏起来免得重复；插件关掉时正文照常显示
      api.registerValueTransformer("post-class", ({ value, context }) => {
        const { post } = context;
        if (post.post_number === 1 && post.topic?.kuu_buddy_activity) {
          return [...value, "kuu-buddy-first-post"];
        }
        return value;
      });

      api.registerValueTransformer(
        "topic-list-item-class",
        ({ value, context }) => {
          const card = context.topic.kuu_buddy_card;
          if (!card) {
            return value;
          }
          return [
            ...value,
            "kuu-buddy-activity",
            `kuu-buddy-status-${card.status}`,
          ];
        }
      );

      registerBuddyNotifications(api);
    });
  },
};
