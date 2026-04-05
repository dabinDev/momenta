<template>
  <article class="task-card">
    <div class="task-card__head">
      <div class="task-card__title-wrap">
        <h4>{{ title }}</h4>
        <p class="task-card__time">{{ formatDateTime(task.created_at || task.createdAt) }}</p>
      </div>
      <StatusPill :label="status.label" :tone="status.tone" />
    </div>

    <p v-if="task.error_message || task.errorMessage" class="task-card__error">
      {{ task.error_message || task.errorMessage }}
    </p>
    <p v-else class="task-card__prompt">{{ task.prompt || task.display_text || task.displayText || '暂无提示词' }}</p>

    <div class="task-card__meta">
      <span>{{ formatDuration(task.duration) }}</span>
      <span v-if="pointsLabel">{{ pointsLabel }}</span>
      <span>{{ modeLabel }}</span>
    </div>

    <div class="task-card__actions">
      <button
        v-if="canPlay"
        class="secondary-btn"
        type="button"
        @click="$emit('play', task)"
      >
        播放
      </button>
      <button
        v-if="canDownload"
        class="secondary-btn"
        type="button"
        @click="$emit('download', task)"
      >
        下载
      </button>
      <button
        v-if="canRetry"
        class="secondary-btn"
        type="button"
        @click="$emit('retry', task)"
      >
        重新生成
      </button>
      <button class="ghost-btn" type="button" @click="$emit('remove', task)">
        删除
      </button>
    </div>
  </article>
</template>

<script setup>
import { computed } from 'vue'

import StatusPill from '@/components/StatusPill.vue'
import { formatDateTime, formatDuration, statusMeta } from '@/utils/format'

const props = defineProps({
  task: {
    type: Object,
    required: true,
  },
})

defineEmits(['play', 'download', 'retry', 'remove'])

const title = computed(
  () =>
    props.task.display_text ||
    props.task.displayText ||
    props.task.prompt ||
    '未命名视频任务'
)

const status = computed(() => statusMeta(props.task.status))

const pointsLabel = computed(() => {
  const cost = Number(props.task.points_cost ?? props.task.pointsCost ?? 0)
  const refunded = props.task.points_refunded === true || props.task.pointsRefunded === true
  if (cost <= 0) {
    return ''
  }
  return refunded ? `已退回 ${cost} 积分` : `已扣 ${cost} 积分`
})

const modeLabel = computed(() => {
  switch (props.task.creation_mode || props.task.creationMode) {
    case 'starter':
      return '入门'
    case 'custom':
      return '自定义'
    default:
      return '简单'
  }
})

const canPlay = computed(() => props.task.status === 'completed' && Boolean(props.task.video_url || props.task.videoUrl))
const canDownload = canPlay
const canRetry = computed(() => props.task.status === 'failed')
</script>
