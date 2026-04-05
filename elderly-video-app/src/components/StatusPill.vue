<template>
  <span class="status-pill" :data-tone="tone">
    {{ label }}
  </span>
</template>

<script setup>
defineProps({
  label: {
    type: String,
    required: true,
  },
  tone: {
    type: String,
    default: 'muted',
  },
})
</script>
