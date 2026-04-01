<script setup>
import { useAppStore } from '@/store'

const appStore = useAppStore()

const toggleDark = () => {
  appStore.toggleDark()
}
</script>

<template>
  <button class="header-tool-button" type="button" @click="toggleDark">
    <icon-mdi-moon-waning-crescent v-if="appStore.isDark" />
    <icon-mdi-white-balance-sunny v-else />
  </button>
</template>

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
