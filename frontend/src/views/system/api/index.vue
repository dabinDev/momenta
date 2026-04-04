<script setup>
import { computed, h, onMounted, ref, resolveDirective, withDirectives } from 'vue'
import { NButton, NForm, NFormItem, NInput, NPopconfirm, NTag } from 'naive-ui'

import CommonPage from '@/components/page/CommonPage.vue'
import QueryBarItem from '@/components/query-bar/QueryBarItem.vue'
import CrudModal from '@/components/table/CrudModal.vue'
import CrudTable from '@/components/table/CrudTable.vue'
import TheIcon from '@/components/icon/TheIcon.vue'

import { renderIcon } from '@/utils'
import { useCRUD } from '@/composables'
import api from '@/api'

defineOptions({ name: '接口管理' })

const $table = ref(null)
const queryItems = ref({
  path: null,
  summary: null,
  tags: null,
})
const tableRows = ref([])
const vPermission = resolveDirective('permission')

const {
  modalVisible,
  modalTitle,
  modalLoading,
  handleSave,
  modalForm,
  modalFormRef,
  handleEdit,
  handleDelete,
  handleAdd,
} = useCRUD({
  name: 'API',
  initForm: {
    path: '',
    method: '',
    summary: '',
    tags: '',
  },
  doCreate: api.createApi,
  doUpdate: api.updateApi,
  doDelete: api.deleteApi,
  refresh: () => $table.value?.handleSearch(),
})

onMounted(() => {
  $table.value?.handleSearch()
})

const addAPIRules = {
  path: [
    {
      required: true,
      message: '请输入 API 路径',
      trigger: ['input', 'blur', 'change'],
    },
  ],
  method: [
    {
      required: true,
      message: '请输入请求方法',
      trigger: ['input', 'blur', 'change'],
    },
  ],
  summary: [
    {
      required: true,
      message: '请输入 API 简介',
      trigger: ['input', 'blur', 'change'],
    },
  ],
  tags: [
    {
      required: true,
      message: '请输入模块标签',
      trigger: ['input', 'blur', 'change'],
    },
  ],
}

const activeFilters = computed(() => {
  const filters = []
  if (queryItems.value.path) filters.push({ type: 'primary', label: `路径：${queryItems.value.path}` })
  if (queryItems.value.summary) filters.push({ type: 'success', label: `简介：${queryItems.value.summary}` })
  if (queryItems.value.tags) filters.push({ type: 'warning', label: `模块：${queryItems.value.tags}` })
  return filters
})

const uniqueTags = computed(() => new Set(tableRows.value.map(item => item.tags).filter(Boolean)).size)
const methodStats = computed(() => {
  const stats = {}
  tableRows.value.forEach((item) => {
    const method = String(item.method || '').toUpperCase() || 'UNKNOWN'
    stats[method] = (stats[method] || 0) + 1
  })
  return stats
})

const overviewStats = computed(() => [
  {
    label: '当前页接口',
    value: tableRows.value.length,
    hint: '已加载记录',
  },
  {
    label: '模块数量',
    value: uniqueTags.value,
    hint: '按 tags 统计',
  },
  {
    label: 'GET 请求',
    value: methodStats.value.GET || 0,
    hint: '读取类接口',
  },
  {
    label: '写入请求',
    value: (methodStats.value.POST || 0) + (methodStats.value.PUT || 0) + (methodStats.value.DELETE || 0),
    hint: 'POST / PUT / DELETE',
  },
])

const columns = [
  {
    title: '路径',
    key: 'path',
    width: 290,
    ellipsis: { tooltip: true },
    render(row) {
      return h('div', { class: 'api-path-cell' }, [
        h('strong', { class: 'api-path-cell__title' }, row.path || '--'),
        h('span', { class: 'api-path-cell__meta' }, row.summary || '未填写简介'),
      ])
    },
  },
  {
    title: '方法',
    key: 'method',
    width: 100,
    render(row) {
      const method = String(row.method || '').toUpperCase()
      const type = method === 'GET' ? 'success' : method === 'POST' ? 'warning' : method === 'DELETE' ? 'error' : 'info'
      return h(NTag, { size: 'small', round: true, type }, { default: () => method || '--' })
    },
  },
  {
    title: '简介',
    key: 'summary',
    width: 260,
    ellipsis: { tooltip: true },
    render(row) {
      return row.summary || '--'
    },
  },
  {
    title: '模块',
    key: 'tags',
    width: 130,
    ellipsis: { tooltip: true },
    render(row) {
      return h(NTag, { size: 'small', type: 'info', round: true }, { default: () => row.tags || '--' })
    },
  },
  {
    title: '操作',
    key: 'actions',
    width: 170,
    fixed: 'right',
    render(row) {
      return h('div', { class: 'api-action-list' }, [
        withDirectives(
          h(
            NButton,
            {
              size: 'small',
              quaternary: true,
              type: 'primary',
              onClick: () => handleEdit(row),
            },
            {
              default: () => '编辑',
              icon: renderIcon('material-symbols:edit', { size: 16 }),
            }
          ),
          [[vPermission, 'post/api/v1/api/update']]
        ),
        h(
          NPopconfirm,
          {
            onPositiveClick: () => handleDelete({ api_id: row.id }, false),
          },
          {
            trigger: () =>
              withDirectives(
                h(
                  NButton,
                  {
                    size: 'small',
                    quaternary: true,
                    type: 'error',
                  },
                  {
                    default: () => '删除',
                    icon: renderIcon('material-symbols:delete-outline', { size: 16 }),
                  }
                ),
                [[vPermission, 'delete/api/v1/api/delete']]
              ),
            default: () => h('div', {}, '确定删除该 API 吗？'),
          }
        ),
      ])
    },
  },
]

function handleTableDataChange(data = []) {
  tableRows.value = data
}

async function handleRefreshApi() {
  await $dialog.confirm({
    title: '刷新接口',
    type: 'warning',
    content: '此操作会根据后端 app.routes 重新生成接口列表，确认继续吗？',
    async confirm() {
      await api.refreshApi()
      $message.success('接口列表已刷新')
      $table.value?.handleSearch()
    },
  })
}
</script>

<template>
  <CommonPage show-footer>
    <template #header>
      <div class="api-page__header">
        <div class="api-page__header-copy">
          <p class="api-page__eyebrow">接口台账</p>
          <h2>接口管理</h2>
          <p>用更清楚的路径、方法和模块标签层级来整理接口清单，方便后台人员快速定位。</p>
        </div>
        <div class="api-page__header-actions">
          <NButton
            v-permission="'post/api/v1/api/refresh'"
            type="warning"
            @click="handleRefreshApi"
          >
            <TheIcon icon="material-symbols:refresh" :size="18" class="mr-5" />
            刷新接口
          </NButton>
          <NButton
            v-permission="'post/api/v1/api/create'"
            type="primary"
            @click="handleAdd"
          >
            <TheIcon icon="material-symbols:add" :size="18" class="mr-5" />
            新建接口
          </NButton>
        </div>
      </div>
    </template>

    <div class="api-page">
      <section class="api-overview">
        <div class="api-overview__intro">
          <div>
            <p class="api-overview__label">接口概览</p>
            <h3>按路径、简介和模块快速定位</h3>
            <p>筛选条件和关键数量被收进顶部区域，减少列表滚动中的认知负担。</p>
          </div>
          <div class="api-overview__filters">
            <NTag v-for="item in activeFilters" :key="item.label" round :type="item.type">
              {{ item.label }}
            </NTag>
          </div>
        </div>

        <div class="api-overview__stats">
          <div v-for="item in overviewStats" :key="item.label" class="api-stat">
            <span>{{ item.label }}</span>
            <strong>{{ item.value }}</strong>
            <small>{{ item.hint }}</small>
          </div>
        </div>
      </section>

      <section class="api-table-panel">
        <div class="api-table-panel__header">
          <div>
            <p class="api-table-panel__eyebrow">接口列表</p>
            <h3>路径、方法和模块归属</h3>
            <p>刷新入口和编辑动作保持在同一工作区里，便于维护接口注册表。</p>
          </div>
        </div>

        <CrudTable
          ref="$table"
          v-model:query-items="queryItems"
          :columns="columns"
          :get-data="api.getApis"
          :scroll-x="1080"
          @on-data-change="handleTableDataChange"
        >
          <template #queryBar>
            <QueryBarItem label="路径" :label-width="44">
              <NInput
                v-model:value="queryItems.path"
                clearable
                type="text"
                placeholder="输入 API 路径"
                @keypress.enter="$table?.handleSearch()"
              />
            </QueryBarItem>
            <QueryBarItem label="简介" :label-width="44">
              <NInput
                v-model:value="queryItems.summary"
                clearable
                type="text"
                placeholder="输入接口简介"
                @keypress.enter="$table?.handleSearch()"
              />
            </QueryBarItem>
            <QueryBarItem label="模块" :label-width="44">
              <NInput
                v-model:value="queryItems.tags"
                clearable
                type="text"
                placeholder="输入模块标签"
                @keypress.enter="$table?.handleSearch()"
              />
            </QueryBarItem>
          </template>
        </CrudTable>
      </section>

      <CrudModal
        v-model:visible="modalVisible"
        :title="modalTitle"
        :loading="modalLoading"
        @save="handleSave"
      >
        <NForm
          ref="modalFormRef"
          label-placement="left"
          label-align="left"
          :label-width="84"
          :model="modalForm"
          :rules="addAPIRules"
        >
          <NFormItem label="接口路径" path="path">
            <NInput v-model:value="modalForm.path" clearable placeholder="请输入 API 路径" />
          </NFormItem>
          <NFormItem label="请求方法" path="method">
            <NInput v-model:value="modalForm.method" clearable placeholder="例如 GET / POST" />
          </NFormItem>
          <NFormItem label="接口简介" path="summary">
            <NInput v-model:value="modalForm.summary" clearable placeholder="请输入接口简介" />
          </NFormItem>
          <NFormItem label="模块标签" path="tags">
            <NInput v-model:value="modalForm.tags" clearable placeholder="请输入模块标签" />
          </NFormItem>
        </NForm>
      </CrudModal>
    </div>
  </CommonPage>
</template>

<style scoped>
.api-page {
  display: grid;
  gap: 24px;
}

.api-page__header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 18px;
  width: 100%;
}

.api-page__header-copy {
  max-width: 620px;
}

.api-page__header-actions {
  display: flex;
  gap: 12px;
}

.api-page__eyebrow,
.api-overview__label,
.api-table-panel__eyebrow {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: #6b6d86;
}

.api-page__header-copy h2,
.api-overview__intro h3,
.api-table-panel__header h3 {
  margin: 0;
  color: #2b3040;
}

.api-page__header-copy h2 {
  font-size: 32px;
  line-height: 1.1;
}

.api-page__header-copy p,
.api-overview__intro p,
.api-table-panel__header p {
  margin: 10px 0 0;
  color: #666d78;
  line-height: 1.6;
}

.api-overview {
  padding: 24px 26px;
  border-radius: 28px;
  border: 1px solid rgba(87, 98, 137, 0.08);
  background:
    radial-gradient(circle at top right, rgba(140, 184, 255, 0.16), transparent 30%),
    linear-gradient(135deg, #f7f9fe 0%, #f4f7fb 45%, #fff8ef 100%);
}

.api-overview__intro {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 18px;
}

.api-overview__filters {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 10px;
  min-width: 220px;
}

.api-overview__stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
  margin-top: 18px;
}

.api-stat {
  display: grid;
  gap: 6px;
  padding-top: 16px;
  border-top: 1px solid rgba(87, 98, 137, 0.08);
}

.api-stat span,
.api-path-cell__meta {
  font-size: 12px;
  color: #7f8796;
}

.api-stat strong {
  font-size: 28px;
  line-height: 1;
  color: #283143;
}

.api-stat small {
  color: #7f8796;
  line-height: 1.4;
}

.api-table-panel {
  padding: 22px;
  border-radius: 24px;
  border: 1px solid rgba(87, 98, 137, 0.08);
  background: #fff;
}

.api-path-cell {
  display: grid;
  gap: 4px;
}

.api-path-cell__title {
  color: #283143;
  font-size: 14px;
}

.api-action-list {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 4px;
}

:deep(.n-data-table-th) {
  background: #f8f9fd;
}

:deep(.n-data-table-td) {
  vertical-align: middle;
}

@media (max-width: 900px) {
  .api-page__header,
  .api-overview__intro {
    flex-direction: column;
    align-items: flex-start;
  }

  .api-page__header-actions,
  .api-overview__filters {
    width: 100%;
    justify-content: flex-start;
  }

  .api-overview__stats {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .api-overview,
  .api-table-panel {
    padding: 18px;
    border-radius: 20px;
  }

  .api-page__header-copy h2 {
    font-size: 26px;
  }

  .api-page__header-actions,
  .api-overview__stats {
    grid-template-columns: 1fr;
  }
}
</style>
