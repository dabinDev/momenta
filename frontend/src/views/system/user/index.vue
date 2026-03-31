<script setup>
import { computed, h, onMounted, ref, resolveDirective, watch, withDirectives } from 'vue'
import {
  NButton,
  NCheckbox,
  NCheckboxGroup,
  NEmpty,
  NForm,
  NFormItem,
  NInput,
  NPopconfirm,
  NSwitch,
  NTag,
  NTree,
  NTreeSelect,
} from 'naive-ui'

import CommonPage from '@/components/page/CommonPage.vue'
import QueryBarItem from '@/components/query-bar/QueryBarItem.vue'
import CrudModal from '@/components/table/CrudModal.vue'
import CrudTable from '@/components/table/CrudTable.vue'
import TheIcon from '@/components/icon/TheIcon.vue'

import { formatDate, renderIcon } from '@/utils'
import { useCRUD } from '@/composables'
import api from '@/api'
import { useUserStore } from '@/store'

defineOptions({ name: '用户管理' })

const $table = ref(null)
const queryItems = ref({
  username: null,
  email: null,
  dept_id: null,
})
const tableRows = ref([])
const roleOption = ref([])
const deptOption = ref([])
const deptKeyword = ref('')
const selectedDeptId = ref(null)

const vPermission = resolveDirective('permission')
const userStore = useUserStore()

const {
  modalVisible,
  modalTitle,
  modalAction,
  modalLoading,
  handleSave,
  modalForm,
  modalFormRef,
  handleEdit,
  handleDelete,
  handleAdd,
} = useCRUD({
  name: '用户',
  initForm: {
    username: '',
    email: '',
    password: '',
    confirmPassword: '',
    role_ids: [],
    is_superuser: false,
    is_active: true,
    dept_id: null,
  },
  doCreate: api.createUser,
  doUpdate: api.updateUser,
  doDelete: api.deleteUser,
  refresh: () => $table.value?.handleSearch(),
})

onMounted(async () => {
  $table.value?.handleSearch()
  const [roleRes, deptRes] = await Promise.all([api.getRoleList({ page: 1, page_size: 9999 }), api.getDepts()])
  roleOption.value = roleRes.data ?? []
  deptOption.value = deptRes.data ?? []
})

watch(
  () => queryItems.value.dept_id,
  (value) => {
    selectedDeptId.value = value || null
  }
)

const deptTreeData = computed(() => filterDeptTree(deptOption.value, deptKeyword.value))
const totalDeptCount = computed(() => countDeptNodes(deptOption.value))
const visibleDeptCount = computed(() => countDeptNodes(deptTreeData.value))
const selectedDeptName = computed(() => findDeptNameById(deptOption.value, selectedDeptId.value) || '全部部门')
const activeFilters = computed(() => {
  const filters = []
  if (selectedDeptId.value) filters.push({ type: 'primary', label: `部门：${selectedDeptName.value}` })
  if (queryItems.value.username) filters.push({ type: 'success', label: `用户名：${queryItems.value.username}` })
  if (queryItems.value.email) filters.push({ type: 'warning', label: `邮箱：${queryItems.value.email}` })
  return filters
})
const overviewStats = computed(() => [
  {
    label: '当前页用户',
    value: tableRows.value.length,
    hint: '已加载记录',
  },
  {
    label: '启用账号',
    value: tableRows.value.filter(item => item.is_active).length,
    hint: '可正常登录',
  },
  {
    label: '管理员',
    value: tableRows.value.filter(item => item.is_superuser).length,
    hint: '超级用户',
  },
  {
    label: '部门范围',
    value: totalDeptCount.value,
    hint: `当前可见 ${visibleDeptCount.value}`,
  },
])

const columns = [
  {
    title: '用户',
    key: 'username',
    width: 160,
    ellipsis: { tooltip: true },
    render(row) {
      return h('div', { class: 'user-name-cell' }, [
        h('strong', { class: 'user-name-cell__title' }, row.alias || row.username || '--'),
        h('span', { class: 'user-name-cell__meta' }, row.alias ? row.username : '登录账号'),
      ])
    },
  },
  {
    title: '邮箱',
    key: 'email',
    width: 220,
    ellipsis: { tooltip: true },
  },
  {
    title: '角色',
    key: 'role',
    width: 220,
    render(row) {
      const roles = row.roles ?? []
      if (!roles.length) return h('span', { class: 'user-role-empty' }, '未分配')
      return h(
        'div',
        { class: 'user-role-tags' },
        roles.map(role =>
          h(NTag, { size: 'small', type: 'info', round: true }, { default: () => role.name })
        )
      )
    },
  },
  {
    title: '部门',
    key: 'dept.name',
    width: 140,
    ellipsis: { tooltip: true },
    render(row) {
      return row.dept?.name || '--'
    },
  },
  {
    title: '类型',
    key: 'is_superuser',
    width: 120,
    render(row) {
      return h(
        NTag,
        {
          size: 'small',
          round: true,
          type: row.is_superuser ? 'warning' : 'default',
        },
        { default: () => (row.is_superuser ? '管理员' : '普通用户') }
      )
    },
  },
  {
    title: '最近登录',
    key: 'last_login',
    width: 190,
    render(row) {
      return h(
        NButton,
        {
          size: 'small',
          text: true,
          type: 'primary',
        },
        {
          default: () => (row.last_login ? formatDate(row.last_login) : '暂无记录'),
          icon: renderIcon('mdi:update', { size: 16 }),
        }
      )
    },
  },
  {
    title: '状态',
    key: 'is_active',
    width: 110,
    render(row) {
      return h(NSwitch, {
        size: 'small',
        rubberBand: false,
        value: row.is_active,
        loading: !!row.publishing,
        checkedValue: true,
        uncheckedValue: false,
        onUpdateValue: value => handleUpdateDisable(row, value),
      })
    },
  },
  {
    title: '操作',
    key: 'actions',
    width: 240,
    fixed: 'right',
    render(row) {
      return h('div', { class: 'user-action-list' }, [
        withDirectives(
          h(
            NButton,
            {
              size: 'small',
              quaternary: true,
              type: 'primary',
              onClick: () => openEditModal(row),
            },
            {
              default: () => '编辑',
              icon: renderIcon('material-symbols:edit-outline', { size: 16 }),
            }
          ),
          [[vPermission, 'post/api/v1/user/update']]
        ),
        h(
          NPopconfirm,
          {
            onPositiveClick: () => handleDelete({ user_id: row.id }, false),
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
                [[vPermission, 'delete/api/v1/user/delete']]
              ),
            default: () => h('div', {}, '确定删除该用户吗？'),
          }
        ),
        !row.is_superuser &&
          h(
            NPopconfirm,
            {
              onPositiveClick: async () => {
                try {
                  await api.resetPassword({ user_id: row.id })
                  $message.success('密码已重置为 123456')
                  await $table.value?.handleSearch()
                } catch (error) {
                  $message.error(`重置密码失败：${error.message}`)
                }
              },
            },
            {
              trigger: () =>
                withDirectives(
                  h(
                    NButton,
                    {
                      size: 'small',
                      quaternary: true,
                      type: 'warning',
                    },
                    {
                      default: () => '重置密码',
                      icon: renderIcon('material-symbols:lock-reset', { size: 16 }),
                    }
                  ),
                  [[vPermission, 'post/api/v1/user/reset_password']]
                ),
              default: () => h('div', {}, '确定将该用户密码重置为 123456 吗？'),
            }
          ),
      ].filter(Boolean))
    },
  },
]

const validateAddUser = {
  username: [
    {
      required: true,
      message: '请输入用户名',
      trigger: ['input', 'blur'],
    },
  ],
  email: [
    {
      required: true,
      message: '请输入邮箱地址',
      trigger: ['input', 'change'],
    },
    {
      trigger: ['blur'],
      validator: (rule, value, callback) => {
        const re = /^[a-zA-Z0-9_-]+@[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)+$/
        if (!re.test(modalForm.value.email || '')) {
          callback('邮箱格式错误')
          return
        }
        callback()
      },
    },
  ],
  password: [
    {
      required: true,
      message: '请输入密码',
      trigger: ['input', 'blur', 'change'],
    },
  ],
  confirmPassword: [
    {
      required: true,
      message: '请再次输入密码',
      trigger: ['input'],
    },
    {
      trigger: ['blur'],
      validator: (rule, value, callback) => {
        if (value !== modalForm.value.password) {
          callback('两次密码输入不一致')
          return
        }
        callback()
      },
    },
  ],
  role_ids: [
    {
      type: 'array',
      required: true,
      message: '请至少选择一个角色',
      trigger: ['blur', 'change'],
    },
  ],
}

function handleTableDataChange(data = []) {
  tableRows.value = data
}

function openCreateUser() {
  handleAdd()
  modalForm.value.is_active = true
  modalForm.value.is_superuser = false
  modalForm.value.role_ids = []
  modalForm.value.dept_id = null
}

function openEditModal(row) {
  handleEdit(row)
  modalForm.value.dept_id = row.dept?.id ?? row.dept_id ?? null
  modalForm.value.role_ids = (row.roles ?? []).map(item => item.id)
  modalForm.value.is_active = row.is_active ?? true
  modalForm.value.is_superuser = row.is_superuser ?? false
  delete modalForm.value.dept
}

async function handleUpdateDisable(row, value) {
  if (!row.id) return
  if (userStore.userId === row.id && !value) {
    $message.error('当前登录用户不能被停用')
    return
  }

  const previousValue = row.is_active
  row.publishing = true
  row.is_active = value
  row.role_ids = (row.roles ?? []).map(item => item.id)
  row.dept_id = row.dept?.id ?? row.dept_id ?? null

  try {
    await api.updateUser(row)
    $message.success(row.is_active ? '已启用该用户' : '已停用该用户')
    $table.value?.handleSearch()
  } catch (error) {
    row.is_active = previousValue
  } finally {
    row.publishing = false
  }
}

function applyDeptFilter(deptId) {
  selectedDeptId.value = deptId
  queryItems.value = {
    ...queryItems.value,
    dept_id: deptId,
  }
  $table.value?.handleSearch()
}

function clearDeptFilter() {
  selectedDeptId.value = null
  queryItems.value = {
    ...queryItems.value,
    dept_id: null,
  }
  $table.value?.handleSearch()
}

function handleDeptNodeClick(option) {
  if (!option?.id) return
  if (selectedDeptId.value === option.id) {
    clearDeptFilter()
    return
  }
  applyDeptFilter(option.id)
}

function nodeProps({ option }) {
  return {
    onClick() {
      handleDeptNodeClick(option)
    },
  }
}

function filterDeptTree(nodes = [], keyword = '') {
  const normalizedKeyword = keyword.trim()
  if (!normalizedKeyword) return nodes

  return nodes.reduce((result, node) => {
    const children = filterDeptTree(node.children ?? [], normalizedKeyword)
    if ((node.name || '').includes(normalizedKeyword) || children.length) {
      result.push({
        ...node,
        children,
      })
    }
    return result
  }, [])
}

function countDeptNodes(nodes = []) {
  return nodes.reduce((total, node) => total + 1 + countDeptNodes(node.children ?? []), 0)
}

function findDeptNameById(nodes = [], targetId) {
  if (!targetId) return ''
  for (const node of nodes) {
    if (node.id === targetId) return node.name || ''
    const childResult = findDeptNameById(node.children ?? [], targetId)
    if (childResult) return childResult
  }
  return ''
}
</script>

<template>
  <CommonPage show-footer>
    <template #header>
      <div class="user-page__header">
        <div class="user-page__header-copy">
          <p class="user-page__eyebrow">SYSTEM USERS</p>
          <h2>用户管理</h2>
          <p>按部门、用户名和邮箱快速筛选，常用操作保持在同一工作区内完成。</p>
        </div>
        <div class="user-page__header-actions">
          <div class="user-page__scope">
            <span>当前范围</span>
            <strong>{{ selectedDeptName }}</strong>
          </div>
          <NButton v-permission="'post/api/v1/user/create'" type="primary" @click="openCreateUser">
            <TheIcon icon="material-symbols:add" :size="18" class="mr-5" />
            新建用户
          </NButton>
        </div>
      </div>
    </template>

    <div class="user-page">
      <section class="user-overview">
        <div class="user-overview__intro">
          <div>
            <p class="user-overview__label">工作区概览</p>
            <h3>当前视图以 {{ selectedDeptName }} 为主</h3>
            <p>顶部信息保持简短，只保留筛选范围和关键数量，减少管理干扰。</p>
          </div>
          <div class="user-overview__filters">
            <NTag v-for="item in activeFilters" :key="item.label" round :type="item.type">
              {{ item.label }}
            </NTag>
            <NButton v-if="selectedDeptId" text type="primary" @click="clearDeptFilter">清除部门筛选</NButton>
          </div>
        </div>

        <div class="user-overview__stats">
          <div v-for="item in overviewStats" :key="item.label" class="user-stat">
            <span>{{ item.label }}</span>
            <strong>{{ item.value }}</strong>
            <small>{{ item.hint }}</small>
          </div>
        </div>
      </section>

      <div class="user-workspace">
        <aside class="dept-panel">
          <div class="dept-panel__header">
            <div>
              <p class="dept-panel__eyebrow">部门筛选</p>
              <h3>组织结构</h3>
            </div>
            <NButton v-if="selectedDeptId" text type="primary" @click="clearDeptFilter">重置</NButton>
          </div>

          <NInput
            v-model:value="deptKeyword"
            clearable
            placeholder="搜索部门"
          />

          <div class="dept-panel__summary">
            <span>当前查看</span>
            <strong>{{ selectedDeptName }}</strong>
            <small>共 {{ visibleDeptCount }} 个可见部门</small>
          </div>

          <div class="dept-panel__tree">
            <NTree
              v-if="deptTreeData.length"
              block-line
              :data="deptTreeData"
              key-field="id"
              label-field="name"
              :selected-keys="selectedDeptId ? [selectedDeptId] : []"
              default-expand-all
              :node-props="nodeProps"
            />
            <NEmpty v-else description="没有匹配的部门" size="small" />
          </div>
        </aside>

        <section class="user-table-panel">
          <div class="user-table-panel__header">
            <div>
              <p class="user-table-panel__eyebrow">用户列表</p>
              <h3>账户状态与权限配置</h3>
              <p>启用、停用、编辑和密码重置都保留在表格内，减少页面跳转。</p>
            </div>
          </div>

          <CrudTable
            ref="$table"
            v-model:query-items="queryItems"
            :columns="columns"
            :get-data="api.getUserList"
            :scroll-x="1280"
            @on-data-change="handleTableDataChange"
          >
            <template #queryBar>
              <QueryBarItem label="用户名" :label-width="56">
                <NInput
                  v-model:value="queryItems.username"
                  clearable
                  type="text"
                  placeholder="输入用户名"
                  @keypress.enter="$table?.handleSearch()"
                />
              </QueryBarItem>
              <QueryBarItem label="邮箱" :label-width="44">
                <NInput
                  v-model:value="queryItems.email"
                  clearable
                  type="text"
                  placeholder="输入邮箱"
                  @keypress.enter="$table?.handleSearch()"
                />
              </QueryBarItem>
            </template>
          </CrudTable>
        </section>
      </div>

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
          :rules="validateAddUser"
        >
          <NFormItem label="用户名" path="username">
            <NInput v-model:value="modalForm.username" clearable placeholder="请输入用户名" />
          </NFormItem>
          <NFormItem label="邮箱" path="email">
            <NInput v-model:value="modalForm.email" clearable placeholder="请输入邮箱地址" />
          </NFormItem>
          <NFormItem v-if="modalAction === 'add'" label="密码" path="password">
            <NInput
              v-model:value="modalForm.password"
              show-password-on="mousedown"
              type="password"
              clearable
              placeholder="请输入密码"
            />
          </NFormItem>
          <NFormItem v-if="modalAction === 'add'" label="确认密码" path="confirmPassword">
            <NInput
              v-model:value="modalForm.confirmPassword"
              show-password-on="mousedown"
              type="password"
              clearable
              placeholder="请再次输入密码"
            />
          </NFormItem>
          <NFormItem label="角色" path="role_ids">
            <NCheckboxGroup v-model:value="modalForm.role_ids">
              <div class="modal-role-grid">
                <NCheckbox
                  v-for="item in roleOption"
                  :key="item.id"
                  :value="item.id"
                  :label="item.name"
                />
              </div>
            </NCheckboxGroup>
          </NFormItem>
          <NFormItem label="管理员" path="is_superuser">
            <NSwitch
              v-model:value="modalForm.is_superuser"
              size="small"
              :checked-value="true"
              :unchecked-value="false"
            />
          </NFormItem>
          <NFormItem label="启用" path="is_active">
            <NSwitch
              v-model:value="modalForm.is_active"
              :checked-value="true"
              :unchecked-value="false"
            />
          </NFormItem>
          <NFormItem label="部门" path="dept_id">
            <NTreeSelect
              v-model:value="modalForm.dept_id"
              :options="deptOption"
              key-field="id"
              label-field="name"
              placeholder="请选择部门"
              clearable
              default-expand-all
            />
          </NFormItem>
        </NForm>
      </CrudModal>
    </div>
  </CommonPage>
</template>

<style scoped>
.user-page {
  display: grid;
  gap: 24px;
}

.user-page__header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 20px;
  width: 100%;
}

.user-page__header-copy {
  max-width: 620px;
}

.user-page__eyebrow,
.user-overview__label,
.dept-panel__eyebrow,
.user-table-panel__eyebrow {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  color: #7d7465;
  text-transform: uppercase;
}

.user-page__header-copy h2,
.user-overview__intro h3,
.dept-panel__header h3,
.user-table-panel__header h3 {
  margin: 0;
  color: #1f2f2b;
}

.user-page__header-copy h2 {
  font-size: 32px;
  line-height: 1.1;
}

.user-page__header-copy p,
.user-overview__intro p,
.user-table-panel__header p {
  margin: 10px 0 0;
  color: #5d675f;
  line-height: 1.6;
}

.user-page__header-actions {
  display: flex;
  align-items: center;
  gap: 14px;
}

.user-page__scope {
  display: grid;
  gap: 4px;
  min-width: 150px;
  padding: 10px 14px;
  border-radius: 18px;
  background: linear-gradient(135deg, rgba(255, 243, 220, 0.92), rgba(237, 248, 244, 0.92));
  color: #42514c;
}

.user-page__scope span,
.user-stat span,
.dept-panel__summary span {
  font-size: 12px;
  color: #7a857c;
}

.user-page__scope strong,
.dept-panel__summary strong {
  font-size: 15px;
  font-weight: 700;
  color: #1f2f2b;
}

.user-overview {
  padding: 24px 26px;
  border-radius: 28px;
  background:
    radial-gradient(circle at top right, rgba(230, 157, 72, 0.18), transparent 30%),
    linear-gradient(135deg, #f7fbf8 0%, #eef7f1 46%, #fff7ec 100%);
  border: 1px solid rgba(53, 86, 72, 0.08);
}

.user-overview__intro {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 18px;
}

.user-overview__filters {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: flex-end;
  gap: 10px;
  min-width: 220px;
}

.user-overview__stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
  margin-top: 18px;
}

.user-stat {
  display: grid;
  gap: 6px;
  padding: 16px 0 10px;
  border-top: 1px solid rgba(53, 86, 72, 0.08);
}

.user-stat strong {
  font-size: 28px;
  line-height: 1;
  color: #173028;
}

.user-stat small,
.dept-panel__summary small {
  color: #7a857c;
  line-height: 1.4;
}

.user-workspace {
  display: grid;
  grid-template-columns: 280px minmax(0, 1fr);
  gap: 22px;
}

.dept-panel,
.user-table-panel {
  min-width: 0;
  padding: 22px;
  border-radius: 24px;
  border: 1px solid rgba(53, 86, 72, 0.08);
  background: #fff;
}

.dept-panel {
  display: grid;
  align-content: start;
  gap: 16px;
  background: linear-gradient(180deg, #fbfdfb 0%, #ffffff 100%);
}

.dept-panel__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.dept-panel__summary {
  display: grid;
  gap: 4px;
  padding: 14px 16px;
  border-radius: 18px;
  background: #f5f8f6;
}

.dept-panel__tree {
  min-height: 320px;
}

.user-table-panel {
  display: grid;
  gap: 18px;
}

.user-table-panel__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.user-name-cell {
  display: grid;
  gap: 4px;
}

.user-name-cell__title {
  color: #1c2a26;
  font-size: 14px;
}

.user-name-cell__meta,
.user-role-empty {
  font-size: 12px;
  color: #7a857c;
}

.user-role-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.user-action-list {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 4px;
}

.modal-role-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px 12px;
  width: 100%;
}

:deep(.n-tree-node-content) {
  min-height: 34px;
  border-radius: 10px;
}

:deep(.n-tree-node--selected > .n-tree-node-content) {
  background: rgba(35, 111, 84, 0.12);
}

:deep(.n-data-table-th) {
  background: #f8fbf8;
}

:deep(.n-data-table-td) {
  vertical-align: middle;
}

@media (max-width: 1100px) {
  .user-workspace {
    grid-template-columns: 1fr;
  }

  .dept-panel__tree {
    min-height: auto;
  }
}

@media (max-width: 900px) {
  .user-page__header,
  .user-overview__intro {
    flex-direction: column;
    align-items: flex-start;
  }

  .user-page__header-actions,
  .user-overview__filters {
    width: 100%;
    justify-content: flex-start;
  }

  .user-overview__stats {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .user-overview,
  .dept-panel,
  .user-table-panel {
    padding: 18px;
    border-radius: 20px;
  }

  .user-page__header-copy h2 {
    font-size: 26px;
  }

  .user-overview__stats,
  .modal-role-grid {
    grid-template-columns: 1fr;
  }

  .user-page__header-actions {
    flex-direction: column;
    align-items: stretch;
  }
}
</style>
