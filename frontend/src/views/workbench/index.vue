<template>
  <AppPage :show-footer="false">
    <div class="workbench-page">
      <section class="workbench-hero">
        <div class="workbench-hero__main">
          <div class="workbench-hero__brand">
            <n-avatar
              :src="userStore.avatar"
              :size="76"
              round
              class="workbench-hero__avatar"
            >
              {{ (userStore.displayName || userStore.name || 'U').slice(0, 1) }}
            </n-avatar>

            <div>
              <p class="workbench-hero__eyebrow">运营中心</p>
              <h1>{{ userStore.displayName || userStore.name || '用户' }}，欢迎回来</h1>
            </div>
          </div>

          <p class="workbench-hero__summary">
            左侧切换模块，右侧集中处理用户、任务、语音和版本发布。
          </p>

          <div class="workbench-hero__status">
            <n-tag round type="success">{{ userStore.isActive ? '账号正常' : '账号停用' }}</n-tag>
            <n-tag round type="warning">{{ userStore.isSuperUser ? '管理员' : '普通用户' }}</n-tag>
            <n-tag v-for="role in roleNames" :key="role" round>{{ role }}</n-tag>
          </div>

          <div class="workbench-hero__stats">
            <article v-for="item in overviewStats" :key="item.label" class="workbench-hero__stat">
              <span>{{ item.label }}</span>
              <strong>{{ item.value }}</strong>
              <small>{{ item.hint }}</small>
            </article>
          </div>
        </div>

        <aside class="workbench-hero__aside">
          <div class="workbench-aside__head">
            <span>当前时间</span>
            <strong>{{ currentTimeLabel }}</strong>
          </div>

          <div class="workbench-aside__notes">
            <article class="workbench-aside__note">
              <span>登录账号</span>
              <strong>{{ userStore.name || '--' }}</strong>
            </article>
            <article class="workbench-aside__note">
              <span>系统边界</span>
              <strong>App / H5 / 后端 / 管理端</strong>
            </article>
            <article class="workbench-aside__note">
              <span>建议入口</span>
              <strong>用户、任务、版本发布</strong>
            </article>
          </div>
        </aside>
      </section>

      <div class="workbench-grid">
        <section class="workbench-panel">
          <div class="workbench-panel__header">
            <div>
              <p class="workbench-panel__eyebrow">快捷入口</p>
              <h3>常用入口</h3>
            </div>
            <span class="workbench-panel__hint">高频操作一眼直达</span>
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
                <TheIcon :icon="item.icon" :size="22" />
              </div>
              <div class="workbench-shortcut__copy">
                <strong>{{ item.label }}</strong>
                <span>{{ item.desc }}</span>
              </div>
              <TheIcon icon="material-symbols:arrow-outward-rounded" :size="18" />
            </button>
          </div>
        </section>

        <section class="workbench-panel workbench-panel--soft">
          <div class="workbench-panel__header">
            <div>
              <p class="workbench-panel__eyebrow">管理范围</p>
              <h3>工作范围</h3>
            </div>
          </div>

          <div class="workbench-notes">
            <article class="workbench-note">
              <span>角色数量</span>
              <strong>{{ roleNames.length || 1 }}</strong>
            </article>
            <article class="workbench-note">
              <span>快捷入口</span>
              <strong>{{ quickActions.length }}</strong>
            </article>
            <article class="workbench-note">
              <span>账号状态</span>
              <strong>{{ userStore.isActive ? '正常' : '停用' }}</strong>
            </article>
            <article class="workbench-note">
              <span>当前空间</span>
              <strong>统一后台</strong>
            </article>
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
    desc: '账号、停用与密码重置',
    icon: 'material-symbols:group-outline-rounded',
  },
  {
    to: '/system/task',
    label: '视频任务',
    desc: '查看任务状态与失败原因',
    icon: 'material-symbols:movie-outline-rounded',
  },
  {
    to: '/system/voice-log',
    label: '语音日志',
    desc: '识别结果与异常记录',
    icon: 'material-symbols:graphic-eq-rounded',
  },
  {
    to: '/system/app-release',
    label: '版本发布',
    desc: '统一管理版本与下载地址',
    icon: 'material-symbols:system-update-alt-rounded',
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
    hint: '当前账号权限',
  },
  {
    label: '快捷入口',
    value: quickActions.length,
    hint: '常用后台页面',
  },
  {
    label: '账号状态',
    value: userStore.isActive ? '正常' : '停用',
    hint: '当前登录状态',
  },
  {
    label: '工作空间',
    value: '统一后台',
    hint: '业务与管理联动',
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
  grid-template-columns: minmax(0, 1.24fr) 320px;
  gap: 22px;
  padding: 24px;
  border: 1px solid rgba(255, 255, 255, 0.24);
  border-radius: 20px;
  background:
    radial-gradient(circle at top right, rgba(255, 210, 150, 0.18), transparent 26%),
    linear-gradient(135deg, #ff6a00 0%, #ff8421 54%, #ffad48 100%);
  color: #ffffff;
  box-shadow: 0 14px 34px rgba(255, 112, 25, 0.14);
}

.workbench-hero__main {
  display: grid;
  gap: 20px;
}

.workbench-hero__brand {
  display: flex;
  align-items: center;
  gap: 18px;
}

.workbench-hero__avatar {
  border: 3px solid rgba(255, 255, 255, 0.22);
  background: rgba(255, 255, 255, 0.14);
}

.workbench-hero__eyebrow,
.workbench-panel__eyebrow {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.18em;
  text-transform: uppercase;
}

.workbench-hero__brand h1 {
  margin: 0;
  font-size: 34px;
  line-height: 1.08;
}

.workbench-hero__summary {
  max-width: 640px;
  margin: 0;
  font-size: 16px;
  line-height: 1.72;
  color: rgba(255, 255, 255, 0.9);
}

.workbench-hero__status {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.workbench-hero__stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
}

.workbench-hero__stat {
  padding: 14px 16px;
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.1);
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.12);
  backdrop-filter: blur(14px);
}

.workbench-hero__stat span,
.workbench-aside__head span,
.workbench-aside__note span {
  display: block;
  font-size: 12px;
  color: rgba(255, 255, 255, 0.76);
}

.workbench-hero__stat strong {
  display: block;
  margin-top: 8px;
  font-size: 26px;
  line-height: 1;
}

.workbench-hero__stat small {
  display: block;
  margin-top: 8px;
  color: rgba(255, 255, 255, 0.76);
}

.workbench-hero__aside {
  display: grid;
  align-content: start;
  gap: 16px;
  padding: 18px;
  border-radius: 16px;
  background: rgba(79, 28, 4, 0.12);
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(14px);
}

.workbench-aside__head strong {
  display: block;
  margin-top: 8px;
  font-size: 24px;
  line-height: 1.06;
}

.workbench-aside__notes {
  display: grid;
  gap: 12px;
}

.workbench-aside__note {
  display: grid;
  gap: 6px;
  padding: 12px 14px;
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.08);
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.1);
}

.workbench-aside__note strong {
  color: #ffffff;
}

.workbench-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.18fr) 360px;
  gap: 22px;
}

.workbench-panel {
  display: grid;
  gap: 18px;
  min-width: 0;
  padding: 20px;
  border: 1px solid var(--shell-border);
  border-radius: 18px;
  background: rgba(255, 251, 248, 0.72);
  box-shadow: var(--soft-shadow);
  backdrop-filter: blur(20px);
}

.workbench-panel--soft {
  background: rgba(255, 247, 242, 0.66);
}

.workbench-panel__header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 14px;
  padding-bottom: 16px;
  border-bottom: 1px solid var(--page-line);
}

.workbench-panel__header h3 {
  margin: 0;
  color: var(--app-text);
}

.workbench-panel__hint {
  font-size: 12px;
  color: var(--app-muted);
}

.workbench-shortcuts {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
}

.workbench-shortcut {
  display: grid;
  grid-template-columns: 54px minmax(0, 1fr) 20px;
  align-items: center;
  gap: 14px;
  padding: 16px;
  border: 1px solid rgba(255, 105, 0, 0.08);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.58);
  color: inherit;
  text-align: left;
  box-shadow: none;
  transition: transform 0.2s ease, box-shadow 0.2s ease, border-color 0.2s ease;
  cursor: pointer;
  backdrop-filter: blur(12px);
}

.workbench-shortcut:hover {
  transform: translateY(-1px);
  border-color: rgba(255, 105, 0, 0.18);
}

.workbench-shortcut__icon {
  display: grid;
  width: 46px;
  height: 46px;
  place-items: center;
  border-radius: 14px;
  background: rgba(255, 105, 0, 0.1);
  color: var(--brand-primary);
}

.workbench-shortcut__copy strong,
.workbench-note strong {
  display: block;
  color: var(--app-text);
}

.workbench-shortcut__copy span,
.workbench-note span {
  display: block;
  margin-top: 6px;
  font-size: 13px;
  line-height: 1.55;
  color: var(--app-muted);
}

.workbench-notes {
  display: grid;
  gap: 12px;
}

.workbench-note {
  padding: 14px 16px;
  border: 1px solid rgba(255, 105, 0, 0.08);
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.48);
}

@media (max-width: 1180px) {
  .workbench-hero,
  .workbench-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 820px) {
  .workbench-hero__stats,
  .workbench-shortcuts {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 720px) {
  .workbench-hero,
  .workbench-panel {
    padding: 18px;
    border-radius: 16px;
  }

  .workbench-hero__brand {
    align-items: flex-start;
  }

  .workbench-hero__brand h1 {
    font-size: 30px;
  }
}
</style>
