<template>
  <main class="app-shell">
    <div class="app-shell__backdrop">
      <span class="app-shell__orb app-shell__orb--primary"></span>
      <span class="app-shell__orb app-shell__orb--sky"></span>
      <span class="app-shell__orb app-shell__orb--jade"></span>
    </div>

    <div class="app-shell__inner">
      <header class="app-header">
        <div class="app-header__brand">
          <BrandMark :size="54" :radius="18" />
          <div class="app-header__copy">
            <p class="eyebrow">拾光视频</p>
            <h1>{{ currentMeta.title }}</h1>
          </div>
        </div>
        <div class="app-header__meta">
          <p class="app-header__subtitle">{{ currentMeta.subtitle }}</p>
        </div>
      </header>

      <section class="app-panel">
        <RouterView />
      </section>

      <BottomNav :items="navItems" :active-name="activeName" @select="handleSelect" />
    </div>
  </main>
</template>

<script setup>
import { computed, onMounted } from 'vue'
import { RouterView, useRoute, useRouter } from 'vue-router'

import BottomNav from '@/components/BottomNav.vue'
import BrandMark from '@/components/BrandMark.vue'
import { useAuthStore } from '@/stores/auth'
import { emitTabReselect } from '@/utils/events'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const navItems = [
  { name: 'create', label: '创作', to: '/app/create' },
  { name: 'history', label: '记录', to: '/app/history' },
  { name: 'settings', label: '设置', to: '/app/settings' },
]

const pageMeta = {
  create: {
    title: 'AI 创作',
    subtitle: '简单、入门、自定义三种工作流保持和 App 同步',
  },
  history: {
    title: '任务记录',
    subtitle: '查看生成状态、扣分结果、重试与下载操作',
  },
  settings: {
    title: '个人中心',
    subtitle: '个人资料、邀请记录、积分信息与 App 下载入口',
  },
}

const activeName = computed(() => String(route.name || 'create'))
const currentMeta = computed(() => pageMeta[activeName.value] || pageMeta.create)

function handleSelect(item) {
  if (item.name === activeName.value) {
    emitTabReselect(item.name)
    return
  }
  router.push(item.to)
}

onMounted(() => {
  authStore.refreshAppContext()
})
</script>
