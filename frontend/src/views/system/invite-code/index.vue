<script setup>
import { computed, h, onMounted, ref, resolveDirective, withDirectives } from 'vue'
import {
  NButton,
  NDatePicker,
  NForm,
  NFormItem,
  NInput,
  NInputNumber,
  NModal,
  NPopconfirm,
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

defineOptions({ name: '邀请码管理' })

const $table = ref(null)
const queryItems = ref({
  code: null,
})
const tableRows = ref([])
const qrVisible = ref(false)
const activeInvite = ref(null)
const vPermission = resolveDirective('permission')

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
  name: '邀请码',
  initForm: {
    remark: '',
    max_uses: 1,
    expires_at: null,
    is_active: true,
  },
  doCreate: api.createInviteCode,
  doUpdate: api.updateInviteCode,
  doDelete: api.deleteInviteCode,
  refresh: () => $table.value?.handleSearch(),
})

const h5RegisterBaseUrl = computed(() => 'https://memovideos.cn/?inviteCode=')
const appSchemeBaseUrl = computed(() => 'momenta://register?inviteCode=')

const qrImageUrl = computed(() => {
  const code = activeInvite.value?.code
  if (!code) return ''
  const url = `${h5RegisterBaseUrl.value}${encodeURIComponent(code)}`
  return `https://api.qrserver.com/v1/create-qr-code/?size=320x320&margin=16&data=${encodeURIComponent(url)}`
})

const overviewStats = computed(() => {
  const now = Date.now()
  return [
    {
      label: '当前页邀请码',
      value: tableRows.value.length,
      hint: '本次查询已加载记录数',
    },
    {
      label: '可用邀请码',
      value: tableRows.value.filter((item) => item.is_active).length,
      hint: '可继续发给用户注册',
    },
    {
      label: '已达上限',
      value: tableRows.value.filter((item) => Number(item.used_count || 0) >= Number(item.max_uses || 0)).length,
      hint: '已用完，不再允许注册',
    },
    {
      label: '即将过期',
      value: tableRows.value.filter((item) => item.expires_at && new Date(item.expires_at).getTime() > now).length,
      hint: '已设置失效时间',
    },
  ]
})

const rules = {
  max_uses: [
    {
      required: true,
      type: 'number',
      message: '请输入可用次数',
      trigger: ['blur', 'change'],
    },
  ],
}

const columns = [
  {
    title: '邀请码',
    key: 'code',
    width: 320,
    render(row) {
      const registerUrl = `${h5RegisterBaseUrl.value}${row.code || ''}`
      return h('div', { class: 'invite-code-cell' }, [
        h('div', { class: 'invite-code-cell__row' }, [
          h('strong', { class: 'invite-code-cell__title' }, row.code || '--'),
          h(
            NButton,
            {
              size: 'tiny',
              quaternary: true,
              type: 'primary',
              onClick: async () => {
                await navigator.clipboard.writeText(row.code || '')
                $message.success('邀请码已复制')
              },
            },
            { default: () => '复制' }
          ),
        ]),
        h('span', { class: 'invite-code-cell__meta' }, row.remark || '未填写备注'),
        h('span', { class: 'invite-code-cell__link' }, registerUrl),
      ])
    },
  },
  {
    title: '状态',
    key: 'is_active',
    width: 110,
    render(row) {
      return h(
        NTag,
        {
          size: 'small',
          round: true,
          type: row.is_active ? 'success' : 'default',
        },
        {
          default: () => (row.is_active ? '可用' : '停用'),
        }
      )
    },
  },
  {
    title: '使用进度',
    key: 'used_count',
    width: 120,
    render(row) {
      return `${row.used_count || 0} / ${row.max_uses || 0}`
    },
  },
  {
    title: '过期时间',
    key: 'expires_at',
    width: 180,
    render(row) {
      return row.expires_at ? formatDate(row.expires_at) : '长期有效'
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
  {
    title: '操作',
    key: 'actions',
    width: 260,
    fixed: 'right',
    render(row) {
      return h('div', { class: 'invite-action-list' }, [
        withDirectives(
          h(
            NButton,
            {
              size: 'small',
              quaternary: true,
              type: 'info',
              onClick: () => openQrPreview(row),
            },
            {
              default: () => '二维码',
              icon: renderIcon('material-symbols:qr-code-2-rounded', { size: 16 }),
            }
          ),
          [[vPermission, 'post/api/v1/invite_code/update']]
        ),
        withDirectives(
          h(
            NButton,
            {
              size: 'small',
              quaternary: true,
              type: 'primary',
              onClick: () => handleEdit({ ...row }),
            },
            {
              default: () => '编辑',
              icon: renderIcon('material-symbols:edit-outline', { size: 16 }),
            }
          ),
          [[vPermission, 'post/api/v1/invite_code/update']]
        ),
        withDirectives(
          h(
            NButton,
            {
              size: 'small',
              quaternary: true,
              type: row.is_active ? 'warning' : 'success',
              onClick: async () => {
                await api.toggleInviteCode({
                  invite_code_id: row.id,
                  is_active: !row.is_active,
                })
                $message.success(row.is_active ? '邀请码已停用' : '邀请码已启用')
                $table.value?.handleSearch()
              },
            },
            {
              default: () => (row.is_active ? '停用' : '启用'),
              icon: renderIcon('material-symbols:key-vertical-outline', { size: 16 }),
            }
          ),
          [[vPermission, 'post/api/v1/invite_code/toggle']]
        ),
        h(
          NPopconfirm,
          {
            onPositiveClick: () => handleDelete({ invite_code_id: row.id }),
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
                [[vPermission, 'delete/api/v1/invite_code/delete']]
              ),
            default: () => h('div', {}, '确定删除这个邀请码吗？'),
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

function openCreateInviteCode() {
  handleAdd()
  modalForm.value.max_uses = 1
  modalForm.value.is_active = true
}

function normalizeForm() {
  if (!modalForm.value.expires_at) {
    modalForm.value.expires_at = null
  }
}

function openQrPreview(row) {
  activeInvite.value = row
  qrVisible.value = true
}

async function copyInviteLink() {
  const code = activeInvite.value?.code
  if (!code) return
  const targetUrl = `${h5RegisterBaseUrl.value}${encodeURIComponent(code)}`
  await navigator.clipboard.writeText(targetUrl)
  $message.success('注册链接已复制')
}

async function copyInviteCode() {
  const code = activeInvite.value?.code
  if (!code) return
  await navigator.clipboard.writeText(code)
  $message.success('邀请码已复制')
}
</script>

<template>
  <CommonPage show-footer>
    <template #header>
      <div class="invite-page__header">
        <div class="invite-page__header-copy">
          <p class="invite-page__eyebrow">邀请注册</p>
          <h2>邀请码管理</h2>
          <p>
            邀请码只保留真正必要的运营字段，生成后可直接复制链接或二维码给用户。H5 打开会自动带入邀请码，App
            也可复用同一份邀请信息。
          </p>
        </div>
        <NButton v-permission="'post/api/v1/invite_code/create'" type="primary" @click="openCreateInviteCode">
          <TheIcon icon="material-symbols:add" :size="18" class="mr-5" />
          新建邀请码
        </NButton>
      </div>
    </template>

    <div class="invite-page">
      <section class="invite-overview">
        <div v-for="item in overviewStats" :key="item.label" class="invite-stat">
          <span>{{ item.label }}</span>
          <strong>{{ item.value }}</strong>
          <small>{{ item.hint }}</small>
        </div>
      </section>

      <section class="invite-panel">
        <CrudTable
          ref="$table"
          v-model:query-items="queryItems"
          :columns="columns"
          :get-data="api.getInviteCodeList"
          :scroll-x="1080"
          @on-data-change="handleTableDataChange"
        >
          <template #queryBar>
            <QueryBarItem label="邀请码" :label-width="56">
              <NInput
                v-model:value="queryItems.code"
                clearable
                placeholder="输入邀请码片段"
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
        @save="
          () => {
            normalizeForm()
            handleSave()
          }
        "
      >
        <NForm ref="modalFormRef" :model="modalForm" :rules="rules" label-placement="left" :label-width="90">
          <NFormItem v-if="modalAction === 'edit'" label="邀请码">
            <NInput :value="modalForm.code || ''" disabled />
          </NFormItem>
          <NFormItem label="备注" path="remark">
            <NInput v-model:value="modalForm.remark" clearable placeholder="例如：渠道合作、测试用户" />
          </NFormItem>
          <NFormItem label="可用次数" path="max_uses">
            <NInputNumber v-model:value="modalForm.max_uses" :min="1" class="w-full" />
          </NFormItem>
          <NFormItem label="过期时间" path="expires_at">
            <NDatePicker
              v-model:formatted-value="modalForm.expires_at"
              value-format="yyyy-MM-dd HH:mm:ss"
              type="datetime"
              clearable
              class="w-full"
            />
          </NFormItem>
          <NFormItem v-if="modalAction === 'edit'" label="是否启用" path="is_active">
            <NSwitch v-model:value="modalForm.is_active" />
          </NFormItem>
        </NForm>
      </CrudModal>

      <NModal v-model:show="qrVisible" preset="card" style="width: 480px" title="邀请码二维码" :bordered="false">
        <div class="invite-qr">
          <div class="invite-qr__code">{{ activeInvite?.code || '--' }}</div>
          <p class="invite-qr__copy">
            二维码默认指向 H5 注册链接，用户扫码后会自动带入邀请码。也可以单独复制邀请码给 App 注册页使用。
          </p>
          <div class="invite-qr__image-wrap">
            <img v-if="qrImageUrl" :src="qrImageUrl" alt="邀请码二维码" class="invite-qr__image" />
          </div>
          <div class="invite-qr__link-group">
            <div class="invite-qr__link">{{ h5RegisterBaseUrl }}{{ activeInvite?.code || '' }}</div>
            <div class="invite-qr__link invite-qr__link--muted">{{ appSchemeBaseUrl }}{{ activeInvite?.code || '' }}</div>
          </div>
          <div class="invite-qr__actions">
            <NButton type="primary" @click="copyInviteLink">复制注册链接</NButton>
            <NButton quaternary type="primary" @click="copyInviteCode">复制邀请码</NButton>
            <NButton quaternary @click="qrVisible = false">关闭</NButton>
          </div>
        </div>
      </NModal>
    </div>
  </CommonPage>
</template>

<style scoped>
.invite-page {
  display: grid;
  gap: 24px;
}

.invite-page__header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 20px;
  width: 100%;
}

.invite-page__header-copy {
  max-width: 760px;
}

.invite-page__eyebrow {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  color: var(--brand-primary);
  text-transform: uppercase;
}

.invite-page__header-copy h2 {
  margin: 0;
  font-size: 32px;
  line-height: 1.1;
  color: var(--app-text);
}

.invite-page__header-copy p {
  margin: 10px 0 0;
  color: var(--app-muted);
  line-height: 1.6;
}

.invite-overview {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
}

.invite-stat,
.invite-panel {
  padding: 18px;
  border: 1px solid var(--shell-border);
  border-radius: 18px;
  background: rgba(255, 251, 248, 0.68);
  box-shadow: var(--soft-shadow);
  backdrop-filter: blur(18px);
}

.invite-stat {
  display: grid;
  gap: 6px;
}

.invite-stat span {
  font-size: 12px;
  color: var(--app-muted);
}

.invite-stat strong {
  font-size: 28px;
  line-height: 1;
  color: var(--app-text);
}

.invite-stat small {
  color: var(--app-muted);
}

.invite-code-cell {
  display: grid;
  gap: 4px;
}

.invite-code-cell__row {
  display: flex;
  align-items: center;
  gap: 8px;
}

.invite-code-cell__title {
  color: var(--app-text);
  font-size: 14px;
}

.invite-code-cell__meta {
  font-size: 12px;
  color: var(--app-muted);
}

.invite-code-cell__link {
  font-size: 12px;
  color: var(--brand-primary);
  word-break: break-all;
}

.invite-action-list {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 4px;
}

.invite-qr {
  display: grid;
  gap: 14px;
}

.invite-qr__code {
  font-size: 22px;
  font-weight: 800;
  color: var(--app-text);
}

.invite-qr__copy {
  margin: 0;
  color: var(--app-muted);
  line-height: 1.6;
}

.invite-qr__image-wrap {
  display: flex;
  justify-content: center;
  padding: 20px;
  border-radius: 20px;
  background: rgba(255, 251, 248, 0.86);
  border: 1px solid var(--shell-border);
}

.invite-qr__image {
  width: 240px;
  height: 240px;
  object-fit: contain;
}

.invite-qr__link-group {
  display: grid;
  gap: 8px;
}

.invite-qr__link {
  padding: 12px 14px;
  border-radius: 14px;
  background: rgba(255, 251, 248, 0.86);
  color: var(--brand-primary);
  word-break: break-all;
}

.invite-qr__link--muted {
  color: var(--app-muted);
}

.invite-qr__actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}

@media (max-width: 900px) {
  .invite-page__header {
    flex-direction: column;
    align-items: flex-start;
  }

  .invite-overview {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .invite-overview {
    grid-template-columns: 1fr;
  }

  .invite-page__header-copy h2 {
    font-size: 26px;
  }

  .invite-qr__actions {
    flex-wrap: wrap;
    justify-content: flex-start;
  }
}
</style>
