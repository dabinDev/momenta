<script setup>
import SideLogo from './components/SideLogo.vue'
import SideMenu from './components/SideMenu.vue'
</script>

<template>
  <div class="app-sidebar">
    <SideLogo />
    <div class="app-sidebar__menu">
      <SideMenu />
    </div>
  </div>
</template>

<style scoped>
.app-sidebar {
  display: flex;
  min-height: 100%;
  flex-direction: column;
  padding: 12px 0 16px;
}

.app-sidebar__menu {
  min-height: 0;
  flex: 1;
}
</style>
