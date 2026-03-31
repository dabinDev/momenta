<template>
  <n-dropdown :options="options" @select="handleSelect">
    <div class="user-chip">
      <n-avatar
        :src="userStore.avatar"
        :size="38"
        round
        class="user-chip__avatar"
      >
        {{ (userStore.displayName || userStore.name || 'U').slice(0, 1) }}
      </n-avatar>
      <div class="user-chip__copy">
        <strong>{{ userStore.displayName || userStore.name }}</strong>
        <span>{{ userStore.isSuperUser ? '管理员' : '已登录' }}</span>
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
  align-items: center;
  gap: 10px;
  min-width: 0;
  padding: 6px 8px 6px 6px;
  border-radius: 18px;
  background: linear-gradient(135deg, rgba(255, 250, 239, 0.95), rgba(239, 247, 243, 0.95));
  cursor: pointer;
}

.user-chip__avatar {
  flex-shrink: 0;
  border: 2px solid rgba(255, 255, 255, 0.88);
}

.user-chip__copy {
  display: grid;
  min-width: 0;
}

.user-chip__copy strong {
  font-size: 14px;
  font-weight: 700;
  color: #2f3a32;
  white-space: nowrap;
}

.user-chip__copy span {
  font-size: 12px;
  color: #7a847c;
}

@media (max-width: 720px) {
  .user-chip__copy {
    display: none;
  }

  .user-chip {
    padding-right: 6px;
  }
}
</style>
