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
  position: relative;
  height: 100%;
  padding: 14px 16px 20px;
}

.app-page::before {
  position: absolute;
  top: 0;
  left: 8%;
  right: 8%;
  height: 110px;
  border-radius: 999px;
  background: radial-gradient(circle, rgba(255, 162, 77, 0.08) 0%, transparent 72%);
  pointer-events: none;
  content: '';
}

.app-page::after {
  position: absolute;
  inset: 0;
  background: linear-gradient(180deg, rgba(255, 255, 255, 0.04), transparent 14%);
  pointer-events: none;
  content: '';
}

.app-page__body {
  position: relative;
  display: flex;
  min-height: 100%;
  flex-direction: column;
  gap: 22px;
}

.app-page__footer {
  margin-top: auto;
}

@media (max-width: 768px) {
  .app-page {
    padding: 12px;
  }

  .app-page__body {
    gap: 18px;
  }
}
</style>
