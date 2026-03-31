<template>
  <AppPage :show-footer="false">
    <div class="workbench-page">
      <section class="workbench-hero">
        <div class="workbench-hero__main">
          <n-avatar
            :src="userStore.avatar"
            :size="72"
            round
            class="workbench-hero__avatar"
          >
            {{ (userStore.displayName || userStore.name || 'U').slice(0, 1) }}
          </n-avatar>

          <div class="workbench-hero__copy">
            <p class="workbench-hero__eyebrow">Workbench</p>
            <h1>{{ userStore.displayName || userStore.name }}，欢迎回来</h1>
            <p>从这里快速进入用户、角色、部门和审计日志等核心后台模块。</p>
            <div class="workbench-hero__tags">
              <n-tag round type="success">{{ userStore.isActive ? '账号正常' : '账号停用' }}</n-tag>
              <n-tag round type="warning">{{ userStore.isSuperUser ? '管理员' : '普通用户' }}</n-tag>
              <n-tag v-for="role in roleNames" :key="role" round>{{ role }}</n-tag>
            </div>
          </div>
        </div>

        <div class="workbench-hero__stats">
          <div v-for="item in overviewStats" :key="item.label" class="workbench-stat">
            <span>{{ item.label }}</span>
            <strong>{{ item.value }}</strong>
            <small>{{ item.hint }}</small>
          </div>
        </div>
      </section>

      <div class="workbench-grid">
        <section class="workbench-panel">
          <div class="workbench-panel__header">
            <div>
              <p class="workbench-panel__eyebrow">Quick Access</p>
              <h3>常用入口</h3>
              <p>高频页面直接进入，减少后台层层点击。</p>
            </div>
          </div>

          <div class="workbench-shortcuts">
            <button
              v-for="item in quickActions"
              :key="item.to"
              type="button"
              class="workbench-shortcut"
              @click="router.push(item.to)"
            >
              <div class="workbench-shortcut__icon">
                <TheIcon :icon="item.icon" :size="20" />
              </div>
              <div class="workbench-shortcut__copy">
                <strong>{{ item.label }}</strong>
                <span>{{ item.desc }}</span>
              </div>
            </button>
          </div>
        </section>

        <section class="workbench-panel">
          <div class="workbench-panel__header">
            <div>
              <p class="workbench-panel__eyebrow">System Status</p>
              <h3>当前状态</h3>
              <p>保留最少但有用的信息，方便确认当前登录环境。</p>
            </div>
          </div>

          <div class="workbench-insights">
            <div class="workbench-insight">
              <span>当前时间</span>
              <strong>{{ currentTimeLabel }}</strong>
            </div>
            <div class="workbench-insight">
              <span>登录账号</span>
              <strong>{{ userStore.name || '--' }}</strong>
            </div>
            <div class="workbench-insight">
              <span>角色数量</span>
              <strong>{{ roleNames.length || 1 }}</strong>
            </div>
            <div class="workbench-insight">
              <span>后台范围</span>
              <strong>App / Backend / Admin</strong>
            </div>
          </div>
        </section>
      </div>
    </div>
  </AppPage>
</template>

<script setup>
import { useUserStore } from '@/store'
import TheIcon from '@/components/icon/TheIcon.vue'

const router = useRouter()
const userStore = useUserStore()

const roleNames = computed(() => (userStore.role || []).map(item => item.name).filter(Boolean))

const quickActions = [
  {
    to: '/system/user',
    label: '用户管理',
    desc: '账号、启停与密码重置',
    icon: 'material-symbols:group-outline-rounded',
  },
  {
    to: '/system/role',
    label: '角色权限',
    desc: '菜单与接口授权',
    icon: 'material-symbols:key-vertical-outline-rounded',
  },
  {
    to: '/system/dept',
    label: '部门结构',
    desc: '组织树与排序维护',
    icon: 'material-symbols:account-tree-outline-rounded',
  },
  {
    to: '/system/auditlog',
    label: '审计日志',
    desc: '请求与响应记录查看',
    icon: 'material-symbols:monitoring-outline-rounded',
  },
]

const currentTimeLabel = computed(() =>
  new Intl.DateTimeFormat('zh-CN', {
    month: 'numeric',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date())
)

const overviewStats = computed(() => [
  {
    label: '角色数量',
    value: roleNames.value.length || 1,
    hint: '当前账号权限组',
  },
  {
    label: '快捷入口',
    value: quickActions.length,
    hint: '高频后台页面',
  },
  {
    label: '账号状态',
    value: userStore.isActive ? '正常' : '停用',
    hint: '当前登录状态',
  },
  {
    label: '工作范围',
    value: '统一后台',
    hint: 'App 与管理端联动',
  },
])
</script>

<style scoped>
.workbench-page {
  display: grid;
  gap: 24px;
}

.workbench-hero {
  display: grid;
  gap: 22px;
  padding: 26px 28px;
  border-radius: 30px;
  background:
    radial-gradient(circle at top right, rgba(255, 192, 128, 0.2), transparent 30%),
    linear-gradient(135deg, #205b63 0%, #2f6f6a 48%, #d99349 100%);
  color: #fff;
}

.workbench-hero__main {
  display: flex;
  align-items: center;
  gap: 18px;
}

.workbench-hero__avatar {
  border: 3px solid rgba(255, 255, 255, 0.2);
  background: rgba(255, 255, 255, 0.12);
}

.workbench-hero__eyebrow,
.workbench-panel__eyebrow {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
}

.workbench-hero__copy h1 {
  margin: 0;
  font-size: 34px;
  line-height: 1.08;
}

.workbench-hero__copy p {
  margin: 12px 0 0;
  font-size: 15px;
  line-height: 1.6;
  opacity: 0.9;
}

.workbench-hero__tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 14px;
}

.workbench-hero__stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
}

.workbench-stat {
  display: grid;
  gap: 6px;
  padding: 16px 18px;
  border-radius: 20px;
  background: rgba(11, 18, 22, 0.16);
  backdrop-filter: blur(8px);
}

.workbench-stat span {
  font-size: 12px;
  opacity: 0.76;
}

.workbench-stat strong {
  font-size: 26px;
  line-height: 1;
}

.workbench-stat small {
  opacity: 0.76;
}

.workbench-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.2fr) minmax(320px, 0.8fr);
  gap: 22px;
}

.workbench-panel {
  padding: 22px;
  border-radius: 24px;
  border: 1px solid rgba(48, 71, 63, 0.08);
  background: #fff;
}

.workbench-panel__header h3 {
  margin: 0;
  color: #23322d;
}

.workbench-panel__header p:last-child {
  margin: 10px 0 0;
  color: #6f7c75;
  line-height: 1.6;
}

.workbench-shortcuts {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
  margin-top: 18px;
}

.workbench-shortcut {
  display: flex;
  align-items: flex-start;
  gap: 14px;
  padding: 16px;
  border: 1px solid rgba(48, 71, 63, 0.08);
  border-radius: 20px;
  background: linear-gradient(180deg, #fbfdfc 0%, #f6faf8 100%);
  text-align: left;
  transition: transform 0.2s ease, box-shadow 0.2s ease, border-color 0.2s ease;
}

.workbench-shortcut:hover {
  transform: translateY(-2px);
  box-shadow: 0 16px 36px rgba(44, 65, 56, 0.08);
  border-color: rgba(48, 71, 63, 0.14);
}

.workbench-shortcut__icon {
  display: grid;
  place-items: center;
  width: 42px;
  height: 42px;
  border-radius: 14px;
  background: linear-gradient(135deg, rgba(236, 246, 240, 0.95), rgba(255, 248, 235, 0.95));
  color: #275549;
}

.workbench-shortcut__copy strong,
.workbench-insight strong {
  display: block;
  color: #23322d;
}

.workbench-shortcut__copy span,
.workbench-insight span {
  display: block;
  margin-top: 6px;
  font-size: 13px;
  line-height: 1.5;
  color: #6f7c75;
}

.workbench-insights {
  display: grid;
  gap: 12px;
  margin-top: 18px;
}

.workbench-insight {
  padding: 14px 16px;
  border-radius: 18px;
  background: #f5f8f6;
}

@media (max-width: 980px) {
  .workbench-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 720px) {
  .workbench-hero__main {
    flex-direction: column;
    align-items: flex-start;
  }

  .workbench-hero__stats,
  .workbench-shortcuts {
    grid-template-columns: 1fr;
  }

  .workbench-hero {
    padding: 20px;
    border-radius: 24px;
  }
}
</style>
