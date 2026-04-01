<template>
  <transition name="fade-slide" mode="out-in" appear>
    <section class="app-page cus-scroll-y">
      <div class="app-page__body">
        <slot />
        <AppFooter v-if="showFooter" class="app-page__footer" />
      </div>
      <n-back-top :bottom="28" />
    </section>
  </transition>
</template>

<script setup>
defineProps({
  showFooter: {
    type: Boolean,
    default: false,
  },
})
</script>

<style scoped>
.app-page {
  height: 100%;
  padding: 20px;
}

.app-page__body {
  display: flex;
  min-height: 100%;
  flex-direction: column;
  gap: 20px;
}

.app-page__footer {
  margin-top: auto;
}

@media (max-width: 768px) {
  .app-page {
    padding: 16px;
  }

  .app-page__body {
    gap: 16px;
  }
}
</style>
