<template>
  <div class="app-header">
    <div class="app-header__start">
      <div class="app-header__menu">
        <MenuCollapse />
      </div>
      <div class="app-header__crumbs">
        <p class="app-header__eyebrow">{{ route.meta?.title || 'Workspace' }}</p>
        <BreadCrumb class="app-header__breadcrumb" />
      </div>
    </div>

    <div class="app-header__end">
      <div class="app-header__tools">
        <Languages />
        <ThemeMode />
        <GithubSite />
        <FullScreen />
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
import GithubSite from './components/GithubSite.vue'
import ThemeMode from './components/ThemeMode.vue'
import Languages from './components/Languages.vue'

const route = useRoute()
</script>

<style scoped>
.app-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  width: 100%;
}

.app-header__start,
.app-header__end {
  display: flex;
  align-items: center;
  gap: 14px;
  min-width: 0;
}

.app-header__crumbs {
  min-width: 0;
}

.app-header__eyebrow {
  margin: 0 0 4px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: #7c867d;
}

.app-header__menu {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  border-radius: 12px;
  background: linear-gradient(135deg, rgba(237, 246, 240, 0.95), rgba(255, 248, 235, 0.95));
}

.app-header__tools {
  display: flex;
  align-items: center;
  gap: 2px;
  padding: 4px;
  border-radius: 16px;
  background: rgba(244, 247, 245, 0.92);
}

:deep(.app-header__breadcrumb .n-breadcrumb) {
  font-size: 13px;
}

:deep(.app-header__breadcrumb .n-breadcrumb-item) {
  cursor: pointer;
}

@media (max-width: 720px) {
  .app-header__eyebrow,
  .app-header__breadcrumb {
    display: none;
  }

  .app-header__tools {
    padding: 2px;
  }
}
</style>
