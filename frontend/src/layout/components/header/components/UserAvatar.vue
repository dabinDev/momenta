<template>
  <n-dropdown :options="options" @select="handleSelect">
    <div class="user-chip">
      <n-avatar :src="userStore.avatar" :size="40" round class="user-chip__avatar">
        {{ (userStore.displayName || userStore.name || 'U').slice(0, 1) }}
      </n-avatar>
      <div class="user-chip__copy">
        <strong>{{ userStore.displayName || userStore.name }}</strong>
        <span>{{ userStore.isSuperUser ? '管理员' : '已登录账号' }}</span>
      </div>
    </div>
  </n-dropdown>
</template>

<script setup>
import { useUserStore } from '@/store'
import { renderIcon } from '@/utils'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'

const { t } = useI18n()

const router = useRouter()
const userStore = useUserStore()

const options = [
  {
    label: t('header.label_profile'),
    key: 'profile',
    icon: renderIcon('mdi-account-arrow-right-outline', { size: '14px' }),
  },
  {
    label: t('header.label_logout'),
    key: 'logout',
    icon: renderIcon('mdi:exit-to-app', { size: '14px' }),
  },
]

function handleSelect(key) {
  if (key === 'profile') {
    router.push('/profile')
  } else if (key === 'logout') {
    $dialog.confirm({
      title: t('header.label_logout_dialog_title'),
      type: 'warning',
      content: t('header.text_logout_confirm'),
      confirm() {
        userStore.logout()
        $message.success(t('header.text_logout_success'))
      },
    })
  }
}
</script>

<style scoped>
.user-chip {
  display: flex;
  min-width: 0;
  align-items: center;
  gap: 10px;
  padding: 6px 10px 6px 6px;
  border: 1px solid var(--shell-border);
  border-radius: 20px;
  background: var(--surface-card-strong);
  box-shadow: var(--soft-shadow);
  cursor: pointer;
}

.user-chip__avatar {
  flex-shrink: 0;
  border: 2px solid rgba(255, 255, 255, 0.42);
}

.user-chip__copy {
  display: grid;
  min-width: 0;
}

.user-chip__copy strong {
  overflow: hidden;
  font-size: 14px;
  font-weight: 700;
  color: var(--app-text);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.user-chip__copy span {
  font-size: 12px;
  color: var(--app-muted);
}

@media (max-width: 720px) {
  .user-chip {
    padding-right: 6px;
  }

  .user-chip__copy {
    display: none;
  }
}
</style>
