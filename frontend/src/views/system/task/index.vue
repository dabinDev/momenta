<script setup>
import { computed, h, onMounted, ref } from 'vue'
import {
  NButton,
  NDataTable,
  NDrawer,
  NDrawerContent,
  NEmpty,
  NImage,
  NInput,
  NPagination,
  NSelect,
  NTag,
} from 'naive-ui'

import CommonPage from '@/components/page/CommonPage.vue'
import { formatDate, getToken } from '@/utils'
import api from '@/api'

const loading = ref(false)
const rows = ref([])
const syncingId = ref(null)
const detailVisible = ref(false)
const activeTask = ref(null)
const queryForm = ref({
  username: '',
  status: '',
  taskType: '',
})
const pagination = ref({
  page: 1,
  pageSize: 10,
  itemCount: 0,
})

const statusOptions = [
  { label: '全部状态', value: '' },
  { label: '处理中', value: 'processing' },
  { label: '已完成', value: 'completed' },
  { label: '失败', value: 'failed' },
  { label: '已取消', value: 'cancelled' },
]

const taskTypeOptions = [
  { label: '全部类型', value: '' },
  { label: '文生视频', value: 'text_to_video' },
  { label: '图生视频', value: 'image_to_video' },
]

const summaryItems = computed(() => [
  {
    label: '任务总数',
    value: pagination.value.itemCount,
    hint: '统一历史中心',
  },
  {
    label: '处理中',
    value: rows.value.filter((item) => ['queued', 'processing'].includes(item.status)).length,
    hint: '本页实时状态',
  },
  {
    label: '已完成',
    value: rows.value.filter((item) => item.status === 'completed').length,
    hint: '可回放下载',
  },
  {
    label: '失败',
    value: rows.value.filter((item) => item.status === 'failed').length,
    hint: '需要排查重试',
  },
])

const activeTaskMeta = computed(() => {
  if (!activeTask.value) return []
  return [
    {
      label: '任务来源',
      value: activeTask.value.task_source || 'app',
    },
    {
      label: '上游服务',
      value: activeTask.value.provider || 'legacy',
    },
    {
      label: '任务类型',
      value: resolveTaskTypeLabel(activeTask.value.task_type),
    },
    {
      label: '视频时长',
      value: `${activeTask.value.duration || 0}s`,
    },
    {
      label: '上游任务 ID',
      value: readText(activeTask.value.provider_task_id),
    },
    {
      label: '当前进度',
      value: resolveProgressLabel(activeTask.value.progress),
    },
  ]
})

const activeTaskAssets = computed(() => activeTask.value?.assets || [])

const columns = [
  {
    title: '用户',
    key: 'user',
    width: 170,
    render(row) {
      const user = row.user || {}
      return h('div', { class: 'task-user' }, [
        h('strong', {}, user.alias || user.username || '--'),
        h('span', {}, user.username ? `@${user.username}` : '未绑定'),
      ])
    },
  },
  {
    title: '任务类型',
    key: 'task_type',
    width: 120,
    render(row) {
      return h(
        NTag,
        { round: true, type: row.task_type === 'image_to_video' ? 'warning' : 'info' },
        { default: () => (row.task_type === 'image_to_video' ? '图生视频' : '文生视频') }
      )
    },
  },
  {
    title: '状态',
    key: 'status',
    width: 110,
    render(row) {
      return h(
        NTag,
        { round: true, type: resolveStatusType(row.status) },
        { default: () => resolveStatusLabel(row.status) }
      )
    },
  },
  {
    title: '用户输入',
    key: 'display_text',
    minWidth: 320,
    ellipsis: { tooltip: true },
  },
  {
    title: '进度',
    key: 'progress',
    width: 96,
    render(row) {
      return resolveProgressLabel(row.progress)
    },
  },
  {
    title: '更新时间',
    key: 'updated_at',
    width: 180,
    render(row) {
      return row.updated_at ? formatDate(row.updated_at) : '--'
    },
  },
  {
    title: '操作',
    key: 'actions',
    width: 180,
    fixed: 'right',
    render(row) {
      return h('div', { class: 'task-actions' }, [
        h(
          NButton,
          {
            size: 'small',
            quaternary: true,
            onClick: () => openTaskDetail(row),
          },
          { default: () => '详情' }
        ),
        h(
          NButton,
          {
            size: 'small',
            quaternary: true,
            type: 'primary',
            loading: syncingId.value === row.id,
            onClick: () => handleSync(row.id),
          },
          { default: () => '同步状态' }
        ),
      ])
    },
  },
]

onMounted(() => {
  fetchTasks()
})

async function fetchTasks() {
  loading.value = true
  try {
    const res = await api.getTaskList({
      page: pagination.value.page,
      page_size: pagination.value.pageSize,
      username: queryForm.value.username || undefined,
      status: queryForm.value.status || undefined,
      task_type: queryForm.value.taskType || undefined,
    })
    rows.value = res.data || []
    pagination.value.itemCount = res.total || 0
  } finally {
    loading.value = false
  }
}

async function handleSync(taskId) {
  syncingId.value = taskId
  try {
    await api.syncTask({ task_id: taskId })
    window.$message?.success('任务状态已刷新')
    await fetchTasks()
  } finally {
    syncingId.value = null
  }
}

function openTaskDetail(row) {
  activeTask.value = row
  detailVisible.value = true
}

function handleReset() {
  queryForm.value = {
    username: '',
    status: '',
    taskType: '',
  }
  pagination.value.page = 1
  fetchTasks()
}

function handlePageChange(page) {
  pagination.value.page = page
  fetchTasks()
}

function resolveStatusLabel(status = '') {
  const map = {
    queued: '排队中',
    processing: '处理中',
    completed: '已完成',
    failed: '失败',
    cancelled: '已取消',
  }
  return map[status] || status || '--'
}

function resolveTaskTypeLabel(taskType = '') {
  const map = {
    text_to_video: '文生视频',
    image_to_video: '图生视频',
  }
  return map[taskType] || taskType || '--'
}

function resolveProgressLabel(progress) {
  const value = Number(progress || 0)
  if (!Number.isFinite(value) || value <= 0) return '0%'
  const normalized = value > 1 ? value : value * 100
  return `${Math.round(Math.min(normalized, 100))}%`
}

function resolveStatusType(status = '') {
  const map = {
    queued: 'default',
    processing: 'warning',
    completed: 'success',
    failed: 'error',
    cancelled: 'default',
  }
  return map[status] || 'default'
}

function readText(value) {
  const text = `${value ?? ''}`.trim()
  return text || '未提供'
}
function buildTaskDownloadUrl(taskId) {
  const baseUrl = `${import.meta.env.VITE_BASE_API || ''}`.replace(/\/$/, '')
  return `${baseUrl}/task/download?${new URLSearchParams({ task_id: String(taskId) }).toString()}`
}

function openTaskVideo(task) {
  if (!task?.video_url) {
    window.$message?.error('当前任务还没有可预览的视频')
    return
  }
  window.open(task.video_url, '_blank', 'noopener,noreferrer')
}

async function downloadTaskVideo(task) {
  if (!task?.id || !task?.video_url) {
    window.$message?.error('当前任务还没有可保存的视频')
    return
  }

  const token = getToken()
  const response = await fetch(buildTaskDownloadUrl(task.id), {
    headers: token ? { token } : {},
  })

  if (!response.ok) {
    let message = '保存视频失败'
    try {
      const payload = JSON.parse(await response.text())
      message = payload?.detail || payload?.msg || payload?.message || message
    } catch (_) {
      // Keep fallback message.
    }
    throw new Error(message)
  }

  const blob = await response.blob()
  const objectUrl = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = objectUrl
  link.download = `task_${task.id}.mp4`
  link.click()
  setTimeout(() => URL.revokeObjectURL(objectUrl), 1000)
  window.$message?.success('视频已开始保存到本地')
}

async function handleTaskVideoDownload(task) {
  try {
    await downloadTaskVideo(task)
  } catch (error) {
    window.$message?.error(error?.message || '保存视频失败')
  }
}
</script>

<template>
  <CommonPage show-footer>
    <template #header>
      <div class="task-header">
        <div>
          <p class="task-header__eyebrow">任务中心</p>
          <h2>视频任务</h2>
          <p>App 端生成的视频任务统一沉淀到这里，后台可以直接查看状态、用户与失败原因。</p>
        </div>
        <NButton type="primary" @click="fetchTasks">刷新列表</NButton>
      </div>
    </template>

    <div class="task-page">
      <section class="task-summary">
        <div v-for="item in summaryItems" :key="item.label" class="task-stat">
          <span>{{ item.label }}</span>
          <strong>{{ item.value }}</strong>
          <small>{{ item.hint }}</small>
        </div>
      </section>

      <section class="task-panel">
        <div class="task-filters">
          <NInput
            v-model:value="queryForm.username"
            clearable
            placeholder="搜索用户名"
            @keyup.enter="fetchTasks"
          />
          <NSelect v-model:value="queryForm.status" :options="statusOptions" placeholder="状态" />
          <NSelect
            v-model:value="queryForm.taskType"
            :options="taskTypeOptions"
            placeholder="任务类型"
          />
          <NButton type="primary" @click="fetchTasks">查询</NButton>
          <NButton quaternary @click="handleReset">重置</NButton>
        </div>

        <NDataTable :loading="loading" :columns="columns" :data="rows" :scroll-x="1180" remote />

        <div class="task-pagination">
          <NPagination
            :page="pagination.page"
            :page-size="pagination.pageSize"
            :item-count="pagination.itemCount"
            @update:page="handlePageChange"
          />
        </div>
      </section>
    </div>
  </CommonPage>

  <NDrawer v-model:show="detailVisible" placement="right" :width="520">
    <NDrawerContent closable>
      <template #header>
        <div v-if="activeTask" class="task-detail__header">
          <div>
            <p class="task-detail__eyebrow">任务详情</p>
            <h3>{{ activeTask.user?.alias || activeTask.user?.username || '未绑定用户' }}</h3>
            <p>
              {{ resolveTaskTypeLabel(activeTask.task_type) }} ·
              {{ activeTask.task_source || 'app' }}
            </p>
          </div>
          <NTag round :type="resolveStatusType(activeTask.status)">
            {{ resolveStatusLabel(activeTask.status) }}
          </NTag>
        </div>
      </template>

      <div v-if="activeTask" class="task-detail">
        <section class="task-detail__meta">
          <div v-for="item in activeTaskMeta" :key="item.label" class="task-detail__meta-item">
            <span>{{ item.label }}</span>
            <strong>{{ item.value }}</strong>
          </div>
        </section>

        <section class="task-detail__section">
          <h4>任务内容</h4>
          <div class="task-detail__content-grid">
            <article class="task-detail__card">
              <span>原始文案</span>
              <p>{{ readText(activeTask.input_text) }}</p>
            </article>
            <article class="task-detail__card">
              <span>润色文案</span>
              <p>{{ readText(activeTask.polished_text) }}</p>
            </article>
            <article class="task-detail__card task-detail__card--wide">
              <span>最终提示词</span>
              <p>{{ readText(activeTask.prompt) }}</p>
            </article>
          </div>
        </section>

        <section class="task-detail__section">
          <h4>结果与时间</h4>
          <div class="task-detail__content-grid">
            <article class="task-detail__card">
              <span>创建时间</span>
              <p>{{ activeTask.created_at ? formatDate(activeTask.created_at) : '未提供' }}</p>
            </article>
            <article class="task-detail__card">
              <span>更新时间</span>
              <p>{{ activeTask.updated_at ? formatDate(activeTask.updated_at) : '未提供' }}</p>
            </article>
            <article class="task-detail__card">
              <span>视频地址</span>
              <p v-if="!activeTask.video_url">{{ readText(activeTask.video_url) }}</p>
              <a
                v-else
                class="task-detail__link"
                :href="activeTask.video_url"
                target="_blank"
                rel="noreferrer"
              >
                打开视频
              </a>
            </article>
            <article class="task-detail__card">
              <span>错误信息</span>
              <p>{{ readText(activeTask.error_message) }}</p>
            </article>
          </div>
        </section>

        <section class="task-detail__section">
          <h4>参考图</h4>
          <div v-if="activeTaskAssets.length" class="task-detail__assets">
            <article
              v-for="asset in activeTaskAssets"
              :key="asset.id || asset.file_url"
              class="task-detail__asset"
            >
              <NImage
                width="100"
                height="100"
                object-fit="cover"
                :src="asset.file_url"
                fallback-src=""
              />
              <strong>{{ asset.file_name || 'reference' }}</strong>
              <span>{{ asset.asset_type || 'reference_image' }}</span>
            </article>
          </div>
          <NEmpty v-else description="未上传参考图" />
        </section>

        <section v-if="activeTask.video_url" class="task-detail__section">
          <h4>视频预览与下载</h4>
          <article class="task-detail__card task-detail__card--wide">
            <video
              class="task-detail__video"
              :src="activeTask.video_url"
              controls
              playsinline
              preload="metadata"
            ></video>
            <div class="task-detail__video-actions">
              <NButton type="primary" secondary @click="openTaskVideo(activeTask)">
                新窗口预览
              </NButton>
              <NButton quaternary type="primary" @click="handleTaskVideoDownload(activeTask)">
                保存到本地
              </NButton>
            </div>
          </article>
        </section>
      </div>
    </NDrawerContent>
  </NDrawer>
</template>

<style scoped>
.task-header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 20px;
  width: 100%;
}

.task-header__eyebrow {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--brand-primary);
}

.task-header h2 {
  margin: 0;
  color: var(--app-text);
}

.task-header p:last-child {
  margin: 10px 0 0;
  max-width: 660px;
  color: var(--app-muted);
  line-height: 1.6;
}

.task-page {
  display: grid;
  gap: 20px;
}

.task-summary {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
}

.task-stat {
  display: grid;
  gap: 6px;
  padding: 14px 16px;
  border: 1px solid var(--shell-border);
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.5);
  box-shadow: var(--soft-shadow);
  backdrop-filter: blur(14px);
}

.task-stat span {
  font-size: 12px;
  color: var(--app-muted);
}

.task-stat strong {
  font-size: 30px;
  line-height: 1;
  color: var(--app-text);
}

.task-stat small {
  color: var(--app-muted);
}

.task-panel {
  display: grid;
  gap: 16px;
  padding: 18px;
  border: 1px solid var(--shell-border);
  border-radius: 18px;
  background: rgba(255, 251, 248, 0.7);
  box-shadow: var(--soft-shadow);
  backdrop-filter: blur(18px);
}

.task-filters {
  display: grid;
  grid-template-columns: 1.2fr 180px 180px auto auto;
  gap: 12px;
  align-items: center;
}

.task-pagination {
  display: flex;
  justify-content: flex-end;
}

.task-user {
  display: grid;
  gap: 4px;
}

.task-user strong {
  color: var(--app-text);
}

.task-user span {
  font-size: 12px;
  color: var(--app-muted);
}

.task-actions {
  display: flex;
  justify-content: flex-end;
  gap: 4px;
}

.task-detail {
  display: grid;
  gap: 20px;
}

.task-detail__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.task-detail__eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--brand-primary);
}

.task-detail__header h3 {
  margin: 0;
  color: var(--app-text);
}

.task-detail__header p:last-child {
  margin: 8px 0 0;
  color: var(--app-muted);
}

.task-detail__meta,
.task-detail__content-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.task-detail__meta-item,
.task-detail__card,
.task-detail__asset {
  padding: 14px 16px;
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.54);
  border: 1px solid rgba(255, 105, 0, 0.08);
}

.task-detail__meta-item span,
.task-detail__card span,
.task-detail__asset span {
  display: block;
  font-size: 12px;
  color: var(--app-muted);
}

.task-detail__meta-item strong,
.task-detail__asset strong {
  display: block;
  margin-top: 6px;
  color: var(--app-text);
}

.task-detail__section {
  display: grid;
  gap: 12px;
}

.task-detail__section h4 {
  margin: 0;
  color: var(--app-text);
}

.task-detail__card p {
  margin: 8px 0 0;
  color: var(--app-text);
  line-height: 1.7;
  white-space: pre-wrap;
  word-break: break-word;
}

.task-detail__card--wide {
  grid-column: 1 / -1;
}

.task-detail__assets {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.task-detail__asset {
  display: grid;
  gap: 10px;
}

.task-detail__link {
  display: inline-flex;
  margin-top: 8px;
  color: var(--brand-primary);
  font-weight: 700;
}

.task-detail__video {
  width: 100%;
  margin-top: 10px;
  border-radius: 14px;
  background: rgba(16, 12, 9, 0.92);
}

.task-detail__video-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-top: 14px;
}

@media (max-width: 1024px) {
  .task-summary {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .task-filters {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 720px) {
  .task-header {
    flex-direction: column;
    align-items: flex-start;
  }

  .task-summary,
  .task-filters,
  .task-detail__meta,
  .task-detail__content-grid,
  .task-detail__assets {
    grid-template-columns: 1fr;
  }
}
</style>
