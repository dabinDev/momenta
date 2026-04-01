<template>
  <div class="app-header">
    <div class="app-header__start">
      <MenuCollapse />
      <div class="app-header__titles">
        <p class="app-header__eyebrow">Momenta Console</p>
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
  position: relative;
  display: flex;
  width: 100%;
  align-items: center;
  justify-content: space-between;
  gap: 18px;
  padding: 12px 16px;
  overflow: hidden;
  border: 1px solid var(--shell-border);
  border-radius: 20px;
  background: rgba(255, 250, 247, 0.72);
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

.app-header__eyebrow {
  margin: 0 0 6px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--brand-primary);
}

.app-header__titles h1 {
  margin: 0;
  font-size: 24px;
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

:deep(.app-header__breadcrumb .n-breadcrumb) {
  margin-top: 5px;
  font-size: 12px;
  color: var(--app-muted);
}

:deep(.app-header__breadcrumb .n-breadcrumb-item) {
  cursor: pointer;
}

@media (max-width: 720px) {
  .app-header {
    padding: 10px 12px;
    border-radius: 16px;
  }

  .app-header__eyebrow {
    display: none;
  }

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
