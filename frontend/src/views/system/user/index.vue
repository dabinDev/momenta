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
const metricsLoading = ref(false)
const userMetrics = ref({
  summary: {
    users: 0,
    video_count: 0,
    completed_count: 0,
    failed_count: 0,
    voice_count: 0,
    total_duration: 0,
  },
  ranking: [],
})

const vPermission = resolveDirective('permission')
const userStore = useUserStore()

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
  modalAction,
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

const metricsByUserId = computed(() => {
  const map = new Map()
  for (const item of userMetrics.value.ranking || []) {
    map.set(item.user_id, item)
  }
  return map
})

const deptTreeData = computed(() => filterDeptTree(deptOption.value, deptKeyword.value))
const visibleDeptCount = computed(() => countDeptNodes(deptTreeData.value))
const selectedDeptName = computed(() => findDeptNameById(deptOption.value, selectedDeptId.value) || '全部部门')
const activeFilters = computed(() => {
  const filters = []
  if (selectedDeptId.value) filters.push({ type: 'primary', label: `部门：${selectedDeptName.value}` })
  if (queryItems.value.username) filters.push({ type: 'success', label: `用户：${queryItems.value.username}` })
  if (queryItems.value.email) filters.push({ type: 'warning', label: `邮箱：${queryItems.value.email}` })
  return filters
})

const overviewStats = computed(() => [
  {
    label: '当前页用户',
    value: tableRows.value.length,
    hint: '本次查询已加载账号',
  },
  {
    label: '启用账号',
    value: tableRows.value.filter((item) => item.is_active).length,
    hint: '允许登录和调用服务',
  },
  {
    label: '已封禁账号',
    value: tableRows.value.filter((item) => !item.is_active).length,
    hint: '不可继续登录',
  },
  {
    label: '受邀注册',
    value: tableRows.value.filter((item) => item.registration_source === 'invite').length,
    hint: '邀请码注册用户',
  },
])

const userMetricCards = computed(() => [
  {
    label: '用户总数',
    value: userMetrics.value.summary.users || 0,
    hint: '当前筛选范围参与统计的用户',
  },
  {
    label: '视频生成',
    value: userMetrics.value.summary.video_count || 0,
    hint: '累计生成任务数',
  },
  {
    label: '成功完成',
    value: userMetrics.value.summary.completed_count || 0,
    hint: '状态为 completed 的任务',
  },
  {
    label: '语音调用',
    value: userMetrics.value.summary.voice_count || 0,
    hint: '语音识别调用次数',
  },
])

const metricRanking = computed(() => {
  const rows = userMetrics.value.ranking || []
  const maxVideoCount = Math.max(...rows.map((item) => Number(item.video_count || 0)), 1)
  return rows.slice(0, 8).map((item) => ({
    ...item,
    videoPercent: Math.max(10, Math.round((Number(item.video_count || 0) / maxVideoCount) * 100)),
  }))
})

function isSuspiciousAlias(alias) {
  const value = String(alias || '').trim()
  if (!value) return true
  if (/u[0-9A-Fa-f]{4}/.test(value)) return true
  if (/\?{2,}/.test(value)) return true
  if (/^(App|H5|Web)?\?+$/i.test(value)) return true
  return false
}

function readDisplayName(row) {
  const alias = String(row?.alias || '').trim()
  if (isSuspiciousAlias(alias)) {
    return String(row?.username || '--')
  }
  return alias
}

function readSecondaryName(row) {
  const username = String(row?.username || '').trim()
  const alias = String(row?.alias || '').trim()
  if (!username) return '登录账号'
  if (isSuspiciousAlias(alias) || alias === username) {
    return '登录账号'
  }
  return `@${username}`
}

const columns = [
  {
    title: '用户',
    key: 'username',
    width: 180,
    ellipsis: { tooltip: true },
    render(row) {
      return h('div', { class: 'user-name-cell' }, [
        h('strong', { class: 'user-name-cell__title' }, readDisplayName(row)),
        h('span', { class: 'user-name-cell__meta' }, readSecondaryName(row)),
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
    title: '来源',
    key: 'registration_source',
    width: 120,
    render(row) {
      const fromInvite = row.registration_source === 'invite'
      return h(
        NTag,
        {
          size: 'small',
          round: true,
          type: fromInvite ? 'success' : 'default',
        },
        { default: () => (fromInvite ? '邀请码注册' : '后台创建') }
      )
    },
  },
  {
    title: '邀请码',
    key: 'invite_code',
    width: 140,
    render(row) {
      return row.invite_code?.code || '--'
    },
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
        roles.map((role) => h(NTag, { size: 'small', type: 'info', round: true }, { default: () => role.name }))
      )
    },
  },
  {
    title: '权限',
    key: 'permission_scope',
    width: 120,
    render(row) {
      return h(
        NTag,
        {
          size: 'small',
          round: true,
          type: row.is_superuser ? 'warning' : 'default',
        },
        { default: () => (row.is_superuser ? '超级管理' : '角色权限') }
      )
    },
  },
  {
    title: '数据用量',
    key: 'metric_usage',
    width: 220,
    render(row) {
      const metric = metricsByUserId.value.get(row.id)
      if (!metric) {
        return h('span', { class: 'user-usage-empty' }, '暂无数据')
      }
      return h('div', { class: 'user-usage-cell' }, [
        h('strong', null, `视频 ${metric.video_count || 0}`),
        h('span', null, `成功 ${metric.completed_count || 0} / 失败 ${metric.failed_count || 0}`),
        h('span', null, `语音 ${metric.voice_count || 0}`),
      ])
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
    title: '最近登录',
    key: 'last_login',
    width: 180,
    render(row) {
      return row.last_login ? formatDate(row.last_login) : '暂无记录'
    },
  },
  {
    title: '状态',
    key: 'is_active',
    width: 120,
    render(row) {
      return h(
        NTag,
        {
          size: 'small',
          round: true,
          type: row.is_active ? 'success' : 'error',
        },
        { default: () => (row.is_active ? '启用中' : '已封禁') }
      )
    },
  },
  {
    title: '操作',
    key: 'actions',
    width: 360,
    fixed: 'right',
    render(row) {
      return h('div', { class: 'user-action-list' }, [
        withDirectives(
          h(
            NButton,
            {
              size: 'small',
              quaternary: true,
              type: row.is_active ? 'warning' : 'success',
              loading: !!row.publishing,
              onClick: () => handleToggleStatus(row, !row.is_active),
            },
            {
              default: () => (row.is_active ? '封禁' : '启用'),
              icon: renderIcon(
                row.is_active ? 'material-symbols:block' : 'material-symbols:check-circle-outline',
                { size: 16 }
              ),
            }
          ),
          [[vPermission, 'post/api/v1/user/update']]
        ),
        withDirectives(
          h(
            NButton,
            {
              size: 'small',
              quaternary: true,
              type: 'info',
              onClick: () => openRoleModal(row),
            },
            {
              default: () => '角色权限',
              icon: renderIcon('material-symbols:shield-person-outline', { size: 16 }),
            }
          ),
          [[vPermission, 'post/api/v1/user/update']]
        ),
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
            default: () => h('div', {}, '确定删除这个用户吗？'),
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
                  $message.error(error?.message || '重置密码失败')
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
  username: [{ required: true, message: '请输入用户名', trigger: ['input', 'blur'] }],
  email: [
    { required: true, message: '请输入邮箱地址', trigger: ['input', 'change'] },
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
  password: [{ required: true, message: '请输入密码', trigger: ['input', 'blur', 'change'] }],
  confirmPassword: [
    { required: true, message: '请再次输入密码', trigger: ['input'] },
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
  role_ids: [{ type: 'array', required: true, message: '请至少选择一个角色', trigger: ['blur', 'change'] }],
}

onMounted(async () => {
  $table.value?.handleSearch()
  const [roleRes, deptRes] = await Promise.all([api.getRoleList({ page: 1, page_size: 9999 }), api.getDepts()])
  roleOption.value = roleRes.data ?? []
  deptOption.value = deptRes.data ?? []
  await loadUserMetrics()
})

watch(
  () => queryItems.value.dept_id,
  (value) => {
    selectedDeptId.value = value || null
  }
)

function handleTableDataChange(data = []) {
  tableRows.value = data
  loadUserMetrics()
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
  modalForm.value.role_ids = (row.roles ?? []).map((item) => item.id)
  modalForm.value.is_active = row.is_active ?? true
  modalForm.value.is_superuser = row.is_superuser ?? false
  delete modalForm.value.dept
  delete modalForm.value.invite_code
}

function openRoleModal(row) {
  openEditModal(row)
}

async function handleToggleStatus(row, value) {
  if (!row.id) return
  if (userStore.userId === row.id && !value) {
    $message.error('当前登录用户不能封禁自己')
    return
  }

  const payload = {
    ...row,
    is_active: value,
    role_ids: (row.roles ?? []).map((item) => item.id),
    dept_id: row.dept?.id ?? row.dept_id ?? null,
  }
  delete payload.roles
  delete payload.dept
  delete payload.invite_code
  delete payload.publishing

  row.publishing = true
  try {
    await api.updateUser(payload)
    $message.success(value ? '用户已启用' : '用户已封禁')
    $table.value?.handleSearch()
  } catch (error) {
    $message.error(error?.message || '更新用户状态失败')
  } finally {
    row.publishing = false
  }
}

function clearDeptFilter() {
  selectedDeptId.value = null
  queryItems.value = {
    ...queryItems.value,
    dept_id: null,
  }
  $table.value?.handleSearch()
}

async function loadUserMetrics() {
  metricsLoading.value = true
  try {
    const res = await api.getUserMetrics({
      username: queryItems.value.username || undefined,
      dept_id: queryItems.value.dept_id || undefined,
    })
    userMetrics.value = res.data || userMetrics.value
  } finally {
    metricsLoading.value = false
  }
}

function handleDeptNodeClick(option) {
  if (!option?.id) return
  if (selectedDeptId.value === option.id) {
    clearDeptFilter()
    return
  }
  selectedDeptId.value = option.id
  queryItems.value = {
    ...queryItems.value,
    dept_id: option.id,
  }
  $table.value?.handleSearch()
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
      result.push({ ...node, children })
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
          <p>统一管理受邀注册与后台创建用户，支持启用、封禁、角色权限调整、密码重置和使用数据查看。</p>
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
            <p>支持按部门、用户名和邮箱筛选，便于运营查看账号状态、来源和服务调用情况。</p>
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

      <section class="user-insight">
        <div class="user-insight__header">
          <div>
            <p class="user-overview__label">用户洞察</p>
            <h3>按当前筛选范围查看调用与产出</h3>
            <p>聚合用户的视频生成、成功/失败任务和语音调用，方便快速判断活跃度与资源消耗。</p>
          </div>
          <NButton quaternary type="primary" :loading="metricsLoading" @click="loadUserMetrics">刷新数据</NButton>
        </div>

        <div class="user-insight__stats">
          <div v-for="item in userMetricCards" :key="item.label" class="user-stat user-stat--metric">
            <span>{{ item.label }}</span>
            <strong>{{ item.value }}</strong>
            <small>{{ item.hint }}</small>
          </div>
        </div>

        <div class="user-insight__chart">
          <div class="user-insight__chart-head">
            <strong>用户视频生成排行</strong>
            <span>前 8 位用户按视频生成量排序</span>
          </div>
          <div v-if="metricRanking.length" class="user-metric-list">
            <article v-for="item in metricRanking" :key="item.user_id" class="user-metric-row">
              <div class="user-metric-row__copy">
                <strong>{{ item.display_name }}</strong>
                <span>@{{ item.username }}</span>
              </div>
              <div class="user-metric-row__bar">
                <div class="user-metric-row__fill" :style="{ width: `${item.videoPercent}%` }" />
              </div>
              <div class="user-metric-row__meta">
                <span>{{ item.video_count }} 条视频</span>
                <small>成功 {{ item.completed_count }} / 失败 {{ item.failed_count }} / 语音 {{ item.voice_count }}</small>
              </div>
            </article>
          </div>
          <NEmpty v-else description="当前筛选范围暂无统计数据" size="small" />
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

          <NInput v-model:value="deptKeyword" clearable placeholder="搜索部门" />

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
              <h3>账号状态、角色权限与调用概况</h3>
              <p>将封禁、启用、角色编辑、删除和密码重置保持在同一张表内，减少跳转成本。</p>
            </div>
          </div>

          <CrudTable
            ref="$table"
            v-model:query-items="queryItems"
            :columns="columns"
            :get-data="api.getUserList"
            :scroll-x="1960"
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

      <CrudModal v-model:visible="modalVisible" :title="modalTitle" :loading="modalLoading" @save="handleSave">
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
                <NCheckbox v-for="item in roleOption" :key="item.id" :value="item.id" :label="item.name" />
              </div>
            </NCheckboxGroup>
          </NFormItem>
          <NFormItem label="管理员" path="is_superuser">
            <NCheckbox v-model:checked="modalForm.is_superuser">设为管理员</NCheckbox>
          </NFormItem>
          <NFormItem label="启用" path="is_active">
            <NCheckbox v-model:checked="modalForm.is_active">允许登录</NCheckbox>
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
  max-width: 660px;
}

.user-page__eyebrow,
.user-overview__label,
.dept-panel__eyebrow,
.user-table-panel__eyebrow {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  color: var(--brand-primary);
  text-transform: uppercase;
}

.user-page__header-copy h2,
.user-overview__intro h3,
.dept-panel__header h3,
.user-table-panel__header h3 {
  margin: 0;
  color: var(--app-text);
}

.user-page__header-copy h2 {
  font-size: 32px;
  line-height: 1.1;
}

.user-page__header-copy p,
.user-overview__intro p,
.user-table-panel__header p {
  margin: 10px 0 0;
  color: var(--app-muted);
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
  padding: 12px 16px;
  border: 1px solid rgba(255, 105, 0, 0.1);
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.56);
  color: var(--app-text);
  box-shadow: var(--soft-shadow);
  backdrop-filter: blur(16px);
}

.user-page__scope span,
.user-stat span,
.dept-panel__summary span {
  font-size: 12px;
  color: var(--app-muted);
}

.user-page__scope strong,
.dept-panel__summary strong {
  font-size: 15px;
  font-weight: 700;
  color: var(--app-text);
}

.user-overview,
.user-insight,
.dept-panel,
.user-table-panel {
  padding: 20px 22px;
  border: 1px solid var(--shell-border);
  border-radius: 18px;
  background: rgba(255, 251, 248, 0.66);
  box-shadow: var(--soft-shadow);
  backdrop-filter: blur(20px);
}

.user-overview,
.user-insight {
  display: grid;
  gap: 18px;
}

.user-overview__intro,
.user-insight__header,
.dept-panel__header {
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
  gap: 8px;
}

.user-overview__stats,
.user-insight__stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
}

.user-stat {
  display: grid;
  gap: 6px;
  padding: 16px;
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.56);
  border: 1px solid rgba(255, 105, 0, 0.08);
}

.user-stat strong {
  font-size: 28px;
  line-height: 1;
  color: var(--app-text);
}

.user-stat small {
  color: var(--app-muted);
}

.user-insight__chart {
  display: grid;
  gap: 14px;
  padding: 18px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.56);
  border: 1px solid rgba(255, 105, 0, 0.08);
}

.user-insight__chart-head {
  display: grid;
  gap: 4px;
}

.user-insight__chart-head strong {
  color: var(--app-text);
}

.user-insight__chart-head span {
  color: var(--app-muted);
  font-size: 13px;
}

.user-metric-list {
  display: grid;
  gap: 12px;
}

.user-metric-row {
  display: grid;
  grid-template-columns: 220px minmax(0, 1fr) 220px;
  align-items: center;
  gap: 14px;
}

.user-metric-row__copy,
.user-metric-row__meta,
.user-name-cell,
.user-usage-cell {
  display: grid;
  gap: 4px;
}

.user-metric-row__copy strong,
.user-name-cell__title,
.user-usage-cell strong {
  color: var(--app-text);
}

.user-metric-row__copy span,
.user-metric-row__meta small,
.user-name-cell__meta,
.user-role-empty,
.user-usage-cell span,
.user-usage-empty {
  color: var(--app-muted);
  font-size: 12px;
}

.user-metric-row__bar {
  position: relative;
  height: 12px;
  border-radius: 999px;
  background: rgba(93, 141, 247, 0.08);
  overflow: hidden;
}

.user-metric-row__fill {
  height: 100%;
  border-radius: inherit;
  background: linear-gradient(90deg, var(--brand-primary), #ffb36a 60%, #72a5ff);
}

.user-metric-row__meta {
  justify-items: end;
}

.user-metric-row__meta span {
  color: var(--app-text);
  font-size: 13px;
  font-weight: 700;
}

.user-workspace {
  display: grid;
  grid-template-columns: 300px minmax(0, 1fr);
  gap: 20px;
}

.dept-panel {
  display: grid;
  gap: 16px;
  align-content: start;
}

.dept-panel__summary {
  display: grid;
  gap: 4px;
  padding: 14px;
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.6);
  border: 1px solid rgba(255, 105, 0, 0.08);
}

.dept-panel__tree {
  min-height: 280px;
}

.user-table-panel {
  display: grid;
  gap: 16px;
}

.user-action-list,
.user-role-tags,
.modal-role-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.modal-role-grid {
  width: 100%;
}

@media (max-width: 1200px) {
  .user-workspace {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 960px) {
  .user-page__header,
  .user-overview__intro,
  .user-insight__header,
  .dept-panel__header {
    flex-direction: column;
    align-items: flex-start;
  }

  .user-overview__filters {
    justify-content: flex-start;
  }

  .user-overview__stats,
  .user-insight__stats {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .user-metric-row {
    grid-template-columns: 1fr;
    align-items: stretch;
  }

  .user-metric-row__meta {
    justify-items: start;
  }
}

@media (max-width: 640px) {
  .user-overview__stats,
  .user-insight__stats {
    grid-template-columns: 1fr;
  }

  .user-page__header-copy h2 {
    font-size: 26px;
  }
}
</style>
