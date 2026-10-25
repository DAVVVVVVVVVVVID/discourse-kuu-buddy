import { i18n } from "discourse-i18n";

// 列表卡片（界面 1）上的状态文字：人满自动开始的叫「人满·活动开始」
export function cardStatusLabel({ status, start_reason }) {
  if (status === "started" && start_reason === "full") {
    return i18n("kuu_buddy.card_statuses.started_full");
  }
  return i18n(`kuu_buddy.card_statuses.${status}`);
}

export function spotsLeft({ capacity, member_count }) {
  return Math.max(capacity - member_count, 0);
}
