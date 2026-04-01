<template>
  <n-layout class="app-shell" has-sider wh-full>
    <n-layout-sider
      class="app-shell__sider"
      collapse-mode="width"
      :collapsed-width="74"
      :width="248"
      :native-scrollbar="false"
      :collapsed="appStore.collapsed"
    >
      <SideBar />
    </n-layout-sider>

    <article class="app-shell__main">
      <header class="app-shell__header" :style="`height: ${header.height}px`">
        <AppHeader />
      </header>

      <section class="app-shell__content">
        <div class="app-shell__workspace">
          <AppMain />
        </div>
      </section>
    </article>
  </n-layout>
</template>

<script setup>
import AppHeader from './components/header/index.vue'
import SideBar from './components/sidebar/index.vue'
import AppMain from './components/AppMain.vue'
import { useAppStore } from '@/store'
import { header } from '~/settings'

import { useBreakpoints } from '@vueuse/core'

const appStore = useAppStore()
const breakpointsEnum = {
  xl: 1600,
  lg: 1199,
  md: 991,
  sm: 666,
  xs: 575,
}
const breakpoints = reactive(useBreakpoints(breakpointsEnum))
const isMobile = breakpoints.smaller('sm')
const isPad = breakpoints.between('sm', 'md')
const isPC = breakpoints.greater('md')

watchEffect(() => {
  if (isMobile.value) {
    appStore.setCollapsed(true)
    appStore.setFullScreen(false)
  }

  if (isPad.value) {
    appStore.setCollapsed(true)
    appStore.setFullScreen(false)
  }

  if (isPC.value) {
    appStore.setCollapsed(false)
    appStore.setFullScreen(true)
  }
})
</script>

<style scoped>
.app-shell {
  background: transparent;
}

.app-shell__sider {
  background: var(--shell-sidebar-bg);
  backdrop-filter: blur(20px);
  border-right: 1px solid var(--shell-border);
  box-shadow: var(--soft-shadow);
}

.app-shell__main {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
}

.app-shell__header {
  display: flex;
  align-items: center;
  padding: 0 24px 0 18px;
  background: var(--shell-header-bg);
}

.app-shell__content {
  min-height: 0;
  flex: 1;
  padding: 0 20px 20px 12px;
}

.app-shell__workspace {
  height: 100%;
  overflow: hidden;
  border: 1px solid var(--shell-border);
  border-radius: 32px;
  background: var(--shell-workspace-bg);
  box-shadow: var(--panel-shadow);
  backdrop-filter: blur(18px);
}

:deep(.n-layout-sider-scroll-container) {
  display: flex;
  flex-direction: column;
}

@media (max-width: 768px) {
  .app-shell__header {
    padding: 0 14px 0 12px;
  }

  .app-shell__content {
    padding: 0 14px 14px;
  }

  .app-shell__workspace {
    border-radius: 24px;
  }
}
</style>
