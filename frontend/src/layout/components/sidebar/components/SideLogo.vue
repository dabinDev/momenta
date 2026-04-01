<template>
  <router-link class="side-logo" to="/">
    <div class="side-logo__mark">
      <icon-custom-logo text-30 color-primary />
    </div>
    <div v-show="!appStore.collapsed" class="side-logo__copy">
      <h2>{{ title }}</h2>
      <p>管理后台</p>
    </div>
  </router-link>
</template>

<script setup>
import { useAppStore } from '@/store'

const title = import.meta.env.VITE_TITLE
const appStore = useAppStore()
</script>

<style scoped>
.side-logo {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 10px 18px 18px;
}

.side-logo__mark {
  display: grid;
  width: 46px;
  height: 46px;
  place-items: center;
  border-radius: 18px;
  background: var(--sidebar-mark-bg);
  box-shadow: inset 0 0 0 1px var(--sidebar-mark-ring), var(--soft-shadow);
}

.side-logo__copy {
  min-width: 0;
}

.side-logo__copy h2 {
  margin: 0;
  overflow: hidden;
  font-size: 18px;
  font-weight: 700;
  color: var(--app-text);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.side-logo__copy p {
  margin: 4px 0 0;
  font-size: 12px;
  color: var(--app-muted);
}
</style>
