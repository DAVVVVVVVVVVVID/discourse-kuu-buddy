import {
  getRenderDirector,
  registerNotificationTypeRenderer,
} from "discourse/lib/notification-types-manager";
import { i18n } from "discourse-i18n";

// 插件自己的站内通知（core 的 custom 类型）：data.message 是 server 端的 key，
// 显示用这里的图标和 js 文案，文案里的 %{username} 是 data.display_username
export const NOTIFICATIONS = {
  "kuu_buddy.notifications.applied": { key: "applied", icon: "user-plus" },
  "kuu_buddy.notifications.accepted": { key: "accepted", icon: "user-group" },
  "kuu_buddy.notifications.declined": { key: "declined", icon: "user-group" },
  "kuu_buddy.notifications.expired": {
    key: "expired",
    icon: "clock-rotate-left",
  },
};

// custom 类型的显示只能登记一个，后登记的覆盖前面的；二手插件也登记了它。
// 所以等所有插件的初始化器都跑完（第一次换页时），在当时登记的那个之上再包一层，
// 只接管自己的通知，其他的交给原来的显示（二手插件或 core）
export function registerBuddyNotifications(api) {
  let registered = false;

  api.onPageChange(() => {
    if (registered) {
      return;
    }
    registered = true;

    const Previous = getRenderDirector(
      "custom",
      { data: {} },
      api.getCurrentUser(),
      api.container.lookup("service:site-settings"),
      api.container.lookup("service:site")
    ).constructor;

    registerNotificationTypeRenderer(
      "custom",
      () =>
        class extends Previous {
          get #own() {
            return NOTIFICATIONS[this.notification.data.message];
          }

          get icon() {
            return this.#own?.icon ?? super.icon;
          }

          get label() {
            return this.#own
              ? i18n(`kuu_buddy.notifications.${this.#own.key}`, {
                  username: this.username,
                })
              : super.label;
          }

          get linkTitle() {
            return this.#own
              ? i18n(`kuu_buddy.notifications.${this.#own.key}_title`)
              : super.linkTitle;
          }
        }
    );
  });
}
