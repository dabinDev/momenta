<template>
  <n-layout class="app-shell" has-sider wh-full>
    <n-layout-sider
      class="app-shell__sider"
      collapse-mode="width"
      :collapsed-width="76"
      :width="264"
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
  gap: 10px;
  padding: 10px;
  background: transparent;
}

.app-shell__sider {
  position: relative;
  overflow: hidden;
  border: 1px solid var(--shell-border);
  border-radius: 22px;
  background: var(--shell-sidebar-bg);
  box-shadow: var(--panel-shadow);
}

.app-shell__sider::before {
  display: none;
}

.app-shell__sider::after {
  position: absolute;
  top: 16px;
  right: 0;
  bottom: 16px;
  width: 1px;
  background: linear-gradient(180deg, transparent, var(--shell-divider), transparent);
  content: '';
}

.app-shell__main {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 10px;
  padding-left: 2px;
}

.app-shell__header {
  display: flex;
  align-items: center;
  padding: 0;
  background: transparent;
}

.app-shell__content {
  position: relative;
  min-height: 0;
  flex: 1;
  padding: 0;
}

.app-shell__workspace {
  position: relative;
  height: 100%;
  overflow: hidden;
  border-radius: 24px;
  background: var(--shell-workspace-bg);
  box-shadow: var(--panel-shadow);
}

.app-shell__workspace::before {
  position: absolute;
  inset: 0;
  border: 1px solid var(--shell-border);
  border-radius: inherit;
  pointer-events: none;
  content: '';
}

.app-shell__workspace::after {
  position: absolute;
  inset: 0;
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.06), transparent 18%);
  pointer-events: none;
  content: '';
}

:deep(.n-layout-sider-scroll-container) {
  display: flex;
  flex-direction: column;
}

@media (max-width: 768px) {
  .app-shell {
    gap: 8px;
    padding: 8px;
  }

  .app-shell__workspace {
    border-radius: 18px;
  }
}
</style>
