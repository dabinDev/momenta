<script setup>
import { computed, h, onMounted, ref } from 'vue'
import {
  NButton,
  NDataTable,
  NDrawer,
  NDrawerContent,
  NInput,
  NPagination,
  NSelect,
  NTag,
} from 'naive-ui'

import CommonPage from '@/components/page/CommonPage.vue'
import { formatDate } from '@/utils'
import api from '@/api'

const loading = ref(false)
const rows = ref([])
const detailVisible = ref(false)
const activeLog = ref(null)
const queryForm = ref({
  username: '',
  status: '',
  provider: '',
})
const pagination = ref({
  page: 1,
  pageSize: 10,
  itemCount: 0,
})

const statusOptions = [
  { label: '全部状态', value: '' },
  { label: '成功', value: 'success' },
  { label: '失败', value: 'failed' },
]

const providerOptions = [
  { label: '全部服务', value: '' },
  { label: '讯飞', value: 'xfyun' },
]

const summaryItems = computed(() => [
  {
    label: '日志总数',
    value: pagination.value.itemCount,
    hint: '语音识别记录',
  },
  {
    label: '成功',
    value: rows.value.filter((item) => item.status === 'success').length,
    hint: '本页识别成功',
  },
  {
    label: '失败',
    value: rows.value.filter((item) => item.status === 'failed').length,
    hint: '本页异常记录',
  },
  {
    label: '平均时长',
    value: averageDuration.value,
    hint: '单位秒',
  },
])

const averageDuration = computed(() => {
  if (!rows.value.length) return '0.0'
  const total = rows.value.reduce((sum, item) => sum + Number(item.audio_duration || 0), 0)
  return (total / rows.value.length).toFixed(1)
})

const activeLogMeta = computed(() => {
  if (!activeLog.value) return []
  return [
    {
      label: '识别状态',
      value: activeLog.value.status === 'success' ? '成功' : '失败',
    },
    {
      label: '语音服务',
      value: activeLog.value.provider || 'xfyun',
    },
    {
      label: '音频格式',
      value: `${(activeLog.value.audio_format || '--').toUpperCase()}`,
    },
    {
      label: '音频时长',
      value: `${Number(activeLog.value.audio_duration || 0).toFixed(1)}s`,
    },
    {
      label: '识别语言',
      value: `${activeLog.value.language || 'zh_cn'} / ${activeLog.value.accent || 'mandarin'}`,
    },
    {
      label: '创建时间',
      value: activeLog.value.created_at ? formatDate(activeLog.value.created_at) : '未提供',
    },
  ]
})

const columns = [
  {
    title: '用户',
    key: 'user',
    width: 170,
    render(row) {
      const user = row.user || {}
      return h('div', { class: 'voice-user' }, [
        h('strong', {}, user.alias || user.username || '--'),
        h('span', {}, user.username ? `@${user.username}` : '未绑定'),
      ])
    },
  },
  {
    title: '状态',
    key: 'status',
    width: 110,
    render(row) {
      return h(
        NTag,
        { round: true, type: row.status === 'success' ? 'success' : 'error' },
        { default: () => (row.status === 'success' ? '成功' : '失败') }
      )
    },
  },
  {
    title: '识别结果',
    key: 'recognized_text',
    minWidth: 320,
    ellipsis: { tooltip: true },
    render(row) {
      return row.recognized_text || row.error_message || '--'
    },
  },
  {
    title: '关联任务',
    key: 'task',
    width: 180,
    ellipsis: { tooltip: true },
    render(row) {
      return row.task?.prompt || row.task_id || '--'
    },
  },
  {
    title: '音频时长',
    key: 'audio_duration',
    width: 100,
    render(row) {
      return `${Number(row.audio_duration || 0).toFixed(1)}s`
    },
  },
  {
    title: '格式',
    key: 'audio_format',
    width: 88,
    render(row) {
      return (row.audio_format || '--').toUpperCase()
    },
  },
  {
    title: '操作',
    key: 'actions',
    width: 96,
    fixed: 'right',
    render(row) {
      return h(
        NButton,
        {
          size: 'small',
          quaternary: true,
          onClick: () => openDetail(row),
        },
        { default: () => '详情' }
      )
    },
  },
  {
    title: '创建时间',
    key: 'created_at',
    width: 180,
    render(row) {
      return row.created_at ? formatDate(row.created_at) : '--'
    },
  },
]

onMounted(() => {
  fetchLogs()
})

async function fetchLogs() {
  loading.value = true
  try {
    const res = await api.getVoiceLogList({
      page: pagination.value.page,
      page_size: pagination.value.pageSize,
      username: queryForm.value.username || undefined,
      status: queryForm.value.status || undefined,
      provider: queryForm.value.provider || undefined,
    })
    rows.value = res.data || []
    pagination.value.itemCount = res.total || 0
  } finally {
    loading.value = false
  }
}

function openDetail(row) {
  activeLog.value = row
  detailVisible.value = true
}

function handleReset() {
  queryForm.value = {
    username: '',
    status: '',
    provider: '',
  }
  pagination.value.page = 1
  fetchLogs()
}

function handlePageChange(page) {
  pagination.value.page = page
  fetchLogs()
}

function readText(value) {
  const text = `${value ?? ''}`.trim()
  return text || '未提供'
}
</script>

<template>
  <CommonPage show-footer>
    <template #header>
      <div class="voice-header">
        <div>
          <p class="voice-header__eyebrow">语音日志</p>
          <h2>语音日志</h2>
          <p>每次语音识别都会留下审计记录，方便排查识别率、失败原因和用户使用情况。</p>
        </div>
      </div>
    </template>

    <div class="voice-page">
      <section class="voice-summary">
        <div v-for="item in summaryItems" :key="item.label" class="voice-stat">
          <span>{{ item.label }}</span>
          <strong>{{ item.value }}</strong>
          <small>{{ item.hint }}</small>
        </div>
      </section>

      <section class="voice-panel">
        <div class="voice-filters">
          <NInput
            v-model:value="queryForm.username"
            clearable
            placeholder="搜索用户名"
            @keyup.enter="fetchLogs"
          />
          <NSelect
            v-model:value="queryForm.status"
            :options="statusOptions"
            placeholder="识别状态"
          />
          <NSelect
            v-model:value="queryForm.provider"
            :options="providerOptions"
            placeholder="语音服务"
          />
          <NButton type="primary" @click="fetchLogs">查询</NButton>
          <NButton quaternary @click="handleReset">重置</NButton>
        </div>

        <NDataTable :loading="loading" :columns="columns" :data="rows" :scroll-x="1120" remote />

        <div class="voice-pagination">
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

  <NDrawer v-model:show="detailVisible" placement="right" :width="500">
    <NDrawerContent closable>
      <template #header>
        <div v-if="activeLog" class="voice-detail__header">
          <div>
            <p class="voice-detail__eyebrow">日志详情</p>
            <h3>{{ activeLog.user?.alias || activeLog.user?.username || '未绑定用户' }}</h3>
            <p>{{ activeLog.file_name || '未提供文件名' }}</p>
          </div>
          <NTag round :type="activeLog.status === 'success' ? 'success' : 'error'">
            {{ activeLog.status === 'success' ? '成功' : '失败' }}
          </NTag>
        </div>
      </template>

      <div v-if="activeLog" class="voice-detail">
        <section class="voice-detail__meta">
          <div v-for="item in activeLogMeta" :key="item.label" class="voice-detail__meta-item">
            <span>{{ item.label }}</span>
            <strong>{{ item.value }}</strong>
          </div>
        </section>

        <section class="voice-detail__section">
          <h4>识别文本</h4>
          <article class="voice-detail__card">
            <p>{{ readText(activeLog.recognized_text) }}</p>
          </article>
        </section>

        <section class="voice-detail__section">
          <h4>异常信息</h4>
          <article class="voice-detail__card">
            <p>{{ readText(activeLog.error_message) }}</p>
          </article>
        </section>

        <section class="voice-detail__section">
          <h4>关联任务</h4>
          <article class="voice-detail__card">
            <p>{{ readText(activeLog.task?.prompt || activeLog.task_id) }}</p>
          </article>
        </section>
      </div>
    </NDrawerContent>
  </NDrawer>
</template>

<style scoped>
.voice-header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 20px;
  width: 100%;
}

.voice-header__eyebrow {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--brand-primary);
}

.voice-header h2 {
  margin: 0;
  color: var(--app-text);
}

.voice-header p:last-child {
  margin: 10px 0 0;
  max-width: 660px;
  color: var(--app-muted);
  line-height: 1.6;
}

.voice-page {
  display: grid;
  gap: 20px;
}

.voice-summary {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
}

.voice-stat {
  display: grid;
  gap: 6px;
  padding: 14px 16px;
  border: 1px solid var(--shell-border);
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.5);
  box-shadow: var(--soft-shadow);
  backdrop-filter: blur(14px);
}

.voice-stat span {
  font-size: 12px;
  color: var(--app-muted);
}

.voice-stat strong {
  font-size: 30px;
  line-height: 1;
  color: var(--app-text);
}

.voice-stat small {
  color: var(--app-muted);
}

.voice-panel {
  display: grid;
  gap: 16px;
  padding: 18px;
  border: 1px solid var(--shell-border);
  border-radius: 18px;
  background: rgba(255, 251, 248, 0.7);
  box-shadow: var(--soft-shadow);
  backdrop-filter: blur(18px);
}

.voice-filters {
  display: grid;
  grid-template-columns: 1.2fr 180px 180px auto auto;
  gap: 12px;
  align-items: center;
}

.voice-pagination {
  display: flex;
  justify-content: flex-end;
}

.voice-user {
  display: grid;
  gap: 4px;
}

.voice-user strong {
  color: var(--app-text);
}

.voice-user span {
  font-size: 12px;
  color: var(--app-muted);
}

.voice-detail {
  display: grid;
  gap: 20px;
}

.voice-detail__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.voice-detail__eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--brand-primary);
}

.voice-detail__header h3 {
  margin: 0;
  color: var(--app-text);
}

.voice-detail__header p:last-child {
  margin: 8px 0 0;
  color: var(--app-muted);
}

.voice-detail__meta {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.voice-detail__meta-item,
.voice-detail__card {
  padding: 14px 16px;
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.54);
  border: 1px solid rgba(255, 105, 0, 0.08);
}

.voice-detail__meta-item span {
  display: block;
  font-size: 12px;
  color: var(--app-muted);
}

.voice-detail__meta-item strong {
  display: block;
  margin-top: 6px;
  color: var(--app-text);
}

.voice-detail__section {
  display: grid;
  gap: 12px;
}

.voice-detail__section h4 {
  margin: 0;
  color: var(--app-text);
}

.voice-detail__card p {
  margin: 0;
  color: var(--app-text);
  line-height: 1.7;
  white-space: pre-wrap;
  word-break: break-word;
}

@media (max-width: 1024px) {
  .voice-summary {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .voice-filters {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 720px) {
  .voice-summary,
  .voice-filters,
  .voice-detail__meta {
    grid-template-columns: 1fr;
  }
}
</style>
