<template>
  <div class="app-header">
    <div class="app-header__start">
      <MenuCollapse />
      <div class="app-header__titles">
        <h1>{{ route.meta?.title || '工作台' }}</h1>
        <BreadCrumb class="app-header__breadcrumb" />
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
import BreadCrumb from './components/BreadCrumb.vue'
import MenuCollapse from './components/MenuCollapse.vue'
import FullScreen from './components/FullScreen.vue'
import UserAvatar from './components/UserAvatar.vue'
import ThemeMode from './components/ThemeMode.vue'

const route = useRoute()
</script>

<style scoped>
.app-header {
  display: flex;
  width: 100%;
  align-items: center;
  justify-content: space-between;
  gap: 18px;
}

.app-header__start,
.app-header__end {
  display: flex;
  min-width: 0;
  align-items: center;
  gap: 14px;
}

.app-header__titles {
  min-width: 0;
}

.app-header__titles h1 {
  margin: 0;
  font-size: 22px;
  font-weight: 700;
  color: var(--app-text);
  line-height: 1.15;
}

.app-header__actions {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px;
  border: 1px solid var(--shell-border);
  border-radius: 18px;
  background: var(--surface-overlay);
}

:deep(.app-header__breadcrumb .n-breadcrumb) {
  margin-top: 4px;
  font-size: 12px;
  color: var(--app-muted);
}

:deep(.app-header__breadcrumb .n-breadcrumb-item) {
  cursor: pointer;
}

@media (max-width: 720px) {
  .app-header__titles h1 {
    font-size: 18px;
  }

  .app-header__breadcrumb {
    display: none;
  }

  .app-header__actions {
    padding: 4px;
    gap: 6px;
  }
}
</style>
