<script setup>
import { computed, h, onMounted, ref, resolveDirective, withDirectives } from 'vue'
import {
  NButton,
  NForm,
  NFormItem,
  NInput,
  NInputNumber,
  NPopconfirm,
  NRadio,
  NRadioGroup,
  NSwitch,
  NTag,
  NTreeSelect,
} from 'naive-ui'

import CommonPage from '@/components/page/CommonPage.vue'
import CrudModal from '@/components/table/CrudModal.vue'
import CrudTable from '@/components/table/CrudTable.vue'
import IconPicker from '@/components/icon/IconPicker.vue'
import TheIcon from '@/components/icon/TheIcon.vue'

import { formatDate, renderIcon } from '@/utils'
import { useCRUD } from '@/composables'
import api from '@/api'

defineOptions({ name: '菜单管理' })

const $table = ref(null)
const queryItems = ref({})
const tableRows = ref([])
const menuOptions = ref([])
const vPermission = resolveDirective('permission')

const initForm = {
  parent_id: 0,
  menu_type: 'catalog',
  name: '',
  path: '',
  component: '',
  redirect: '',
  icon: '',
  order: 1,
  keepalive: true,
  is_hidden: false,
}

const {
  modalVisible,
  modalTitle,
  modalLoading,
  handleAdd,
  handleDelete,
  handleEdit,
  handleSave,
  modalForm,
  modalFormRef,
} = useCRUD({
  name: '菜单',
  initForm,
  doCreate: api.createMenu,
  doDelete: api.deleteMenu,
  doUpdate: api.updateMenu,
  refresh: async () => {
    await refreshMenuTree()
    $table.value?.handleSearch()
  },
})

onMounted(async () => {
  await refreshMenuTree()
  $table.value?.handleSearch()
})

const totalMenuCount = computed(() => countTreeNodes(tableRows.value))
const catalogCount = computed(() => countByType(tableRows.value, 'catalog'))
const pageMenuCount = computed(() => countByType(tableRows.value, 'menu'))
const hiddenCount = computed(() => countByBoolean(tableRows.value, 'is_hidden'))

const overviewStats = computed(() => [
  {
    label: '菜单总数',
    value: totalMenuCount.value,
    hint: '包含目录与页面',
  },
  {
    label: '目录节点',
    value: catalogCount.value,
    hint: '可继续挂载子菜单',
  },
  {
    label: '页面菜单',
    value: pageMenuCount.value,
    hint: '实际跳转入口',
  },
  {
    label: '隐藏菜单',
    value: hiddenCount.value,
    hint: '侧栏不展示',
  },
])

const columns = [
  {
    title: '菜单',
    key: 'name',
    width: 220,
    ellipsis: { tooltip: true },
    render(row) {
      return h('div', { class: 'menu-name-cell' }, [
        h('div', { class: 'menu-name-cell__main' }, [
          row.icon ? h(TheIcon, { icon: row.icon, size: 18, class: 'menu-name-cell__icon' }) : null,
          h('strong', { class: 'menu-name-cell__title' }, row.name || '--'),
        ]),
        h('span', { class: 'menu-name-cell__meta' }, row.path || '未设置访问路径'),
      ])
    },
  },
  {
    title: '类型',
    key: 'menu_type',
    width: 120,
    render(row) {
      const isCatalog = row.menu_type === 'catalog'
      return h(
        NTag,
        {
          size: 'small',
          round: !isCatalog,
          bordered: isCatalog,
          type: isCatalog ? 'warning' : 'primary',
        },
        { default: () => (isCatalog ? '目录' : '菜单') }
      )
    },
  },
  {
    title: '组件',
    key: 'component',
    width: 220,
    ellipsis: { tooltip: true },
    render(row) {
      return row.component || '--'
    },
  },
  {
    title: '跳转',
    key: 'redirect',
    width: 200,
    ellipsis: { tooltip: true },
    render(row) {
      return row.redirect || '--'
    },
  },
  {
    title: '排序',
    key: 'order',
    width: 90,
    render(row) {
      return h(NTag, { size: 'small', round: true, type: 'info' }, { default: () => row.order ?? 1 })
    },
  },
  {
    title: '缓存',
    key: 'keepalive',
    width: 90,
    render(row) {
      return h(NSwitch, {
        size: 'small',
        rubberBand: false,
        value: row.keepalive,
        loading: !!row.keepaliveLoading,
        onUpdateValue: value => handleUpdateKeepalive(row, value),
      })
    },
  },
  {
    title: '隐藏',
    key: 'is_hidden',
    width: 90,
    render(row) {
      return h(NSwitch, {
        size: 'small',
        rubberBand: false,
        value: row.is_hidden,
        loading: !!row.hiddenLoading,
        onUpdateValue: value => handleUpdateHidden(row, value),
      })
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
      return h('div', { class: 'menu-action-list' }, [
        withDirectives(
          h(
            NButton,
            {
              size: 'small',
              quaternary: true,
              type: 'primary',
              style: { display: row.menu_type !== 'menu' ? '' : 'none' },
              onClick: () => openCreateChildMenu(row),
            },
            {
              default: () => '子菜单',
              icon: renderIcon('material-symbols:add', { size: 16 }),
            }
          ),
          [[vPermission, 'post/api/v1/menu/create']]
        ),
        withDirectives(
          h(
            NButton,
            {
              size: 'small',
              quaternary: true,
              type: 'info',
              onClick: () => openEditMenu(row),
            },
            {
              default: () => '编辑',
              icon: renderIcon('material-symbols:edit-outline', { size: 16 }),
            }
          ),
          [[vPermission, 'post/api/v1/menu/update']]
        ),
        h(
          NPopconfirm,
          {
            onPositiveClick: () => handleDelete({ id: row.id }, false),
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
                    style: { display: row.children?.length ? 'none' : '' },
                  },
                  {
                    default: () => '删除',
                    icon: renderIcon('material-symbols:delete-outline', { size: 16 }),
                  }
                ),
                [[vPermission, 'delete/api/v1/menu/delete']]
              ),
            default: () => h('div', {}, '确定删除该菜单吗？'),
          }
        ),
      ])
    },
  },
]

async function refreshMenuTree() {
  const { data } = await api.getMenus()
  const rootMenu = { id: 0, name: '根目录', children: data ?? [] }
  menuOptions.value = [rootMenu]
}

function handleTableDataChange(data = []) {
  tableRows.value = data
}

function resetMenuForm(payload = {}) {
  Object.assign(initForm, {
    parent_id: 0,
    menu_type: 'catalog',
    name: '',
    path: '',
    component: '',
    redirect: '',
    icon: '',
    order: 1,
    keepalive: true,
    is_hidden: false,
    ...payload,
  })
}

function openCreateRootMenu() {
  resetMenuForm({
    parent_id: 0,
    menu_type: 'catalog',
  })
  handleAdd()
}

function openCreateChildMenu(row) {
  resetMenuForm({
    parent_id: row.id,
    menu_type: 'menu',
  })
  handleAdd()
}

function openEditMenu(row) {
  handleEdit(row)
}

async function handleUpdateKeepalive(row, value) {
  if (!row.id) return
  const previousValue = row.keepalive
  row.keepaliveLoading = true
  row.keepalive = value
  try {
    await api.updateMenu(row)
    $message.success(row.keepalive ? '已开启缓存' : '已关闭缓存')
  } catch (error) {
    row.keepalive = previousValue
  } finally {
    row.keepaliveLoading = false
  }
}

async function handleUpdateHidden(row, value) {
  if (!row.id) return
  const previousValue = row.is_hidden
  row.hiddenLoading = true
  row.is_hidden = value
  try {
    await api.updateMenu(row)
    $message.success(row.is_hidden ? '已隐藏菜单' : '已取消隐藏')
  } catch (error) {
    row.is_hidden = previousValue
  } finally {
    row.hiddenLoading = false
  }
}

function countTreeNodes(nodes = []) {
  return nodes.reduce((total, node) => total + 1 + countTreeNodes(node.children ?? []), 0)
}

function countByType(nodes = [], type) {
  return nodes.reduce((total, node) => {
    const self = node.menu_type === type ? 1 : 0
    return total + self + countByType(node.children ?? [], type)
  }, 0)
}

function countByBoolean(nodes = [], key) {
  return nodes.reduce((total, node) => {
    const self = node[key] ? 1 : 0
    return total + self + countByBoolean(node.children ?? [], key)
  }, 0)
}
</script>

<template>
  <CommonPage show-footer>
    <template #header>
      <div class="menu-page__header">
        <div class="menu-page__header-copy">
          <p class="menu-page__eyebrow">导航结构</p>
          <h2>菜单管理</h2>
          <p>把目录、页面、缓存和隐藏状态集中在同一张树表里，方便快速整理后台导航。</p>
        </div>
        <NButton v-permission="'post/api/v1/menu/create'" type="primary" @click="openCreateRootMenu">
          <TheIcon icon="material-symbols:add" :size="18" class="mr-5" />
          新建根菜单
        </NButton>
      </div>
    </template>

    <div class="menu-page">
      <section class="menu-overview">
        <div class="menu-overview__intro">
          <div>
            <p class="menu-overview__label">导航概览</p>
            <h3>菜单结构与显示状态一屏看清</h3>
            <p>保留必要字段，不堆说明文字，让目录层级和页面入口自己说话。</p>
          </div>
        </div>

        <div class="menu-overview__stats">
          <div v-for="item in overviewStats" :key="item.label" class="menu-stat">
            <span>{{ item.label }}</span>
            <strong>{{ item.value }}</strong>
            <small>{{ item.hint }}</small>
          </div>
        </div>
      </section>

      <section class="menu-table-panel">
        <div class="menu-table-panel__header">
          <div>
            <p class="menu-table-panel__eyebrow">菜单树</p>
            <h3>目录关系、组件映射和可见性</h3>
            <p>子菜单新增、编辑和删除都收在右侧操作列，减少来回切换。</p>
          </div>
        </div>

        <CrudTable
          ref="$table"
          v-model:query-items="queryItems"
          :is-pagination="false"
          :columns="columns"
          :get-data="api.getMenus"
          :scroll-x="1400"
          @on-data-change="handleTableDataChange"
        />
      </section>

      <CrudModal
        v-model:visible="modalVisible"
        :title="modalTitle"
        :loading="modalLoading"
        @save="handleSave(refreshMenuTree)"
      >
        <NForm
          ref="modalFormRef"
          label-placement="left"
          label-align="left"
          :label-width="88"
          :model="modalForm"
        >
          <div class="menu-form-grid">
            <NFormItem label="菜单类型" path="menu_type">
              <NRadioGroup v-model:value="modalForm.menu_type">
                <NRadio label="目录" value="catalog" />
                <NRadio label="菜单" value="menu" />
              </NRadioGroup>
            </NFormItem>
            <NFormItem label="上级菜单" path="parent_id">
              <NTreeSelect
                v-model:value="modalForm.parent_id"
                key-field="id"
                label-field="name"
                :options="menuOptions"
                default-expand-all
              />
            </NFormItem>
            <NFormItem
              label="菜单名称"
              path="name"
              :rule="{
                required: true,
                message: '请输入唯一菜单名称',
                trigger: ['input', 'blur'],
              }"
            >
              <NInput v-model:value="modalForm.name" placeholder="请输入唯一菜单名称" />
            </NFormItem>
            <NFormItem
              label="访问路径"
              path="path"
              :rule="{
                required: true,
                message: '请输入访问路径',
                trigger: ['blur'],
              }"
            >
              <NInput v-model:value="modalForm.path" placeholder="请输入访问路径" />
            </NFormItem>
            <NFormItem v-if="modalForm.menu_type === 'menu'" label="组件路径" path="component">
              <NInput v-model:value="modalForm.component" placeholder="例如：system/user" />
            </NFormItem>
            <NFormItem label="跳转路径" path="redirect">
              <NInput
                v-model:value="modalForm.redirect"
                :disabled="modalForm.parent_id !== 0"
                :placeholder="modalForm.parent_id !== 0 ? '仅一级菜单可设置跳转路径' : '请输入跳转路径'"
              />
            </NFormItem>
            <NFormItem label="菜单图标" path="icon">
              <IconPicker v-model:value="modalForm.icon" />
            </NFormItem>
            <NFormItem label="显示排序" path="order">
              <NInputNumber v-model:value="modalForm.order" :min="1" />
            </NFormItem>
            <NFormItem label="是否隐藏" path="is_hidden">
              <NSwitch v-model:value="modalForm.is_hidden" />
            </NFormItem>
            <NFormItem label="KeepAlive" path="keepalive">
              <NSwitch v-model:value="modalForm.keepalive" />
            </NFormItem>
          </div>
        </NForm>
      </CrudModal>
    </div>
  </CommonPage>
</template>

<style scoped>
.menu-page {
  display: grid;
  gap: 24px;
}

.menu-page__header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 18px;
  width: 100%;
}

.menu-page__header-copy {
  max-width: 620px;
}

.menu-page__eyebrow,
.menu-overview__label,
.menu-table-panel__eyebrow {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: #7d665d;
}

.menu-page__header-copy h2,
.menu-overview__intro h3,
.menu-table-panel__header h3 {
  margin: 0;
  color: #2f2c32;
}

.menu-page__header-copy h2 {
  font-size: 32px;
  line-height: 1.1;
}

.menu-page__header-copy p,
.menu-overview__intro p,
.menu-table-panel__header p {
  margin: 10px 0 0;
  color: #66646d;
  line-height: 1.6;
}

.menu-overview {
  padding: 24px 26px;
  border-radius: 28px;
  border: 1px solid rgba(115, 92, 83, 0.08);
  background:
    radial-gradient(circle at top right, rgba(255, 194, 146, 0.22), transparent 30%),
    linear-gradient(135deg, #fcf8f5 0%, #f7f4fb 48%, #fff7ed 100%);
}

.menu-overview__stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
  margin-top: 18px;
}

.menu-stat {
  display: grid;
  gap: 6px;
  padding-top: 16px;
  border-top: 1px solid rgba(115, 92, 83, 0.08);
}

.menu-stat span {
  font-size: 12px;
  color: #857b75;
}

.menu-stat strong {
  font-size: 28px;
  line-height: 1;
  color: #2f2c32;
}

.menu-stat small {
  color: #857b75;
  line-height: 1.4;
}

.menu-table-panel {
  padding: 22px;
  border-radius: 24px;
  border: 1px solid rgba(115, 92, 83, 0.08);
  background: #fff;
}

.menu-name-cell {
  display: grid;
  gap: 4px;
}

.menu-name-cell__main {
  display: flex;
  align-items: center;
  gap: 8px;
}

.menu-name-cell__title {
  color: #2f2c32;
  font-size: 14px;
}

.menu-name-cell__meta {
  font-size: 12px;
  color: #857b75;
}

.menu-action-list {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 4px;
}

.menu-form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 4px 18px;
}

:deep(.n-data-table-th) {
  background: #fbfaf8;
}

:deep(.n-data-table-td) {
  vertical-align: middle;
}

@media (max-width: 900px) {
  .menu-page__header {
    flex-direction: column;
    align-items: flex-start;
  }

  .menu-overview__stats {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .menu-overview,
  .menu-table-panel {
    padding: 18px;
    border-radius: 20px;
  }

  .menu-page__header-copy h2 {
    font-size: 26px;
  }

  .menu-overview__stats,
  .menu-form-grid {
    grid-template-columns: 1fr;
  }
}
</style>
