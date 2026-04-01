<script setup>
import { computed, h, onMounted, ref, resolveDirective, withDirectives } from 'vue'
import {
  NButton,
  NDataTable,
  NDrawer,
  NDrawerContent,
  NForm,
  NFormItem,
  NInput,
  NPagination,
  NPopconfirm,
  NTag,
} from 'naive-ui'

import CommonPage from '@/components/page/CommonPage.vue'
import { formatDate, renderIcon } from '@/utils'
import api from '@/api'

defineOptions({ name: '应用配置' })

const loading = ref(false)
const rows = ref([])
const keyword = ref('')
const drawerVisible = ref(false)
const drawerLoading = ref(false)
const saveLoading = ref(false)
const resetLoading = ref(false)
const activeItem = ref(null)
const formRef = ref(null)
const form = ref(createEmptyForm())
const pagination = ref({
  page: 1,
  pageSize: 10,
  itemCount: 0,
})

const vPermission = resolveDirective('permission')

const summaryItems = computed(() => [
  {
    label: '当前分页',
    value: rows.value.length,
    hint: `共 ${pagination.value.itemCount} 位用户`,
  },
  {
    label: '文本服务已配置',
    value: rows.value.filter(item => item.llm_configured).length,
    hint: '已填写模型和密钥',
  },
  {
    label: '视频服务已配置',
    value: rows.value.filter(item => item.video_configured).length,
    hint: '支持独立视频通道',
  },
])

const drawerTitle = computed(() => {
  const user = activeItem.value?.user || {}
  return user.alias || user.username || '应用配置'
})

const rules = {
  llm_base_url: [{ required: true, message: '请输入文本服务地址', trigger: ['input', 'blur'] }],
  llm_model: [{ required: true, message: '请输入文本模型名称', trigger: ['input', 'blur'] }],
  video_base_url: [{ required: true, message: '请输入视频服务地址', trigger: ['input', 'blur'] }],
  video_model: [{ required: true, message: '请输入视频模型名称', trigger: ['input', 'blur'] }],
}

const columns = [
  {
    title: '用户',
    key: 'user',
    width: 220,
    render(row) {
      return h('div', { class: 'config-user' }, [
        h('strong', {}, row.user?.alias || row.user?.username || '--'),
        h('span', {}, row.user?.username ? `@${row.user.username}` : row.user?.email || '--'),
      ])
    },
  },
  {
    title: '文本服务',
    key: 'llm',
    minWidth: 280,
    render(row) {
      return h('div', { class: 'config-provider' }, [
        h('strong', {}, row.llm_model || '--'),
        h('span', {}, shortHost(row.llm_base_url)),
        h(
          NTag,
          { size: 'small', type: row.llm_configured ? 'success' : 'default', round: false },
          { default: () => (row.llm_configured ? row.llm_api_key_masked : '未配置密钥') }
        ),
      ])
    },
  },
  {
    title: '视频服务',
    key: 'video',
    minWidth: 280,
    render(row) {
      return h('div', { class: 'config-provider' }, [
        h('strong', {}, row.video_model || '--'),
        h('span', {}, shortHost(row.video_base_url)),
        h(
          NTag,
          { size: 'small', type: row.video_configured ? 'warning' : 'default', round: false },
          { default: () => (row.video_configured ? row.video_api_key_masked : '未配置密钥') }
        ),
      ])
    },
  },
  {
    title: '最近更新',
    key: 'updated_at',
    width: 180,
    render(row) {
      return row.updated_at ? formatDate(row.updated_at) : '使用默认配置'
    },
  },
  {
    title: '状态',
    key: 'status',
    width: 180,
    render(row) {
      return h('div', { class: 'config-status' }, [
        h(
          NTag,
          { size: 'small', type: row.user?.is_active ? 'primary' : 'default', round: false },
          { default: () => (row.user?.is_active ? '账号启用' : '账号停用') }
        ),
        row.has_custom_config
          ? h(NTag, { size: 'small', type: 'info', round: false }, { default: () => '已落库' })
          : h(NTag, { size: 'small', round: false }, { default: () => '默认模板' }),
      ])
    },
  },
  {
    title: '操作',
    key: 'actions',
    width: 180,
    fixed: 'right',
    render(row) {
      return h('div', { class: 'config-actions' }, [
        withDirectives(
          h(
            NButton,
            {
              size: 'small',
              quaternary: true,
              type: 'primary',
              onClick: () => openEditor(row),
            },
            {
              default: () => '编辑',
              icon: renderIcon('material-symbols:edit-outline', { size: 16 }),
            }
          ),
          [[vPermission, 'get/api/v1/app_config/get']]
        ),
        h(
          NPopconfirm,
          {
            onPositiveClick: () => handleResetRow(row),
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
                    loading: resetLoading.value === row.user_id,
                  },
                  {
                    default: () => '恢复默认',
                    icon: renderIcon('material-symbols:settings-backup-restore-rounded', { size: 16 }),
                  }
                ),
                [[vPermission, 'post/api/v1/app_config/reset']]
              ),
            default: () => '确认恢复该用户的应用默认配置？',
          }
        ),
      ])
    },
  },
]

onMounted(() => {
  fetchList()
})

async function fetchList() {
  loading.value = true
  try {
    const res = await api.getUserAppConfigList({
      page: pagination.value.page,
      page_size: pagination.value.pageSize,
      keyword: keyword.value || undefined,
    })
    rows.value = res.data || []
    pagination.value.itemCount = res.total || 0
  } finally {
    loading.value = false
  }
}

async function openEditor(row) {
  drawerVisible.value = true
  drawerLoading.value = true
  try {
    const res = await api.getUserAppConfigDetail({ user_id: row.user_id })
    activeItem.value = res.data
    form.value = toForm(res.data)
  } finally {
    drawerLoading.value = false
  }
}

async function handleSave() {
  formRef.value?.validate(async (errors) => {
    if (errors) return
    saveLoading.value = true
    try {
      const res = await api.updateUserAppConfig(form.value)
      activeItem.value = res.data
      form.value = toForm(res.data)
      window.$message?.success('配置已保存')
      await fetchList()
    } finally {
      saveLoading.value = false
    }
  })
}

async function handleResetRow(row) {
  resetLoading.value = row.user_id
  try {
    const res = await api.resetUserAppConfig({ user_id: row.user_id })
    if (activeItem.value?.user_id === row.user_id) {
      activeItem.value = res.data
      form.value = toForm(res.data)
    }
    window.$message?.success('已恢复默认配置')
    await fetchList()
  } finally {
    resetLoading.value = false
  }
}

async function handleResetDrawer() {
  if (!form.value.user_id) return
  resetLoading.value = form.value.user_id
  try {
    const res = await api.resetUserAppConfig({ user_id: form.value.user_id })
    activeItem.value = res.data
    form.value = toForm(res.data)
    window.$message?.success('已恢复默认配置')
    await fetchList()
  } finally {
    resetLoading.value = false
  }
}

function handleSearch() {
  pagination.value.page = 1
  fetchList()
}

function handlePageChange(page) {
  pagination.value.page = page
  fetchList()
}

function createEmptyForm() {
  return {
    user_id: null,
    llm_base_url: '',
    llm_api_key: '',
    llm_model: '',
    video_base_url: '',
    video_api_key: '',
    video_model: '',
  }
}

function toForm(item = {}) {
  return {
    user_id: item.user_id ?? null,
    llm_base_url: item.llm_base_url || '',
    llm_api_key: item.llm_api_key || '',
    llm_model: item.llm_model || '',
    video_base_url: item.video_base_url || '',
    video_api_key: item.video_api_key || '',
    video_model: item.video_model || '',
  }
}

function shortHost(url = '') {
  if (!url) return '--'
  try {
    return new URL(url).host
  } catch (error) {
    return url
  }
}
</script>

<template>
  <CommonPage show-footer>
    <template #header>
      <div class="config-header">
        <div class="config-header__copy">
          <p class="config-header__eyebrow">APP CONFIG</p>
          <h2>用户应用配置</h2>
          <p>集中维护每个用户的文案模型、视频模型和密钥来源，web 与 app 读写同一套配置。</p>
        </div>
        <div class="config-header__actions">
          <NInput
            v-model:value="keyword"
            clearable
            placeholder="搜索用户名、昵称或邮箱"
            @keyup.enter="handleSearch"
          />
          <NButton type="primary" @click="handleSearch">查询</NButton>
        </div>
      </div>
    </template>

    <div class="config-page">
      <aside class="config-rail">
        <section class="config-rail__section">
          <p class="config-rail__label">配置覆盖</p>
          <div class="config-rail__stats">
            <div v-for="item in summaryItems" :key="item.label" class="config-stat">
              <span>{{ item.label }}</span>
              <strong>{{ item.value }}</strong>
              <small>{{ item.hint }}</small>
            </div>
          </div>
        </section>

        <section class="config-rail__section">
          <p class="config-rail__label">使用说明</p>
          <ul class="config-rail__list">
            <li>未落库的用户会直接使用默认模板。</li>
            <li>填写密钥后，app 的文案和视频生成会优先走该用户独立通道。</li>
            <li>恢复默认不会影响历史任务，只影响后续请求。</li>
          </ul>
        </section>
      </aside>

      <section class="config-table">
        <div class="config-table__header">
          <div>
            <p class="config-table__eyebrow">按用户管理</p>
            <h3>统一查看每个账号的生成通道</h3>
          </div>
          <NButton quaternary @click="fetchList">刷新列表</NButton>
        </div>

        <NDataTable
          :loading="loading"
          :columns="columns"
          :data="rows"
          :scroll-x="1220"
          remote
        />

        <div class="config-table__pagination">
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

  <NDrawer v-model:show="drawerVisible" placement="right" :width="560">
    <NDrawerContent closable>
      <template #header>
        <div class="config-drawer__header">
          <div>
            <p class="config-drawer__eyebrow">USER CONFIG</p>
            <h3>{{ drawerTitle }}</h3>
            <p>{{ activeItem?.user?.email || '当前用户配置详情' }}</p>
          </div>
          <div v-if="activeItem" class="config-drawer__tags">
            <NTag :type="activeItem.llm_configured ? 'success' : 'default'" :round="false">
              {{ activeItem.llm_configured ? '文本服务已启用' : '文本服务默认' }}
            </NTag>
            <NTag :type="activeItem.video_configured ? 'warning' : 'default'" :round="false">
              {{ activeItem.video_configured ? '视频服务已启用' : '视频服务默认' }}
            </NTag>
          </div>
        </div>
      </template>

      <div v-if="drawerLoading" class="config-drawer__loading">正在读取配置...</div>

      <div v-else-if="activeItem" class="config-drawer">
        <div class="config-drawer__meta">
          <div>
            <span>用户账号</span>
            <strong>{{ activeItem.user?.username || '--' }}</strong>
          </div>
          <div>
            <span>最近更新</span>
            <strong>{{ activeItem.updated_at ? formatDate(activeItem.updated_at) : '默认模板' }}</strong>
          </div>
        </div>

        <NForm
          ref="formRef"
          :model="form"
          :rules="rules"
          label-placement="top"
          class="config-form"
        >
          <section class="config-form__group">
            <div class="config-form__heading">
              <p>文本生成服务</p>
              <span>用于润色文案和生成提示词</span>
            </div>
            <NFormItem label="服务地址" path="llm_base_url">
              <NInput v-model:value="form.llm_base_url" placeholder="https://api.moonshot.cn/v1" />
            </NFormItem>
            <NFormItem label="API Key" path="llm_api_key">
              <NInput v-model:value="form.llm_api_key" type="password" show-password-on="mousedown" />
            </NFormItem>
            <NFormItem label="模型名称" path="llm_model">
              <NInput v-model:value="form.llm_model" placeholder="moonshot-v1-8k" />
            </NFormItem>
          </section>

          <section class="config-form__group">
            <div class="config-form__heading">
              <p>视频生成服务</p>
              <span>用于图生视频和文生视频任务</span>
            </div>
            <NFormItem label="服务地址" path="video_base_url">
              <NInput v-model:value="form.video_base_url" placeholder="https://api.openai.com/v1" />
            </NFormItem>
            <NFormItem label="API Key" path="video_api_key">
              <NInput v-model:value="form.video_api_key" type="password" show-password-on="mousedown" />
            </NFormItem>
            <NFormItem label="模型名称" path="video_model">
              <NInput v-model:value="form.video_model" placeholder="video-generation" />
            </NFormItem>
          </section>
        </NForm>

        <div class="config-drawer__footer">
          <NButton
            v-permission="'post/api/v1/app_config/reset'"
            quaternary
            type="warning"
            :loading="resetLoading === form.user_id"
            @click="handleResetDrawer"
          >
            恢复默认
          </NButton>
          <NButton
            v-permission="'post/api/v1/app_config/update'"
            type="primary"
            :loading="saveLoading"
            @click="handleSave"
          >
            保存配置
          </NButton>
        </div>
      </div>
    </NDrawerContent>
  </NDrawer>
</template>

<style scoped>
.config-header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 20px;
  width: 100%;
}

.config-header__copy {
  max-width: 620px;
}

.config-header__eyebrow,
.config-rail__label,
.config-table__eyebrow,
.config-drawer__eyebrow {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--brand-primary);
}

.config-header h2,
.config-table h3,
.config-drawer h3 {
  margin: 0;
  color: var(--app-text);
}

.config-header__copy p:last-child,
.config-table__header p:last-child,
.config-drawer__header p:last-child {
  margin: 10px 0 0;
  color: var(--app-muted);
  line-height: 1.6;
}

.config-header__actions {
  display: grid;
  grid-template-columns: minmax(280px, 340px) auto;
  gap: 12px;
}

.config-page {
  display: grid;
  grid-template-columns: 300px minmax(0, 1fr);
  gap: 22px;
}

.config-rail,
.config-table {
  min-width: 0;
  border: 1px solid var(--shell-border);
  background: var(--surface-card);
}

.config-rail {
  display: grid;
  align-content: start;
  gap: 0;
}

.config-rail__section {
  padding: 20px;
}

.config-rail__section + .config-rail__section {
  border-top: 1px solid var(--shell-divider);
}

.config-rail__stats {
  display: grid;
  gap: 14px;
}

.config-stat {
  display: grid;
  gap: 6px;
}

.config-stat span,
.config-drawer__meta span,
.config-provider span,
.config-user span {
  font-size: 12px;
  color: var(--app-muted);
}

.config-stat strong {
  font-size: 28px;
  line-height: 1;
  color: var(--app-text);
}

.config-stat small {
  color: var(--app-muted);
  line-height: 1.4;
}

.config-rail__list {
  display: grid;
  gap: 10px;
  margin: 0;
  padding-left: 18px;
  color: var(--app-muted);
  line-height: 1.7;
}

.config-table {
  display: grid;
  gap: 16px;
  padding: 18px;
}

.config-table__header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 16px;
}

.config-table__pagination {
  display: flex;
  justify-content: flex-end;
}

.config-user,
.config-provider {
  display: grid;
  gap: 6px;
}

.config-user strong,
.config-provider strong {
  color: var(--app-text);
}

.config-status,
.config-actions,
.config-drawer__tags {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.config-drawer__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.config-drawer__loading {
  color: var(--app-muted);
}

.config-drawer {
  display: grid;
  gap: 20px;
}

.config-drawer__meta {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
  padding-bottom: 16px;
  border-bottom: 1px solid var(--shell-divider);
}

.config-drawer__meta strong {
  display: block;
  margin-top: 6px;
  color: var(--app-text);
}

.config-form {
  display: grid;
  gap: 18px;
}

.config-form__group {
  padding-bottom: 18px;
  border-bottom: 1px solid var(--shell-divider);
}

.config-form__group:last-child {
  padding-bottom: 0;
  border-bottom: 0;
}

.config-form__heading {
  margin-bottom: 14px;
}

.config-form__heading p {
  margin: 0;
  font-weight: 700;
  color: var(--app-text);
}

.config-form__heading span {
  display: block;
  margin-top: 6px;
  color: var(--app-muted);
}

.config-drawer__footer {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}

:deep(.n-data-table-th) {
  background: var(--surface-muted);
}

:deep(.n-data-table-td) {
  vertical-align: middle;
}

@media (max-width: 1100px) {
  .config-page {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 840px) {
  .config-header {
    flex-direction: column;
    align-items: flex-start;
  }

  .config-header__actions {
    width: 100%;
    grid-template-columns: 1fr auto;
  }
}

@media (max-width: 640px) {
  .config-header__actions,
  .config-drawer__meta {
    grid-template-columns: 1fr;
  }

  .config-drawer__header {
    flex-direction: column;
  }
}
</style>
