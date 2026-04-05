<template>
  <nav class="bottom-nav">
    <button
      v-for="item in items"
      :key="item.name"
      class="bottom-nav__item"
      :class="{ 'is-active': activeName === item.name }"
      type="button"
      @click="$emit('select', item)"
    >
      <span class="bottom-nav__label">{{ item.label }}</span>
    </button>
  </nav>
</template>

<script setup>
defineProps({
  items: {
    type: Array,
    required: true,
  },
  activeName: {
    type: String,
    required: true,
  },
})

defineEmits(['select'])
</script>
