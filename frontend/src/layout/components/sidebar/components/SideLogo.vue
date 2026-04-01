<template>
  <router-link class="side-logo" to="/">
    <div class="side-logo__mark">
      <icon-custom-logo text-30 color-primary />
    </div>
    <div v-show="!appStore.collapsed" class="side-logo__copy">
      <p class="side-logo__eyebrow">Momenta</p>
      <h2>{{ title }}</h2>
      <span>Admin Center</span>
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
  margin: 10px;
  padding: 14px 16px;
  border: 1px solid rgba(255, 105, 0, 0.08);
  border-radius: 18px;
  background: rgba(255, 250, 247, 0.7);
  box-shadow: var(--soft-shadow);
  backdrop-filter: blur(18px);
}

.side-logo__mark {
  display: grid;
  width: 46px;
  height: 46px;
  place-items: center;
  border-radius: 14px;
  background: var(--sidebar-mark-bg);
  box-shadow: inset 0 0 0 1px var(--sidebar-mark-ring);
}

.side-logo__copy {
  min-width: 0;
}

.side-logo__eyebrow {
  margin: 0 0 4px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--brand-primary);
}

.side-logo__copy h2 {
  margin: 0;
  overflow: hidden;
  font-size: 18px;
  font-weight: 800;
  color: var(--app-text);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.side-logo__copy span {
  display: block;
  margin-top: 4px;
  font-size: 12px;
  color: var(--app-muted);
}
</style>
