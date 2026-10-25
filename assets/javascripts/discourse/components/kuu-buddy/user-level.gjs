import { i18n } from "discourse-i18n";

// 名字旁的「Lv3」：积分插件装着时后端才给 level，样式沿用积分插件的类名
const UserLevel = <template>
  {{#if @user.level}}
    <span class="kuu-points-level kuu-points-level--{{@user.level}}">{{i18n
        "kuu_buddy.level"
        level=@user.level
      }}</span>
  {{/if}}
</template>;

export default UserLevel;
