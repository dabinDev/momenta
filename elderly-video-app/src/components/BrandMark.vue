<template>
  <div class="brand-mark" :style="styleObject">
    <img src="/shiguang-icon.png" alt="拾光视频" />
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  size: {
    type: Number,
    default: 64,
  },
  radius: {
    type: Number,
    default: 22,
  },
})

const styleObject = computed(() => ({
  width: `${props.size}px`,
  height: `${props.size}px`,
  borderRadius: `${props.radius}px`,
}))
</script>
