<template>
  <AppPage :show-footer="showFooter">
    <header v-if="showHeader" class="common-page__header">
      <slot v-if="$slots.header" name="header" />
      <template v-else>
        <div class="common-page__title-block">
          <p class="common-page__eyebrow">Momenta</p>
          <h2>{{ title || route.meta?.title }}</h2>
        </div>
        <slot name="action" />
      </template>
    </header>

    <main class="common-page__content">
      <slot />
    </main>
  </AppPage>
</template>

<script setup>
defineProps({
  showFooter: {
    type: Boolean,
    default: false,
  },
  showHeader: {
    type: Boolean,
    default: true,
  },
  title: {
    type: String,
    default: undefined,
  },
})

const route = useRoute()
</script>

<style scoped>
.common-page__header {
  position: relative;
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 18px;
  padding: 18px 20px;
  overflow: hidden;
  border: 1px solid var(--shell-border);
  border-radius: 18px;
  background: rgba(255, 251, 248, 0.68);
  box-shadow: var(--soft-shadow);
  backdrop-filter: blur(20px);
}

.common-page__header::before {
  display: none;
}

.common-page__title-block {
  position: relative;
  min-width: 0;
  z-index: 1;
}

.common-page__eyebrow {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--brand-primary);
}

.common-page__title-block h2 {
  margin: 0;
  font-size: 28px;
  line-height: 1.06;
  color: var(--app-text);
}

.common-page__content {
  display: flex;
  min-height: 0;
  flex: 1;
  flex-direction: column;
  gap: 24px;
}

@media (max-width: 768px) {
  .common-page__header {
    flex-direction: column;
    align-items: flex-start;
    padding: 16px;
  }

  .common-page__content {
    gap: 18px;
  }

  .common-page__title-block h2 {
    font-size: 24px;
  }
}
</style>
