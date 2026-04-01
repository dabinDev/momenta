<template>
  <button v-if="appStore.fullScreen" class="header-tool-button" type="button" @click="toggle">
    <icon-ant-design:fullscreen-exit-outlined v-if="isFullscreen" />
    <icon-ant-design:fullscreen-outlined v-else />
  </button>
</template>

<script setup>
import { useFullscreen } from '@vueuse/core'
import { useAppStore } from '@/store'

const appStore = useAppStore()
const { isFullscreen, toggle } = useFullscreen()
</script>

<style scoped>
.header-tool-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 38px;
  height: 38px;
  border: 0;
  border-radius: 14px;
  background: transparent;
  color: var(--app-muted);
  cursor: pointer;
  transition: background-color 0.2s ease, color 0.2s ease, transform 0.2s ease;
}

.header-tool-button:hover {
  transform: translateY(-1px);
  background: var(--menu-hover-bg);
  color: var(--primary-color);
}

.header-tool-button :deep(svg) {
  font-size: 18px;
}
</style>
