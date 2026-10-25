// 和后端 DiscourseKuuBuddy::Activity 的限制保持一致
export const TITLE_MAX_LENGTH = 40;
export const SCHEDULE_MAX_LENGTH = 40;
export const REQUIREMENTS_MAX_LENGTH = 100;
export const DESCRIPTION_MAX_LENGTH = 2000;
export const MIN_CAPACITY = 2;
export const DEFAULT_CAPACITY = 4;

// 界面 1 顶部的三个筛选，值写在网址的 kuu_buddy 里
export const LIST_FILTERS = ["recruiting", "mine"];

export function buddyCategoryId(siteSettings) {
  return parseInt(siteSettings.kuu_buddy_category, 10) || null;
}

// 总人数（含发起人）的上限跟着 chat 的群聊人数上限走
export function maxCapacity(siteSettings) {
  return Math.max(
    parseInt(siteSettings.chat_max_direct_message_users, 10) || 0,
    MIN_CAPACITY
  );
}

export function formDataFor(activity) {
  if (!activity) {
    return {
      title: "",
      capacity: DEFAULT_CAPACITY,
      schedule: "",
      requirements: "",
      description: "",
    };
  }

  return {
    title: activity.title,
    capacity: activity.capacity,
    schedule: activity.schedule,
    requirements: activity.requirements,
    description: activity.description,
  };
}

export function payloadFrom(data) {
  return {
    title: data.title?.trim(),
    capacity: data.capacity,
    schedule: data.schedule?.trim(),
    requirements: data.requirements?.trim() ?? "",
    description: data.description ?? "",
  };
}
