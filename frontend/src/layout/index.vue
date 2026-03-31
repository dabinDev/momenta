<template>
  <n-layout class="app-shell" has-sider wh-full>
    <n-layout-sider
      class="app-shell__sider"
      collapse-mode="width"
      :collapsed-width="72"
      :width="236"
      :native-scrollbar="false"
      :collapsed="appStore.collapsed"
    >
      <SideBar />
    </n-layout-sider>

    <article class="app-shell__main" flex-col flex-1 overflow-hidden>
      <header class="app-shell__header" :style="`height: ${header.height}px`">
        <AppHeader />
      </header>
      <section v-if="tags.visible" class="app-shell__tags" hidden sm:block>
        <AppTags :style="{ height: `${tags.height}px` }" />
      </section>
      <section class="app-shell__content" flex-1 overflow-hidden>
        <AppMain />
      </section>
    </article>
  </n-layout>
</template>

<script setup>
import AppHeader from './components/header/index.vue'
import SideBar from './components/sidebar/index.vue'
import AppMain from './components/AppMain.vue'
import AppTags from './components/tags/index.vue'
import { useAppStore } from '@/store'
import { header, tags } from '~/settings'

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
  background:
    radial-gradient(circle at top right, rgba(190, 214, 255, 0.18), transparent 28%),
    linear-gradient(180deg, #f7faf8 0%, #f3f6fb 100%);
}

.app-shell__sider {
  border-right: 1px solid rgba(58, 84, 71, 0.08);
  background: linear-gradient(180deg, #fbfdfc 0%, #f5f9f7 100%);
  box-shadow: 12px 0 32px rgba(43, 67, 56, 0.04);
}

.app-shell__main {
  min-width: 0;
}

.app-shell__header {
  display: flex;
  align-items: center;
  padding: 0 18px;
  border-bottom: 1px solid rgba(58, 84, 71, 0.08);
  background: rgba(255, 255, 255, 0.82);
  backdrop-filter: blur(16px);
}

.app-shell__tags {
  border-bottom: 1px solid rgba(58, 84, 71, 0.07);
  background: rgba(255, 255, 255, 0.72);
}

.app-shell__content {
  background:
    radial-gradient(circle at top right, rgba(255, 214, 146, 0.14), transparent 24%),
    linear-gradient(180deg, #f7faf8 0%, #f3f6fb 100%);
}

:deep(.n-layout-sider-scroll-container) {
  display: flex;
  flex-direction: column;
}
</style>
