<script setup>
import { computed, h, onMounted, ref, resolveDirective, withDirectives } from 'vue'
import {
  NButton,
  NForm,
  NFormItem,
  NInput,
  NInputNumber,
  NPopconfirm,
  NTag,
  NTreeSelect,
} from 'naive-ui'

import CommonPage from '@/components/page/CommonPage.vue'
import QueryBarItem from '@/components/query-bar/QueryBarItem.vue'
import CrudModal from '@/components/table/CrudModal.vue'
import CrudTable from '@/components/table/CrudTable.vue'
import TheIcon from '@/components/icon/TheIcon.vue'

import { renderIcon } from '@/utils'
import { useCRUD } from '@/composables'
import api from '@/api'

defineOptions({ name: '部门管理' })

const $table = ref(null)
const queryItems = ref({
  name: null,
})
const deptOption = ref([])
const tableRows = ref([])
const isDisabled = ref(false)

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
  name: '部门',
  initForm: {
    parent_id: null,
    name: '',
    desc: '',
    order: 0,
  },
  doCreate: api.createDept,
  doUpdate: api.updateDept,
  doDelete: api.deleteDept,
  refresh: () => {
    $table.value?.handleSearch()
    refreshDeptOptions()
  },
})

onMounted(async () => {
  await Promise.all([$table.value?.handleSearch(), refreshDeptOptions()])
})

const deptRules = {
  name: [
    {
      required: true,
      message: '请输入部门名称',
      trigger: ['input', 'blur', 'change'],
    },
  ],
}

const totalDeptCount = computed(() => countTreeNodes(deptOption.value))
const rootDeptCount = computed(() => deptOption.value.length)
const describedDeptCount = computed(() => tableRows.value.filter(item => item.desc).length)
const filterStatus = computed(() => queryItems.value.name || '全部')
const deptNameMap = computed(() => buildDeptNameMap(deptOption.value))

const overviewStats = computed(() => [
  {
    label: '部门总数',
    value: totalDeptCount.value,
    hint: '按组织树统计',
  },
  {
    label: '一级部门',
    value: rootDeptCount.value,
    hint: '最上层节点',
  },
  {
    label: '已写说明',
    value: describedDeptCount.value,
    hint: '便于维护',
  },
  {
    label: '筛选状态',
    value: filterStatus.value,
    hint: queryItems.value.name ? '按名称筛选' : '未筛选',
  },
])

const columns = [
  {
    title: '部门',
    key: 'name',
    width: 220,
    ellipsis: { tooltip: true },
    render(row) {
      return h('div', { class: 'dept-name-cell' }, [
        h('strong', { class: 'dept-name-cell__title' }, row.name || '--'),
        h(
          'span',
          { class: 'dept-name-cell__meta' },
          row.parent_id ? `上级：${deptNameMap.value[row.parent_id] || '未命名部门'}` : '一级部门'
        ),
      ])
    },
  },
  {
    title: '说明',
    key: 'desc',
    width: 280,
    ellipsis: { tooltip: true },
    render(row) {
      return row.desc || '--'
    },
  },
  {
    title: '排序',
    key: 'order',
    width: 100,
    render(row) {
      return h(NTag, { size: 'small', round: true, type: 'info' }, { default: () => row.order ?? 0 })
    },
  },
  {
    title: '层级',
    key: 'parent_id',
    width: 120,
    render(row) {
      return row.parent_id ? '子部门' : '一级部门'
    },
  },
  {
    title: '操作',
    key: 'actions',
    width: 180,
    fixed: 'right',
    render(row) {
      return h('div', { class: 'dept-action-list' }, [
        withDirectives(
          h(
            NButton,
            {
              size: 'small',
              quaternary: true,
              type: 'primary',
              onClick: () => openEditDept(row),
            },
            {
              default: () => '编辑',
              icon: renderIcon('material-symbols:edit', { size: 16 }),
            }
          ),
          [[vPermission, 'post/api/v1/dept/update']]
        ),
        h(
          NPopconfirm,
          {
            onPositiveClick: () => handleDelete({ dept_id: row.id }, false),
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
                [[vPermission, 'delete/api/v1/dept/delete']]
              ),
            default: () => h('div', {}, '确定删除该部门吗？'),
          }
        ),
      ])
    },
  },
]

async function refreshDeptOptions() {
  const res = await api.getDepts()
  deptOption.value = res.data ?? []
}

function handleTableDataChange(data = []) {
  tableRows.value = data
}

function openCreateDept() {
  isDisabled.value = false
  handleAdd()
  modalForm.value.parent_id = null
  modalForm.value.order = 0
}

function openEditDept(row) {
  isDisabled.value = row.parent_id === 0
  handleEdit(row)
}

function countTreeNodes(nodes = []) {
  return nodes.reduce((total, node) => total + 1 + countTreeNodes(node.children ?? []), 0)
}

function buildDeptNameMap(nodes = [], result = {}) {
  nodes.forEach((node) => {
    result[node.id] = node.name
    buildDeptNameMap(node.children ?? [], result)
  })
  return result
}
</script>

<template>
  <CommonPage show-footer>
    <template #header>
      <div class="dept-page__header">
        <div class="dept-page__header-copy">
          <p class="dept-page__eyebrow">ORGANIZATION TREE</p>
          <h2>部门管理</h2>
          <p>保留组织维护所需的关键信息，减少大段说明，让结构和操作本身更容易看懂。</p>
        </div>
        <NButton v-permission="'post/api/v1/dept/create'" type="primary" @click="openCreateDept">
          <TheIcon icon="material-symbols:add" :size="18" class="mr-5" />
          新建部门
        </NButton>
      </div>
    </template>

    <div class="dept-page">
      <section class="dept-overview">
        <div class="dept-overview__intro">
          <div>
            <p class="dept-overview__label">组织概览</p>
            <h3>部门结构和排序信息集中展示</h3>
            <p>部门层级、说明和排序被压缩为少量重点字段，查看时更直接。</p>
          </div>
          <div class="dept-overview__filters">
            <NTag round type="primary">当前筛选：{{ filterStatus }}</NTag>
          </div>
        </div>

        <div class="dept-overview__stats">
          <div v-for="item in overviewStats" :key="item.label" class="dept-stat">
            <span>{{ item.label }}</span>
            <strong>{{ item.value }}</strong>
            <small>{{ item.hint }}</small>
          </div>
        </div>
      </section>

      <section class="dept-table-panel">
        <div class="dept-table-panel__header">
          <div>
            <p class="dept-table-panel__eyebrow">部门列表</p>
            <h3>树结构维护与信息编辑</h3>
            <p>编辑和删除入口保持紧凑排列，便于管理员快速处理组织调整。</p>
          </div>
        </div>

        <CrudTable
          ref="$table"
          v-model:query-items="queryItems"
          :columns="columns"
          :get-data="api.getDepts"
          :scroll-x="920"
          @on-data-change="handleTableDataChange"
        >
          <template #queryBar>
            <QueryBarItem label="部门名" :label-width="56">
              <NInput
                v-model:value="queryItems.name"
                clearable
                type="text"
                placeholder="输入部门名称"
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
          :label-width="80"
          :model="modalForm"
          :rules="deptRules"
        >
          <NFormItem label="上级部门" path="parent_id">
            <NTreeSelect
              v-model:value="modalForm.parent_id"
              :options="deptOption"
              key-field="id"
              label-field="name"
              placeholder="请选择上级部门"
              clearable
              default-expand-all
              :disabled="isDisabled"
            />
          </NFormItem>
          <NFormItem label="部门名称" path="name">
            <NInput v-model:value="modalForm.name" clearable placeholder="请输入部门名称" />
          </NFormItem>
          <NFormItem label="部门说明" path="desc">
            <NInput
              v-model:value="modalForm.desc"
              type="textarea"
              :autosize="{ minRows: 3, maxRows: 5 }"
              clearable
              placeholder="说明部门职责或用途"
            />
          </NFormItem>
          <NFormItem label="排序" path="order">
            <NInputNumber v-model:value="modalForm.order" min="0" />
          </NFormItem>
        </NForm>
      </CrudModal>
    </div>
  </CommonPage>
</template>

<style scoped>
.dept-page {
  display: grid;
  gap: 24px;
}

.dept-page__header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 18px;
  width: 100%;
}

.dept-page__header-copy {
  max-width: 620px;
}

.dept-page__eyebrow,
.dept-overview__label,
.dept-table-panel__eyebrow {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: #6f7d58;
}

.dept-page__header-copy h2,
.dept-overview__intro h3,
.dept-table-panel__header h3 {
  margin: 0;
  color: #253125;
}

.dept-page__header-copy h2 {
  font-size: 32px;
  line-height: 1.1;
}

.dept-page__header-copy p,
.dept-overview__intro p,
.dept-table-panel__header p {
  margin: 10px 0 0;
  color: #627062;
  line-height: 1.6;
}

.dept-overview {
  padding: 24px 26px;
  border-radius: 28px;
  border: 1px solid rgba(74, 105, 71, 0.08);
  background:
    radial-gradient(circle at top right, rgba(255, 206, 125, 0.18), transparent 30%),
    linear-gradient(135deg, #f7fbf4 0%, #eef7ef 45%, #fff7eb 100%);
}

.dept-overview__intro {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 18px;
}

.dept-overview__filters {
  display: flex;
  justify-content: flex-end;
  min-width: 220px;
}

.dept-overview__stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
  margin-top: 18px;
}

.dept-stat {
  display: grid;
  gap: 6px;
  padding-top: 16px;
  border-top: 1px solid rgba(74, 105, 71, 0.08);
}

.dept-stat span {
  font-size: 12px;
  color: #788678;
}

.dept-stat strong {
  font-size: 28px;
  line-height: 1;
  color: #243226;
}

.dept-stat small {
  color: #788678;
  line-height: 1.4;
}

.dept-table-panel {
  padding: 22px;
  border-radius: 24px;
  border: 1px solid rgba(74, 105, 71, 0.08);
  background: #fff;
}

.dept-name-cell {
  display: grid;
  gap: 4px;
}

.dept-name-cell__title {
  color: #243226;
  font-size: 14px;
}

.dept-name-cell__meta {
  font-size: 12px;
  color: #788678;
}

.dept-action-list {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 4px;
}

:deep(.n-data-table-th) {
  background: #f8fbf6;
}

:deep(.n-data-table-td) {
  vertical-align: middle;
}

@media (max-width: 900px) {
  .dept-page__header,
  .dept-overview__intro {
    flex-direction: column;
    align-items: flex-start;
  }

  .dept-overview__filters {
    justify-content: flex-start;
    min-width: 0;
  }

  .dept-overview__stats {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .dept-overview,
  .dept-table-panel {
    padding: 18px;
    border-radius: 20px;
  }

  .dept-page__header-copy h2 {
    font-size: 26px;
  }

  .dept-overview__stats {
    grid-template-columns: 1fr;
  }
}
</style>
