<template>
  <button class="header-icon-button" type="button" @click="appStore.switchCollapsed">
    <icon-mdi:format-indent-increase v-if="appStore.collapsed" />
    <icon-mdi:format-indent-decrease v-else />
  </button>
</template>

<script setup>
import { useAppStore } from '@/store'

const appStore = useAppStore()
</script>

<style scoped>
.header-icon-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 42px;
  height: 42px;
  border: 0;
  border-radius: 16px;
  background: var(--surface-card-strong);
  color: var(--app-text);
  box-shadow: inset 0 0 0 1px var(--shell-border), var(--soft-shadow);
  cursor: pointer;
  transition: transform 0.2s ease, background-color 0.2s ease, color 0.2s ease;
}

.header-icon-button:hover {
  transform: translateY(-1px);
  background: var(--surface-overlay);
  color: var(--primary-color);
}

.header-icon-button :deep(svg) {
  font-size: 20px;
}
</style>
