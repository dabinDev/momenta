<template>
  <div class="app-header">
    <div class="app-header__start">
      <MenuCollapse />
      <div class="app-header__titles">
        <h1>{{ route.meta?.title || '工作台' }}</h1>
      </div>
    </div>

    <div class="app-header__end">
      <div class="app-header__actions">
        <FullScreen />
        <ThemeMode />
      </div>
      <UserAvatar />
    </div>
  </div>
</template>

<script setup>
import MenuCollapse from './components/MenuCollapse.vue'
import FullScreen from './components/FullScreen.vue'
import UserAvatar from './components/UserAvatar.vue'
import ThemeMode from './components/ThemeMode.vue'

const route = useRoute()
</script>

<style scoped>
.app-header {
  position: relative;
  display: flex;
  width: 100%;
  align-items: center;
  justify-content: space-between;
  gap: 18px;
  padding: 10px 14px;
  overflow: hidden;
  border: 1px solid var(--shell-border);
  border-radius: 20px;
  background:
    linear-gradient(135deg, rgba(255, 250, 247, 0.82), rgba(247, 249, 255, 0.76)),
    rgba(255, 250, 247, 0.72);
  box-shadow: var(--soft-shadow);
  backdrop-filter: blur(22px);
}

.app-header::after {
  position: absolute;
  inset: 0;
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.12), transparent 44%);
  pointer-events: none;
  content: '';
}

.app-header__start,
.app-header__end {
  display: flex;
  min-width: 0;
  align-items: center;
  gap: 14px;
}

.app-header__titles {
  position: relative;
  min-width: 0;
  z-index: 1;
}

.app-header__titles h1 {
  margin: 0;
  font-size: 22px;
  font-weight: 800;
  line-height: 1.08;
  color: var(--app-text);
}

.app-header__actions {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 4px;
  border: 1px solid var(--shell-border);
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.36);
}

@media (max-width: 720px) {
  .app-header {
    padding: 10px 12px;
    border-radius: 16px;
  }

  .app-header__titles h1 {
    font-size: 18px;
  }

  .app-header__actions {
    padding: 4px;
    gap: 6px;
  }
}
</style>
