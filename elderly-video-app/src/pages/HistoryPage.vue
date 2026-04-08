<template>
  <div class="workspace">
    <article class="surface-card">
      <div class="section-head">
        <div>
          <p class="eyebrow">任务概览</p>
          <h3>历史记录</h3>
          <p>任务状态、扣分结果、重试与下载逻辑全部来自统一后端接口。</p>
        </div>
        <div class="button-row">
          <button class="secondary-btn" type="button" :disabled="loading" @click="loadHistory(true)">
            {{ loading ? '刷新中...' : '刷新' }}
          </button>
          <button class="ghost-btn" type="button" @click="handleClearAll">清空记录</button>
        </div>
      </div>

      <div class="summary-row">
        <div class="summary-chip">
          <strong>{{ summary.total || 0 }}</strong>
          <span>全部</span>
        </div>
        <div class="summary-chip summary-chip--success">
          <strong>{{ summary.completed || 0 }}</strong>
          <span>已完成</span>
        </div>
        <div class="summary-chip summary-chip--warn">
          <strong>{{ summary.processing || 0 }}</strong>
          <span>处理中</span>
        </div>
        <div class="summary-chip summary-chip--danger">
          <strong>{{ summary.failed || 0 }}</strong>
          <span>失败</span>
        </div>
      </div>

      <div class="chip-row chip-row--filter">
        <button
          v-for="item in filters"
          :key="item.value"
          class="chip chip--button"
          :class="{ 'is-active': filter === item.value }"
          type="button"
          @click="changeFilter(item.value)"
        >
          {{ item.label }}
        </button>
      </div>

      <div v-if="loading && !tasks.length" class="empty-placeholder">正在加载任务记录...</div>
      <div v-else-if="!tasks.length" class="empty-placeholder">还没有任务记录，先去创作一条视频吧。</div>
      <div v-else class="task-list">
        <TaskCard
          v-for="task in tasks"
          :key="task.id"
          :task="task"
          @play="handlePlay"
          @download="handleDownload"
          @retry="handleRetry"
          @remove="handleDelete"
        />
      </div>

      <div v-if="pagination.total > pagination.pageSize" class="pagination-row">
        <button class="ghost-btn" type="button" :disabled="pagination.page <= 1" @click="loadHistory(false, pagination.page - 1)">
          上一页
        </button>
        <span>第 {{ pagination.page }} / {{ totalPages }} 页</span>
        <button
          class="ghost-btn"
          type="button"
          :disabled="pagination.page >= totalPages"
          @click="loadHistory(false, pagination.page + 1)"
        >
          下一页
        </button>
      </div>
    </article>

    <VideoPreviewSheet
      v-model="preview.visible"
      :url="preview.url"
      @download="handleDownload(preview.task)"
    />
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue'

import * as api from '@/api'
import TaskCard from '@/components/TaskCard.vue'
import VideoPreviewSheet from '@/components/VideoPreviewSheet.vue'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { APP_TAB_RESELECT_EVENT } from '@/utils/events'
import { isWeChatBrowser } from '@/utils/browser'

const authStore = useAuthStore()
const toastStore = useToastStore()

const filters = [
  { label: '全部', value: 'all' },
  { label: '已完成', value: 'completed' },
  { label: '处理中', value: 'processing' },
  { label: '失败', value: 'failed' },
]

const filter = ref('all')
const loading = ref(false)
const tasks = ref([])
const summary = ref({
  total: 0,
  completed: 0,
  processing: 0,
  failed: 0,
})
const pagination = reactive({
  page: 1,
  pageSize: 10,
  total: 0,
})
const preview = reactive({
  visible: false,
  url: '',
  task: null,
})

const totalPages = computed(() =>
  Math.max(1, Math.ceil((pagination.total || 0) / pagination.pageSize))
)

async function loadSummary() {
  summary.value = await api.getTaskSummary()
}

async function loadHistory(reset = false, page = 1) {
  loading.value = true
  try {
    const [list, taskSummary] = await Promise.all([
      api.listTasks({
        page,
        limit: pagination.pageSize,
        filter: filter.value,
      }),
      api.getTaskSummary(),
    ])
    tasks.value = Array.isArray(list?.items) ? list.items : []
    summary.value = taskSummary
    pagination.page = Number(list?.page || page)
    pagination.total = Number(list?.total || 0)
    if (reset) {
      await authStore.fetchCurrentUser()
    }
  } catch (error) {
    toastStore.push(error.message || '加载历史记录失败', 'danger')
  } finally {
    loading.value = false
  }
}

function changeFilter(nextFilter) {
  if (filter.value === nextFilter) {
    return
  }
  filter.value = nextFilter
  loadHistory(true, 1)
}

function handlePlay(task) {
  preview.url = task.video_url || task.videoUrl || ''
  preview.task = task
  preview.visible = true
}

async function handleDownload(task) {
  if (!task?.id) {
    return
  }
  if (isWeChatBrowser()) {
    toastStore.push('微信内不支持直接下载，请在系统浏览器中打开', 'warn', 3200)
    return
  }

  try {
    const response = await api.downloadTaskVideo(task.id)
    const contentDisposition = response.headers['content-disposition'] || ''
    const matched = contentDisposition.match(/filename=\"?([^"]+)\"?/)
    const fileName = matched?.[1] || `拾光视频-${task.id}.mp4`
    const url = window.URL.createObjectURL(response.data)
    const link = document.createElement('a')
    link.href = url
    link.download = decodeURIComponent(fileName)
    document.body.appendChild(link)
    link.click()
    link.remove()
    window.URL.revokeObjectURL(url)
    toastStore.push('视频开始下载', 'success')
  } catch (error) {
    toastStore.push(error.message || '下载失败', 'danger')
  }
}

async function handleRetry(task) {
  try {
    await api.retryTask(task.id)
    toastStore.push('任务已重新提交', 'success')
    await Promise.all([loadHistory(true, pagination.page), authStore.fetchCurrentUser()])
  } catch (error) {
    if (String(error.message || '').includes('积分不足')) {
      toastStore.push('积分不足，请先到 App 内充值后再生成视频', 'warn', 3200)
      return
    }
    toastStore.push(error.message || '重新生成失败', 'danger')
  }
}

async function handleDelete(task) {
  if (!window.confirm('确定删除这条任务记录吗？')) {
    return
  }

  try {
    await api.deleteTask(task.id)
    toastStore.push('任务记录已删除', 'success')
    await loadHistory(true, pagination.page)
  } catch (error) {
    toastStore.push(error.message || '删除失败', 'danger')
  }
}

async function handleClearAll() {
  if (!tasks.value.length) {
    return
  }
  if (!window.confirm('确定清空当前账号的历史记录吗？')) {
    return
  }
  try {
    await api.clearTasks()
    toastStore.push('历史记录已清空', 'success')
    await loadHistory(true, 1)
  } catch (error) {
    toastStore.push(error.message || '清空失败', 'danger')
  }
}

function handleTabReselect(event) {
  if (event.detail?.tab === 'history') {
    loadHistory(true, 1)
  }
}

onMounted(async () => {
  await loadHistory(true, 1)
  window.addEventListener(APP_TAB_RESELECT_EVENT, handleTabReselect)
})

onBeforeUnmount(() => {
  window.removeEventListener(APP_TAB_RESELECT_EVENT, handleTabReselect)
})
</script>
