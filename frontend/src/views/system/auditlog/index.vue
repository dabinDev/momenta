<script setup>
import { computed, h, onMounted, ref } from 'vue'
import { NDatePicker, NInput, NPopover, NSelect, NTag } from 'naive-ui'
import TheIcon from '@/components/icon/TheIcon.vue'

import CommonPage from '@/components/page/CommonPage.vue'
import QueryBarItem from '@/components/query-bar/QueryBarItem.vue'
import CrudTable from '@/components/table/CrudTable.vue'

import api from '@/api'

defineOptions({ name: '审计日志' })

const $table = ref(null)
const tableRows = ref([])
const queryItems = ref({})

const methodOptions = [
  { label: 'GET', value: 'GET' },
  { label: 'POST', value: 'POST' },
  { label: 'DELETE', value: 'DELETE' },
  { label: 'PUT', value: 'PUT' },
]

const startOfDayTimestamp = getStartOfDayTimestamp()
const endOfDayTimestamp = getEndOfDayTimestamp()
const datetimeRange = ref([startOfDayTimestamp, endOfDayTimestamp])

queryItems.value.start_time = formatTimestamp(startOfDayTimestamp)
queryItems.value.end_time = formatTimestamp(endOfDayTimestamp)

onMounted(() => {
  $table.value?.handleSearch()
})

const activeFilters = computed(() => {
  const filters = []
  if (queryItems.value.username) filters.push({ type: 'primary', label: `用户：${queryItems.value.username}` })
  if (queryItems.value.module) filters.push({ type: 'info', label: `模块：${queryItems.value.module}` })
  if (queryItems.value.method) filters.push({ type: 'success', label: `方法：${queryItems.value.method}` })
  if (queryItems.value.status) filters.push({ type: 'warning', label: `状态：${queryItems.value.status}` })
  return filters
})

const overviewStats = computed(() => {
  const total = tableRows.value.length
  const errorCount = tableRows.value.filter(item => Number(item.status) >= 400).length
  const getCount = tableRows.value.filter(item => String(item.method).toUpperCase() === 'GET').length
  const avgResponseTime = total
    ? (
        tableRows.value.reduce((sum, item) => sum + Number(item.response_time || 0), 0) / total
      ).toFixed(3)
    : '0.000'

  return [
    { label: '当前页日志', value: total, hint: '已加载记录' },
    { label: '异常响应', value: errorCount, hint: '状态码 >= 400' },
    { label: 'GET 请求', value: getCount, hint: '读取类操作' },
    { label: '平均耗时', value: `${avgResponseTime}s`, hint: '当前列表均值' },
  ]
})

const columns = [
  {
    title: '操作人',
    key: 'username',
    width: 150,
    render(row) {
      return h('div', { class: 'audit-user-cell' }, [
        h('strong', { class: 'audit-user-cell__title' }, row.username || '--'),
        h('span', { class: 'audit-user-cell__meta' }, row.module || '未分类模块'),
      ])
    },
  },
  {
    title: '接口信息',
    key: 'summary',
    width: 260,
    render(row) {
      return h('div', { class: 'audit-endpoint-cell' }, [
        h('strong', { class: 'audit-endpoint-cell__title' }, row.summary || '--'),
        h('span', { class: 'audit-endpoint-cell__meta' }, row.path || '--'),
      ])
    },
  },
  {
    title: '方法',
    key: 'method',
    width: 90,
    render(row) {
      const method = String(row.method || '').toUpperCase()
      const type = method === 'GET' ? 'success' : method === 'POST' ? 'warning' : method === 'DELETE' ? 'error' : 'info'
      return h(NTag, { round: true, size: 'small', type }, { default: () => method || '--' })
    },
  },
  {
    title: '状态',
    key: 'status',
    width: 90,
    render(row) {
      const status = Number(row.status || 0)
      const type = status >= 500 ? 'error' : status >= 400 ? 'warning' : 'success'
      return h(NTag, { round: true, size: 'small', type }, { default: () => String(row.status || '--') })
    },
  },
  {
    title: '请求体',
    key: 'request_body',
    width: 90,
    render(row) {
      return renderJsonPopover(row.request_args)
    },
  },
  {
    title: '响应体',
    key: 'response_body',
    width: 90,
    render(row) {
      return renderJsonPopover(row.response_body)
    },
  },
  {
    title: '耗时',
    key: 'response_time',
    width: 100,
    render(row) {
      const value = Number(row.response_time || 0)
      const type = value > 1 ? 'error' : value > 0.4 ? 'warning' : 'success'
      return h(NTag, { round: true, size: 'small', type }, { default: () => `${value.toFixed(3)}s` })
    },
  },
  {
    title: '操作时间',
    key: 'created_at',
    width: 180,
    ellipsis: { tooltip: true },
  },
]

function handleDateRangeChange(value) {
  if (value == null) {
    queryItems.value.start_time = null
    queryItems.value.end_time = null
  } else {
    queryItems.value.start_time = formatTimestamp(value[0])
    queryItems.value.end_time = formatTimestamp(value[1])
  }
}

function handleTableDataChange(data = []) {
  tableRows.value = data
}

function renderJsonPopover(data) {
  return h(
    NPopover,
    {
      trigger: 'hover',
      placement: 'right',
    },
    {
      trigger: () =>
        h('button', { class: 'audit-json-button', type: 'button' }, [
          h(TheIcon, { icon: 'carbon:data-view', size: 18 }),
        ]),
      default: () =>
        h(
          'pre',
          {
            class: 'audit-json-popover',
          },
          formatJSON(data)
        ),
    }
  )
}

function formatJSON(data) {
  try {
    return typeof data === 'string'
      ? JSON.stringify(JSON.parse(data), null, 2)
      : JSON.stringify(data, null, 2)
  } catch (e) {
    return data || '无数据'
  }
}

function formatTimestamp(timestamp) {
  const date = new Date(timestamp)
  const pad = num => num.toString().padStart(2, '0')

  const year = date.getFullYear()
  const month = pad(date.getMonth() + 1)
  const day = pad(date.getDate())
  const hours = pad(date.getHours())
  const minutes = pad(date.getMinutes())
  const seconds = pad(date.getSeconds())

  return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`
}

function getStartOfDayTimestamp() {
  const now = new Date()
  now.setHours(0, 0, 0, 0)
  return now.getTime()
}

function getEndOfDayTimestamp() {
  const now = new Date()
  now.setHours(23, 59, 59, 999)
  return now.getTime()
}
</script>

<template>
  <CommonPage>
    <template #header>
      <div class="audit-page__header">
        <div class="audit-page__header-copy">
          <p class="audit-page__eyebrow">AUDIT LOGS</p>
          <h2>审计日志</h2>
          <p>按用户、模块、接口和状态快速筛选，帮助你更快定位请求与响应记录。</p>
        </div>
      </div>
    </template>

    <div class="audit-page">
      <section class="audit-overview">
        <div class="audit-overview__intro">
          <div>
            <p class="audit-overview__label">日志概览</p>
            <h3>高频筛选条件和关键数量集中展示</h3>
            <p>保留必要维度，减少表格滚动时的上下文丢失。</p>
          </div>
          <div class="audit-overview__filters">
            <NTag v-for="item in activeFilters" :key="item.label" round :type="item.type">
              {{ item.label }}
            </NTag>
          </div>
        </div>

        <div class="audit-overview__stats">
          <div v-for="item in overviewStats" :key="item.label" class="audit-stat">
            <span>{{ item.label }}</span>
            <strong>{{ item.value }}</strong>
            <small>{{ item.hint }}</small>
          </div>
        </div>
      </section>

      <section class="audit-table-panel">
        <div class="audit-table-panel__header">
          <div>
            <p class="audit-table-panel__eyebrow">请求记录</p>
            <h3>接口摘要、状态码与数据详情</h3>
            <p>请求体和响应体通过悬浮查看，列表本身保持紧凑。</p>
          </div>
        </div>

        <CrudTable
          ref="$table"
          v-model:query-items="queryItems"
          :columns="columns"
          :get-data="api.getAuditLogList"
          :scroll-x="1300"
          @on-data-change="handleTableDataChange"
        >
          <template #queryBar>
            <QueryBarItem label="用户" :label-width="44">
              <NInput
                v-model:value="queryItems.username"
                clearable
                type="text"
                placeholder="输入用户名"
                @keypress.enter="$table?.handleSearch()"
              />
            </QueryBarItem>
            <QueryBarItem label="模块" :label-width="44">
              <NInput
                v-model:value="queryItems.module"
                clearable
                type="text"
                placeholder="输入模块名"
                @keypress.enter="$table?.handleSearch()"
              />
            </QueryBarItem>
            <QueryBarItem label="摘要" :label-width="44">
              <NInput
                v-model:value="queryItems.summary"
                clearable
                type="text"
                placeholder="输入接口摘要"
                @keypress.enter="$table?.handleSearch()"
              />
            </QueryBarItem>
            <QueryBarItem label="方法" :label-width="44">
              <NSelect
                v-model:value="queryItems.method"
                style="width: 180px"
                :options="methodOptions"
                clearable
                placeholder="选择请求方法"
              />
            </QueryBarItem>
            <QueryBarItem label="路径" :label-width="44">
              <NInput
                v-model:value="queryItems.path"
                clearable
                type="text"
                placeholder="输入请求路径"
                @keypress.enter="$table?.handleSearch()"
              />
            </QueryBarItem>
            <QueryBarItem label="状态" :label-width="44">
              <NInput
                v-model:value="queryItems.status"
                clearable
                type="text"
                placeholder="输入状态码"
                @keypress.enter="$table?.handleSearch()"
              />
            </QueryBarItem>
            <QueryBarItem label="时间" :label-width="44">
              <NDatePicker
                v-model:value="datetimeRange"
                type="datetimerange"
                clearable
                placeholder="选择时间范围"
                @update:value="handleDateRangeChange"
              />
            </QueryBarItem>
          </template>
        </CrudTable>
      </section>
    </div>
  </CommonPage>
</template>

<style scoped>
.audit-page {
  display: grid;
  gap: 24px;
}

.audit-page__header-copy {
  max-width: 620px;
}

.audit-page__eyebrow,
.audit-overview__label,
.audit-table-panel__eyebrow {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: #6d7284;
}

.audit-page__header-copy h2,
.audit-overview__intro h3,
.audit-table-panel__header h3 {
  margin: 0;
  color: #2d3241;
}

.audit-page__header-copy h2 {
  font-size: 32px;
  line-height: 1.1;
}

.audit-page__header-copy p,
.audit-overview__intro p,
.audit-table-panel__header p {
  margin: 10px 0 0;
  color: #6b7280;
  line-height: 1.6;
}

.audit-overview {
  padding: 24px 26px;
  border-radius: 28px;
  border: 1px solid rgba(82, 97, 126, 0.08);
  background:
    radial-gradient(circle at top right, rgba(188, 210, 255, 0.18), transparent 30%),
    linear-gradient(135deg, #f8faff 0%, #f4f7fb 45%, #fff8ef 100%);
}

.audit-overview__intro {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 18px;
}

.audit-overview__filters {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 10px;
  min-width: 220px;
}

.audit-overview__stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
  margin-top: 18px;
}

.audit-stat {
  display: grid;
  gap: 6px;
  padding-top: 16px;
  border-top: 1px solid rgba(82, 97, 126, 0.08);
}

.audit-stat span,
.audit-user-cell__meta,
.audit-endpoint-cell__meta {
  font-size: 12px;
  color: #7b8393;
}

.audit-stat strong {
  font-size: 28px;
  line-height: 1;
  color: #283041;
}

.audit-stat small {
  color: #7b8393;
  line-height: 1.4;
}

.audit-table-panel {
  padding: 22px;
  border-radius: 24px;
  border: 1px solid rgba(82, 97, 126, 0.08);
  background: #fff;
}

.audit-user-cell,
.audit-endpoint-cell {
  display: grid;
  gap: 4px;
}

.audit-user-cell__title,
.audit-endpoint-cell__title {
  color: #283041;
  font-size: 14px;
}

:deep(.audit-json-button) {
  display: inline-grid;
  place-items: center;
  width: 34px;
  height: 34px;
  border: 1px solid rgba(82, 97, 126, 0.1);
  border-radius: 12px;
  background: #f6f8fb;
  color: #4b5e87;
  cursor: pointer;
}

:deep(.audit-json-popover) {
  max-height: 420px;
  max-width: 520px;
  overflow: auto;
  margin: 0;
  padding: 12px 14px;
  border-radius: 12px;
  background: #f5f7fb;
  color: #29303d;
}

:deep(.n-data-table-th) {
  background: #f8f9fd;
}

:deep(.n-data-table-td) {
  vertical-align: middle;
}

@media (max-width: 900px) {
  .audit-overview__intro {
    flex-direction: column;
    align-items: flex-start;
  }

  .audit-overview__filters {
    justify-content: flex-start;
    min-width: 0;
  }

  .audit-overview__stats {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .audit-overview,
  .audit-table-panel {
    padding: 18px;
    border-radius: 20px;
  }

  .audit-page__header-copy h2 {
    font-size: 26px;
  }

  .audit-overview__stats {
    grid-template-columns: 1fr;
  }
}
</style>
