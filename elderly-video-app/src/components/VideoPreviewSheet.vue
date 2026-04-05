<template>
  <AppSheet
    :model-value="modelValue"
    title="视频预览"
    subtitle="支持浏览器原生全屏与系统下载"
    eyebrow="成片查看"
    size="lg"
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <div class="video-sheet">
      <video
        v-if="url"
        class="video-sheet__player"
        :src="url"
        controls
        playsinline
        preload="metadata"
      />
      <div v-else class="video-sheet__empty">当前还没有可预览的视频</div>
      <div class="video-sheet__actions">
        <button class="secondary-btn" type="button" @click="$emit('download')">下载视频</button>
        <button class="ghost-btn" type="button" @click="$emit('update:modelValue', false)">关闭</button>
      </div>
    </div>
  </AppSheet>
</template>

<script setup>
import AppSheet from '@/components/AppSheet.vue'

defineProps({
  modelValue: {
    type: Boolean,
    default: false,
  },
  url: {
    type: String,
    default: '',
  },
})

defineEmits(['update:modelValue', 'download'])
</script>
