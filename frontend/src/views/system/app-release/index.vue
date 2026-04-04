<script setup>
import { computed, h, onMounted, ref, resolveDirective, watch, withDirectives } from 'vue'
import {
  NButton,
  NForm,
  NFormItem,
  NInput,
  NInputNumber,
  NPopconfirm,
  NSelect,
  NSwitch,
  NTag,
} from 'naive-ui'

import CommonPage from '@/components/page/CommonPage.vue'
import QueryBarItem from '@/components/query-bar/QueryBarItem.vue'
import CrudModal from '@/components/table/CrudModal.vue'
import CrudTable from '@/components/table/CrudTable.vue'
import TheIcon from '@/components/icon/TheIcon.vue'

import { formatDate, renderIcon } from '@/utils'
import { useCRUD } from '@/composables'
import api from '@/api'

defineOptions({ name: '版本发布' })

const $table = ref(null)
const tableRows = ref([])
const queryItems = ref({
  platform: null,
  channel: null,
  keyword: null,
  is_active: null,
})

const vPermission = resolveDirective('permission')

const platformOptions = [
  { label: 'Android', value: 'android' },
  { label: 'iOS', value: 'ios' },
]

const channelOptions = [
  { label: '局域网', value: 'lan' },
  { label: '公开版', value: 'public' },
  { label: '测试版', value: 'beta' },
]

const activeOptions = [
  { label: '全部状态', value: null },
  { label: '已启用', value: true },
  { label: '未启用', value: false },
]

const {
  modalVisible,
  modalTitle,
  modalLoading,
  modalAction,
  modalForm,
  modalFormRef,
  handleAdd,
  handleEdit,
  handleDelete,
  handleSave,
} = useCRUD({
  name: '版本',
  initForm: {
    platform: 'android',
    channel: 'lan',
    version_name: '',
    build_number: 1,
    title: '',
    release_notes: '',
    download_url: '',
    force_update: false,
    is_active: true,
  },
  doCreate: api.createAppRelease,
  doUpdate: api.updateAppRelease,
  doDelete: api.deleteAppRelease,
  refresh: () => $table.value?.handleSearch(),
})

const overviewStats = computed(() => [
  {
    label: '当前记录',
    value: tableRows.value.length,
    hint: '已加载的发布记录',
  },
  {
    label: '启用发布',
    value: tableRows.value.filter(item => item.is_active).length,
    hint: '客户端会读取这些版本',
  },
  {
    label: '强制更新',
    value: tableRows.value.filter(item => item.force_update).length,
    hint: '用户必须升级后继续使用',
  },
  {
    label: 'Android 版本',
    value: tableRows.value.filter(item => item.platform === 'android').length,
    hint: '当前主要发布平台',
  },
])

const activeFilters = computed(() => {
  const filters = []
  if (queryItems.value.platform) {
    filters.push({ type: 'primary', label: `平台：${queryItems.value.platform}` })
  }
  if (queryItems.value.channel) {
    filters.push({ type: 'success', label: `渠道：${queryItems.value.channel}` })
  }
  if (queryItems.value.keyword) {
    filters.push({ type: 'warning', label: `搜索：${queryItems.value.keyword}` })
  }
  if (queryItems.value.is_active !== null && queryItems.value.is_active !== undefined) {
    filters.push({
      type: 'info',
      label: queryItems.value.is_active ? '仅看启用' : '仅看停用',
    })
  }
  return filters
})

const rules = {
  version_name: [
    {
      required: true,
      message: '请输入版本号',
      trigger: ['blur', 'input'],
    },
  ],
  build_number: [
    {
      required: true,
      type: 'number',
      message: '请输入构建号',
      trigger: ['blur', 'change'],
    },
  ],
  platform: [
    {
      required: true,
      message: '请选择平台',
      trigger: ['blur', 'change'],
    },
  ],
  channel: [
    {
      required: true,
      message: '请选择渠道',
      trigger: ['blur', 'change'],
    },
  ],
  title: [
    {
      required: true,
      message: '请输入版本标题',
      trigger: ['blur', 'input'],
    },
  ],
  release_notes: [
    {
      required: true,
      message: '请输入版本说明',
      trigger: ['blur', 'input'],
    },
  ],
  download_url: [
    {
      validator: (_rule, value) => {
        const raw = `${value || ''}`.trim()
        if (modalForm.value.is_active && !raw) {
          return new Error('启用发布时必须填写下载地址')
        }
        if (raw && !/^https?:\/\//i.test(raw)) {
          return new Error('下载地址必须以 http:// 或 https:// 开头')
        }
        return true
      },
      trigger: ['blur', 'input'],
    },
  ],
}

const columns = [
  {
    title: '版本',
    key: 'version_name',
    width: 180,
    render(row) {
      return h('div', { class: 'release-version-cell' }, [
        h('strong', { class: 'release-version-cell__title' }, `V${row.version_name || '--'}`),
        h('span', { class: 'release-version-cell__meta' }, `Build ${row.build_number ?? '--'}`),
      ])
    },
  },
  {
    title: '标题',
    key: 'title',
    width: 220,
    ellipsis: { tooltip: true },
    render(row) {
      return row.title || '--'
    },
  },
  {
    title: '平台',
    key: 'platform',
    width: 120,
    render(row) {
      return h(
        NTag,
        { round: true, size: 'small', type: row.platform === 'android' ? 'success' : 'default' },
        { default: () => row.platform || '--' }
      )
    },
  },
  {
    title: '渠道',
    key: 'channel',
    width: 120,
    render(row) {
      return h(NTag, { round: true, size: 'small', type: 'warning' }, { default: () => row.channel || '--' })
    },
  },
  {
    title: '状态',
    key: 'status',
    width: 160,
    render(row) {
      return h('div', { class: 'release-status-list' }, [
        h(
          NTag,
          { round: true, size: 'small', type: row.is_active ? 'primary' : 'default' },
          { default: () => (row.is_active ? '启用中' : '未启用') }
        ),
        row.force_update
          ? h(NTag, { round: true, size: 'small', type: 'error' }, { default: () => '强制更新' })
          : null,
      ].filter(Boolean))
    },
  },
  {
    title: '发布时间',
    key: 'published_at',
    width: 180,
    render(row) {
      return row.published_at ? formatDate(row.published_at) : '--'
    },
  },
  {
    title: '下载地址',
    key: 'download_url',
    minWidth: 320,
    ellipsis: { tooltip: true },
    render(row) {
      return row.download_url || '--'
    },
  },
  {
    title: '操作',
    key: 'actions',
    width: 180,
    fixed: 'right',
    render(row) {
      return h('div', { class: 'release-action-list' }, [
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
          [[vPermission, 'post/api/v1/app_release/update']]
        ),
        h(
          NPopconfirm,
          {
            onPositiveClick: () => handleDelete({ id: row.id }),
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
                [[vPermission, 'delete/api/v1/app_release/delete']]
              ),
            default: () => h('div', {}, '确认删除这条版本发布记录吗？'),
          }
        ),
      ])
    },
  },
]

onMounted(() => {
  $table.value?.handleSearch()
})

function handleTableDataChange(data = []) {
  tableRows.value = data
}

function normalizeModalForm() {
  modalForm.value.build_number = Number(modalForm.value.build_number || 1)
  modalForm.value.version_name = `${modalForm.value.version_name || ''}`.trim()
  modalForm.value.title = `${modalForm.value.title || ''}`.trim()
  modalForm.value.release_notes = `${modalForm.value.release_notes || ''}`.trim()
  modalForm.value.download_url = `${modalForm.value.download_url || ''}`.trim()
  modalForm.value.force_update = modalForm.value.force_update === true
  modalForm.value.is_active = modalForm.value.is_active === true
}

function openCreateModal() {
  handleAdd()
  modalForm.value.platform = 'android'
  modalForm.value.channel = 'lan'
  modalForm.value.build_number = getNextBuildNumber('android', 'lan')
  modalForm.value.force_update = false
  modalForm.value.is_active = true
}

function getNextBuildNumber(platform = 'android', channel = 'lan') {
  const builds = tableRows.value
    .filter(item => item.platform === platform && item.channel === channel)
    .map(item => Number(item.build_number || 0))
    .filter(item => Number.isFinite(item) && item > 0)
  return builds.length ? Math.max(...builds) + 1 : 1
}

watch(
  () => [modalAction.value, modalForm.value.platform, modalForm.value.channel],
  ([action, platform, channel], [prevAction, prevPlatform, prevChannel] = []) => {
    if (action !== 'add') {
      return
    }
    if (platform === prevPlatform && channel === prevChannel && prevAction === action) {
      return
    }
    modalForm.value.build_number = getNextBuildNumber(platform || 'android', channel || 'lan')
  }
)

function openEditModal(row) {
  handleEdit(row)
  normalizeModalForm()
}

function handleModalSave() {
  normalizeModalForm()
  handleSave(() => {
    if (modalForm.value.is_active) {
      $message.success('已发布为当前生效版本，客户端会读取这条配置')
      return
    }
    $message.success('版本记录已保存')
  })
}
</script>

<template>
  <CommonPage show-footer>
    <template #header>
      <div class="release-page__header">
        <div class="release-page__header-copy">
          <p class="release-page__eyebrow">版本发布</p>
          <h2>版本发布</h2>
          <p>
            在 Web 管理端统一维护 App 的版本号、下载地址、更新说明和强制更新策略。
            客户端检查更新时会直接读取这里的启用版本。
          </p>
        </div>
        <NButton v-permission="'post/api/v1/app_release/create'" type="primary" @click="openCreateModal">
          <TheIcon icon="material-symbols:add" :size="18" class="mr-5" />
          新建版本
        </NButton>
      </div>
    </template>

    <div class="release-page">
      <section class="release-overview">
        <div class="release-overview__intro">
          <div>
            <p class="release-overview__label">统一发布面板</p>
            <h3>一个入口维护所有版本更新配置</h3>
            <p>
              启用中的版本会作为 App 的最新版本返回；同平台同渠道下，只会保留一个生效版本。
            </p>
          </div>
          <div class="release-overview__filters">
            <NTag v-for="item in activeFilters" :key="item.label" round :type="item.type">
              {{ item.label }}
            </NTag>
          </div>
        </div>
        <div class="release-overview__stats">
          <div v-for="item in overviewStats" :key="item.label" class="release-stat">
            <span>{{ item.label }}</span>
            <strong>{{ item.value }}</strong>
            <small>{{ item.hint }}</small>
          </div>
        </div>
      </section>

      <section class="release-table-panel">
        <div class="release-table-panel__header">
          <div>
            <p class="release-table-panel__eyebrow">发布记录</p>
            <h3>版本号、渠道、下载入口与更新说明</h3>
            <p>建议每次发布都填写完整的标题、说明和 APK 下载地址，便于 App 端直接使用。</p>
          </div>
        </div>

        <CrudTable
          ref="$table"
          v-model:query-items="queryItems"
          :columns="columns"
          :get-data="api.getAppReleaseList"
          :scroll-x="1320"
          @on-data-change="handleTableDataChange"
        >
          <template #queryBar>
            <QueryBarItem label="平台" :label-width="44">
              <NSelect
                v-model:value="queryItems.platform"
                clearable
                :options="platformOptions"
                placeholder="全部平台"
              />
            </QueryBarItem>
            <QueryBarItem label="渠道" :label-width="44">
              <NSelect
                v-model:value="queryItems.channel"
                clearable
                :options="channelOptions"
                placeholder="全部渠道"
              />
            </QueryBarItem>
            <QueryBarItem label="状态" :label-width="44">
              <NSelect
                v-model:value="queryItems.is_active"
                :options="activeOptions"
                placeholder="全部状态"
              />
            </QueryBarItem>
            <QueryBarItem label="搜索" :label-width="44">
              <NInput
                v-model:value="queryItems.keyword"
                clearable
                placeholder="版本号或标题"
                @keypress.enter="$table?.handleSearch()"
              />
            </QueryBarItem>
          </template>
        </CrudTable>
      </section>

      <CrudModal
        v-model:visible="modalVisible"
        width="720px"
        :title="modalTitle"
        :loading="modalLoading"
        @save="handleModalSave"
      >
        <NForm
          ref="modalFormRef"
          label-placement="left"
          label-align="left"
          :label-width="92"
          :model="modalForm"
          :rules="rules"
        >
          <NFormItem label="平台" path="platform">
            <NSelect
              v-model:value="modalForm.platform"
              :options="platformOptions"
              placeholder="请选择平台"
            />
          </NFormItem>
          <NFormItem label="渠道" path="channel">
            <NSelect
              v-model:value="modalForm.channel"
              :options="channelOptions"
              placeholder="请选择渠道"
            />
          </NFormItem>
          <NFormItem label="版本号" path="version_name">
            <NInput v-model:value="modalForm.version_name" placeholder="例如 1.2.0" />
          </NFormItem>
          <NFormItem label="构建号" path="build_number">
            <NInputNumber
              v-model:value="modalForm.build_number"
              clearable
              :min="1"
              placeholder="例如 12"
              style="width: 100%"
            />
          </NFormItem>
          <NFormItem label="版本标题" path="title">
            <NInput v-model:value="modalForm.title" placeholder="例如 V1.2.0 正式版" />
          </NFormItem>
          <NFormItem label="下载地址" path="download_url">
            <NInput
              v-model:value="modalForm.download_url"
              placeholder="例如 https://memovideos.cn/file/V1.2.0.apk"
            />
          </NFormItem>
          <NFormItem label="更新说明" path="release_notes">
            <NInput
              v-model:value="modalForm.release_notes"
              type="textarea"
              :autosize="{ minRows: 4, maxRows: 7 }"
              placeholder="填写本次版本更新内容，App 会直接展示这里的说明"
            />
          </NFormItem>
          <NFormItem label="强制更新" path="force_update">
            <NSwitch v-model:value="modalForm.force_update" />
          </NFormItem>
          <NFormItem label="启用发布" path="is_active">
            <NSwitch v-model:value="modalForm.is_active" />
          </NFormItem>
          <div class="release-modal__hint">
            启用发布后，同平台同渠道下其他已启用版本会自动转为未启用。
            如果当前版本需要让客户端真正可升级，请同时填写可访问的下载地址。
          </div>
        </NForm>
      </CrudModal>
    </div>
  </CommonPage>
</template>

<style scoped>
.release-page {
  display: grid;
  gap: 24px;
}

.release-page__header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 20px;
  width: 100%;
}

.release-page__header-copy {
  max-width: 720px;
}

.release-page__eyebrow,
.release-overview__label,
.release-table-panel__eyebrow {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  color: var(--brand-primary);
  text-transform: uppercase;
}

.release-page__header-copy h2,
.release-overview__intro h3,
.release-table-panel__header h3 {
  margin: 0;
  color: var(--app-text);
}

.release-page__header-copy h2 {
  font-size: 32px;
  line-height: 1.1;
}

.release-page__header-copy p,
.release-overview__intro p,
.release-table-panel__header p {
  margin: 10px 0 0;
  color: var(--app-muted);
  line-height: 1.6;
}

.release-overview {
  position: relative;
  overflow: hidden;
  padding: 20px 22px;
  border: 1px solid var(--shell-border);
  border-radius: 18px;
  background: rgba(255, 251, 248, 0.66);
  box-shadow: var(--soft-shadow);
  backdrop-filter: blur(20px);
}

.release-overview__intro {
  position: relative;
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 18px;
  z-index: 1;
}

.release-overview__filters {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 10px;
  min-width: 220px;
}

.release-overview__stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
  margin-top: 18px;
}

.release-stat {
  display: grid;
  gap: 6px;
  padding: 14px 16px;
  border: 1px solid rgba(255, 105, 0, 0.08);
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.46);
  backdrop-filter: blur(12px);
}

.release-stat span {
  font-size: 12px;
  color: var(--app-muted);
}

.release-stat strong {
  font-size: 28px;
  line-height: 1;
  color: var(--app-text);
}

.release-stat small {
  color: var(--app-muted);
  line-height: 1.4;
}

.release-table-panel {
  display: grid;
  gap: 18px;
  min-width: 0;
  padding: 18px;
  border: 1px solid var(--shell-border);
  border-radius: 18px;
  background: rgba(255, 251, 248, 0.7);
  box-shadow: var(--soft-shadow);
  backdrop-filter: blur(18px);
}

.release-table-panel__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.release-version-cell {
  display: grid;
  gap: 4px;
}

.release-version-cell__title {
  color: var(--app-text);
  font-size: 14px;
}

.release-version-cell__meta {
  font-size: 12px;
  color: var(--app-muted);
}

.release-status-list,
.release-action-list {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.release-modal__hint {
  margin-top: 4px;
  padding: 12px 14px;
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.52);
  color: var(--app-muted);
  line-height: 1.6;
}

:deep(.n-data-table-th) {
  background: #fff5ee;
}

:deep(.n-data-table-td) {
  vertical-align: middle;
}

@media (max-width: 900px) {
  .release-page__header,
  .release-overview__intro {
    flex-direction: column;
    align-items: flex-start;
  }

  .release-overview__filters {
    width: 100%;
    justify-content: flex-start;
  }

  .release-overview__stats {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .release-overview,
  .release-table-panel {
    padding: 18px;
    border-radius: 20px;
  }

  .release-page__header-copy h2 {
    font-size: 26px;
  }

  .release-overview__stats {
    grid-template-columns: 1fr;
  }
}
</style>
