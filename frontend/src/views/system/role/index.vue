<script setup>
import { computed, h, onMounted, ref, resolveDirective, withDirectives } from 'vue'
import {
  NButton,
  NDrawer,
  NDrawerContent,
  NEmpty,
  NForm,
  NFormItem,
  NInput,
  NPopconfirm,
  NSpin,
  NTabPane,
  NTabs,
  NTag,
  NTree,
} from 'naive-ui'

import CommonPage from '@/components/page/CommonPage.vue'
import QueryBarItem from '@/components/query-bar/QueryBarItem.vue'
import CrudModal from '@/components/table/CrudModal.vue'
import CrudTable from '@/components/table/CrudTable.vue'

import { formatDate, renderIcon } from '@/utils'
import { useCRUD } from '@/composables'
import api from '@/api'
import TheIcon from '@/components/icon/TheIcon.vue'

defineOptions({ name: '角色管理' })

const $table = ref(null)
const queryItems = ref({
  role_name: null,
})
const tableRows = ref([])
const pattern = ref('')
const menuOption = ref([])
const apiOption = ref([])
const menu_ids = ref([])
const api_ids = ref([])
const apiTree = ref(null)
const active = ref(false)
const activeTab = ref('menu')
const drawerLoading = ref(false)
const roleId = ref(0)
const selectedRoleName = ref('')

const vPermission = resolveDirective('permission')

const {
  modalVisible,
  modalAction,
  modalTitle,
  modalLoading,
  handleAdd,
  handleDelete,
  handleEdit,
  handleSave,
  modalForm,
  modalFormRef,
} = useCRUD({
  name: '角色',
  initForm: {
    name: '',
    desc: '',
  },
  doCreate: api.createRole,
  doDelete: api.deleteRole,
  doUpdate: api.updateRole,
  refresh: () => $table.value?.handleSearch(),
})

onMounted(() => {
  $table.value?.handleSearch()
})

const activeFilters = computed(() => {
  const filters = []
  if (queryItems.value.role_name) filters.push({ type: 'primary', label: `角色名：${queryItems.value.role_name}` })
  if (selectedRoleName.value) filters.push({ type: 'warning', label: `授权中：${selectedRoleName.value}` })
  return filters
})

const overviewStats = computed(() => [
  {
    label: '当前页角色',
    value: tableRows.value.length,
    hint: '已加载记录',
  },
  {
    label: '已写描述',
    value: tableRows.value.filter(item => item.desc).length,
    hint: '便于管理识别',
  },
  {
    label: '筛选状态',
    value: queryItems.value.role_name ? '已筛选' : '全部',
    hint: queryItems.value.role_name || '未限制',
  },
  {
    label: '授权目标',
    value: selectedRoleName.value || '未选择',
    hint: active.value ? '抽屉已打开' : '待选择角色',
  },
])

const authStats = computed(() => [
  {
    label: '菜单节点',
    value: countTreeNodes(menuOption.value),
  },
  {
    label: '接口节点',
    value: countTreeLeaves(apiOption.value),
  },
  {
    label: '已选菜单',
    value: menu_ids.value.length,
  },
  {
    label: '已选接口',
    value: api_ids.value.length,
  },
])

const columns = [
  {
    title: '角色',
    key: 'name',
    width: 220,
    ellipsis: { tooltip: true },
    render(row) {
      return h('div', { class: 'role-name-cell' }, [
        h(NTag, { type: 'info', round: true, size: 'small' }, { default: () => row.name }),
        h('span', { class: 'role-name-cell__meta' }, row.desc || '未填写角色说明'),
      ])
    },
  },
  {
    title: '说明',
    key: 'desc',
    width: 300,
    ellipsis: { tooltip: true },
    render(row) {
      return row.desc || '--'
    },
  },
  {
    title: '创建时间',
    key: 'created_at',
    width: 180,
    render(row) {
      return formatDate(row.created_at)
    },
  },
  {
    title: '操作',
    key: 'actions',
    width: 250,
    fixed: 'right',
    render(row) {
      return h('div', { class: 'role-action-list' }, [
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
              icon: renderIcon('material-symbols:edit-outline', { size: 16 }),
            }
          ),
          [[vPermission, 'post/api/v1/role/update']]
        ),
        h(
          NPopconfirm,
          {
            onPositiveClick: () => handleDelete({ role_id: row.id }, false),
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
                [[vPermission, 'delete/api/v1/role/delete']]
              ),
            default: () => h('div', {}, '确定删除该角色吗？'),
          }
        ),
        withDirectives(
          h(
            NButton,
            {
              size: 'small',
              quaternary: true,
              type: 'warning',
              onClick: () => openAuthorizeDrawer(row),
            },
            {
              default: () => '设置权限',
              icon: renderIcon('material-symbols:key-vertical-outline', { size: 16 }),
            }
          ),
          [[vPermission, 'get/api/v1/role/authorized']]
        ),
      ])
    },
  },
]

function handleTableDataChange(data = []) {
  tableRows.value = data
}

function buildApiTree(data = []) {
  const processedData = []
  const groupedData = {}

  data.forEach((item) => {
    const tags = item.tags || 'api'
    const pathParts = (item.path || '').split('/')
    const path = pathParts.slice(0, -1).join('/') || '/'
    const summary = tags.charAt(0).toUpperCase() + tags.slice(1)
    const unique_id = `${String(item.method || '').toLowerCase()}${item.path}`
    if (!(path in groupedData)) {
      groupedData[path] = { unique_id: path, path, summary, children: [] }
    }

    groupedData[path].children.push({
      id: item.id,
      path: item.path,
      method: item.method,
      summary: item.summary,
      unique_id,
    })
  })

  processedData.push(...Object.values(groupedData))
  return processedData
}

async function openAuthorizeDrawer(row) {
  selectedRoleName.value = row.name || ''
  roleId.value = row.id
  pattern.value = ''
  activeTab.value = 'menu'
  active.value = true
  drawerLoading.value = true

  try {
    const [menusResponse, apisResponse, roleAuthorizedResponse] = await Promise.all([
      api.getMenus({ page: 1, page_size: 9999 }),
      api.getApis({ page: 1, page_size: 9999 }),
      api.getRoleAuthorized({ id: row.id }),
    ])

    menuOption.value = menusResponse.data ?? []
    apiOption.value = buildApiTree(apisResponse.data ?? [])
    menu_ids.value = (roleAuthorizedResponse.data?.menus ?? []).map(item => item.id)
    api_ids.value = (roleAuthorizedResponse.data?.apis ?? []).map(
      item => `${String(item.method).toLowerCase()}${item.path}`
    )
  } catch (error) {
    $message.error(`加载权限数据失败：${error.message}`)
    active.value = false
  } finally {
    drawerLoading.value = false
  }
}

async function updateRoleAuthorized() {
  const checkData = apiTree.value?.getCheckedData?.()
  const apiInfos = []

  checkData?.options?.forEach((item) => {
    if (!item.children) {
      apiInfos.push({
        path: item.path,
        method: item.method,
      })
    }
  })

  const { code, msg } = await api.updateRoleAuthorized({
    id: roleId.value,
    menu_ids: menu_ids.value,
    api_infos: apiInfos,
  })

  if (code === 200) {
    $message.success('权限已更新')
  } else {
    $message.error(msg)
  }

  const result = await api.getRoleAuthorized({ id: roleId.value })
  menu_ids.value = (result.data?.menus ?? []).map(item => item.id)
  api_ids.value = (result.data?.apis ?? []).map(
    item => `${String(item.method).toLowerCase()}${item.path}`
  )
}

function handleMenuCheck(value) {
  menu_ids.value = value
}

function handleApiCheck(value) {
  api_ids.value = value
}

function countTreeNodes(nodes = []) {
  return nodes.reduce((total, node) => total + 1 + countTreeNodes(node.children ?? []), 0)
}

function countTreeLeaves(nodes = []) {
  return nodes.reduce((total, node) => {
    if (!node.children?.length) return total + 1
    return total + countTreeLeaves(node.children)
  }, 0)
}
</script>

<template>
  <CommonPage show-footer>
    <template #header>
      <div class="role-page__header">
        <div class="role-page__header-copy">
          <p class="role-page__eyebrow">SYSTEM ROLES</p>
          <h2>角色管理</h2>
          <p>角色列表、说明维护和权限分配保持在同一条工作流里，减少来回切换。</p>
        </div>
        <NButton v-permission="'post/api/v1/role/create'" type="primary" @click="handleAdd">
          <TheIcon icon="material-symbols:add" :size="18" class="mr-5" />
          新建角色
        </NButton>
      </div>
    </template>

    <div class="role-page">
      <section class="role-overview">
        <div class="role-overview__intro">
          <div>
            <p class="role-overview__label">权限工作区</p>
            <h3>为每个角色保留清晰的权限边界</h3>
            <p>页面信息压缩为少量关键信号，方便快速查看当前筛选、角色数量和授权目标。</p>
          </div>
          <div class="role-overview__filters">
            <NTag v-for="item in activeFilters" :key="item.label" round :type="item.type">
              {{ item.label }}
            </NTag>
          </div>
        </div>

        <div class="role-overview__stats">
          <div v-for="item in overviewStats" :key="item.label" class="role-stat">
            <span>{{ item.label }}</span>
            <strong>{{ item.value }}</strong>
            <small>{{ item.hint }}</small>
          </div>
        </div>
      </section>

      <section class="role-table-panel">
        <div class="role-table-panel__header">
          <div>
            <p class="role-table-panel__eyebrow">角色列表</p>
            <h3>名称、说明和权限入口</h3>
            <p>常用动作都收进表格右侧，适合后台管理的连续操作。</p>
          </div>
        </div>

        <CrudTable
          ref="$table"
          v-model:query-items="queryItems"
          :columns="columns"
          :get-data="api.getRoleList"
          :scroll-x="980"
          @on-data-change="handleTableDataChange"
        >
          <template #queryBar>
            <QueryBarItem label="角色名" :label-width="56">
              <NInput
                v-model:value="queryItems.role_name"
                clearable
                type="text"
                placeholder="输入角色名称"
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
          :disabled="modalAction === 'view'"
        >
          <NFormItem
            label="角色名"
            path="name"
            :rule="{
              required: true,
              message: '请输入角色名称',
              trigger: ['input', 'blur'],
            }"
          >
            <NInput v-model:value="modalForm.name" placeholder="请输入角色名称" />
          </NFormItem>
          <NFormItem label="角色说明" path="desc">
            <NInput
              v-model:value="modalForm.desc"
              type="textarea"
              :autosize="{ minRows: 3, maxRows: 5 }"
              placeholder="说明该角色负责的权限范围"
            />
          </NFormItem>
        </NForm>
      </CrudModal>

      <NDrawer v-model:show="active" placement="right" :width="620">
        <NDrawerContent closable body-content-class="role-drawer__body">
          <template #header>
            <div class="role-drawer__header">
              <p class="role-drawer__eyebrow">Permission Editor</p>
              <h3>{{ selectedRoleName || '设置权限' }}</h3>
              <p>用最少的说明和最清晰的树结构来维护菜单与接口权限。</p>
            </div>
          </template>

          <div class="role-drawer">
            <div class="role-drawer__toolbar">
              <div class="role-drawer__stats">
                <div v-for="item in authStats" :key="item.label" class="role-drawer__stat">
                  <span>{{ item.label }}</span>
                  <strong>{{ item.value }}</strong>
                </div>
              </div>

              <div class="role-drawer__actions">
                <NInput
                  v-model:value="pattern"
                  clearable
                  placeholder="搜索权限节点"
                />
                <NButton
                  v-permission="'post/api/v1/role/authorized'"
                  type="primary"
                  :loading="drawerLoading"
                  @click="updateRoleAuthorized"
                >
                  保存权限
                </NButton>
              </div>
            </div>

            <NSpin :show="drawerLoading">
              <NTabs v-model:value="activeTab" type="segment" animated>
                <NTabPane name="menu" tab="菜单权限">
                  <div class="role-tree-panel">
                    <NTree
                      v-if="menuOption.length"
                      :data="menuOption"
                      :checked-keys="menu_ids"
                      :pattern="pattern"
                      :show-irrelevant-nodes="false"
                      key-field="id"
                      label-field="name"
                      checkable
                      :default-expand-all="true"
                      :block-line="true"
                      :selectable="false"
                      @update:checked-keys="handleMenuCheck"
                    />
                    <NEmpty v-else description="没有可分配的菜单节点" />
                  </div>
                </NTabPane>
                <NTabPane name="resource" tab="接口权限">
                  <div class="role-tree-panel">
                    <NTree
                      v-if="apiOption.length"
                      ref="apiTree"
                      :data="apiOption"
                      :checked-keys="api_ids"
                      :pattern="pattern"
                      :show-irrelevant-nodes="false"
                      key-field="unique_id"
                      label-field="summary"
                      checkable
                      :default-expand-all="true"
                      :block-line="true"
                      :selectable="false"
                      cascade
                      @update:checked-keys="handleApiCheck"
                    />
                    <NEmpty v-else description="没有可分配的接口节点" />
                  </div>
                </NTabPane>
              </NTabs>
            </NSpin>
          </div>
        </NDrawerContent>
      </NDrawer>
    </div>
  </CommonPage>
</template>

<style scoped>
.role-page {
  display: grid;
  gap: 24px;
}

.role-page__header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 18px;
  width: 100%;
}

.role-page__header-copy {
  max-width: 620px;
}

.role-page__eyebrow,
.role-overview__label,
.role-table-panel__eyebrow,
.role-drawer__eyebrow {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: #846b59;
}

.role-page__header-copy h2,
.role-overview__intro h3,
.role-table-panel__header h3,
.role-drawer__header h3 {
  margin: 0;
  color: #2d2f3a;
}

.role-page__header-copy h2 {
  font-size: 32px;
  line-height: 1.1;
}

.role-page__header-copy p,
.role-overview__intro p,
.role-table-panel__header p,
.role-drawer__header p {
  margin: 10px 0 0;
  color: #636a72;
  line-height: 1.6;
}

.role-overview {
  padding: 24px 26px;
  border-radius: 28px;
  border: 1px solid rgba(97, 88, 117, 0.08);
  background:
    radial-gradient(circle at top right, rgba(255, 188, 125, 0.2), transparent 30%),
    linear-gradient(135deg, #f8f9ff 0%, #f5f8fc 44%, #fff5ec 100%);
}

.role-overview__intro {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 18px;
}

.role-overview__filters {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 10px;
  min-width: 220px;
}

.role-overview__stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
  margin-top: 18px;
}

.role-stat {
  display: grid;
  gap: 6px;
  padding-top: 16px;
  border-top: 1px solid rgba(97, 88, 117, 0.08);
}

.role-stat span,
.role-drawer__stat span {
  font-size: 12px;
  color: #7d8492;
}

.role-stat strong {
  font-size: 28px;
  line-height: 1;
  color: #2a3141;
}

.role-stat small {
  color: #7d8492;
  line-height: 1.4;
}

.role-table-panel {
  padding: 22px;
  border-radius: 24px;
  border: 1px solid rgba(97, 88, 117, 0.08);
  background: #fff;
}

.role-name-cell {
  display: grid;
  gap: 8px;
}

.role-name-cell__meta {
  font-size: 12px;
  color: #7d8492;
}

.role-action-list {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 4px;
}

.role-drawer {
  display: grid;
  gap: 18px;
}

.role-drawer__toolbar {
  display: grid;
  gap: 16px;
}

.role-drawer__stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
}

.role-drawer__stat {
  display: grid;
  gap: 4px;
  padding: 12px 14px;
  border-radius: 16px;
  background: #f6f7fb;
}

.role-drawer__stat strong {
  font-size: 20px;
  color: #2d2f3a;
}

.role-drawer__actions {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 12px;
}

.role-tree-panel {
  min-height: 420px;
  padding: 8px 2px 4px;
}

:deep(.n-data-table-th) {
  background: #fafbfe;
}

:deep(.n-data-table-td) {
  vertical-align: middle;
}

:deep(.n-tree-node-content) {
  min-height: 36px;
  border-radius: 10px;
}

:deep(.role-drawer__body) {
  padding-top: 8px;
}

@media (max-width: 900px) {
  .role-page__header,
  .role-overview__intro {
    flex-direction: column;
    align-items: flex-start;
  }

  .role-overview__filters {
    justify-content: flex-start;
    min-width: 0;
  }

  .role-overview__stats,
  .role-drawer__stats {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .role-overview,
  .role-table-panel {
    padding: 18px;
    border-radius: 20px;
  }

  .role-page__header-copy h2 {
    font-size: 26px;
  }

  .role-overview__stats,
  .role-drawer__stats,
  .role-drawer__actions {
    grid-template-columns: 1fr;
  }
}
</style>
