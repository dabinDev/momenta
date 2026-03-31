<template>
  <router-link class="side-logo" to="/">
    <div class="side-logo__mark">
      <icon-custom-logo text-34 color-primary />
    </div>
    <div v-show="!appStore.collapsed" class="side-logo__copy">
      <span>后台工作台</span>
      <h2>{{ title }}</h2>
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
  gap: 12px;
  min-height: 72px;
  padding: 16px 18px 12px;
}

.side-logo__mark {
  display: grid;
  place-items: center;
  width: 42px;
  height: 42px;
  border-radius: 14px;
  background: linear-gradient(135deg, rgba(236, 246, 240, 0.95), rgba(255, 248, 235, 0.95));
}

.side-logo__copy {
  min-width: 0;
}

.side-logo__copy span {
  display: block;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: #7b867e;
}

.side-logo__copy h2 {
  margin: 4px 0 0;
  font-size: 18px;
  font-weight: 700;
  color: var(--primary-color);
  white-space: nowrap;
}
</style>
