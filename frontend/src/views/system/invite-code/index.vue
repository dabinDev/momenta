<script setup>
import { computed, h, onMounted, ref, resolveDirective, withDirectives } from 'vue'
import { NButton, NDatePicker, NForm, NFormItem, NInput, NInputNumber, NPopconfirm, NSwitch, NTag } from 'naive-ui'

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

onMounted(() => {
  $table.value?.handleSearch()
})

const overviewStats = computed(() => [
  {
    label: '当前页邀请码',
    value: tableRows.value.length,
    hint: '已加载记录',
  },
  {
    label: '可用邀请码',
    value: tableRows.value.filter(item => item.is_active).length,
    hint: '仍可用于注册',
  },
  {
    label: '已用尽',
    value: tableRows.value.filter(item => Number(item.used_count || 0) >= Number(item.max_uses || 0)).length,
    hint: '达到使用上限',
  },
  {
    label: '即将过期',
    value: tableRows.value.filter(item => item.expires_at).length,
    hint: '已设置过期时间',
  },
])

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
    width: 180,
    render(row) {
      return h('div', { class: 'invite-code-cell' }, [
        h('strong', { class: 'invite-code-cell__title' }, row.code || '--'),
        h('span', { class: 'invite-code-cell__meta' }, row.remark || '未填写备注'),
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
            default: () => h('div', {}, '确定删除该邀请码吗？'),
          }
        ),
      ])
    },
  },
]

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
</script>

<template>
  <CommonPage show-footer>
    <template #header>
      <div class="invite-page__header">
        <div class="invite-page__header-copy">
          <p class="invite-page__eyebrow">INVITE ACCESS</p>
          <h2>邀请码管理</h2>
          <p>只有后台生成的邀请码才能注册。邀请码可控制次数、失效时间和启停状态，保证受邀注册闭环。</p>
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
          :scroll-x="1000"
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
  max-width: 720px;
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

.invite-code-cell__title {
  color: var(--app-text);
  font-size: 14px;
}

.invite-code-cell__meta {
  font-size: 12px;
  color: var(--app-muted);
}

.invite-action-list {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 4px;
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
}
</style>
