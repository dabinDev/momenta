<script setup>
import { h, onMounted, ref, resolveDirective, withDirectives } from 'vue'
import { NButton, NInput, NPopconfirm, NSelect, NTag } from 'naive-ui'

import CommonPage from '@/components/page/CommonPage.vue'
import QueryBarItem from '@/components/query-bar/QueryBarItem.vue'
import CrudTable from '@/components/table/CrudTable.vue'

import api from '@/api'
import { formatDate, renderIcon } from '@/utils'

defineOptions({ name: '充值订单' })

const $table = ref(null)
const userOptions = ref([])
const vPermission = resolveDirective('permission')
const queryItems = ref({
  user_id: null,
  status: '',
})

const statusOptions = [
  { label: '全部状态', value: '' },
  { label: '待支付', value: 'pending' },
  { label: '已到账', value: 'paid' },
  { label: '已取消', value: 'cancelled' },
  { label: '支付失败', value: 'failed' },
]

const columns = [
  {
    title: '订单号',
    key: 'order_no',
    width: 220,
  },
  {
    title: '用户',
    key: 'user',
    width: 180,
    render(row) {
      return row.user?.alias || row.user?.username || '--'
    },
  },
  {
    title: '套餐',
    key: 'package_name',
    width: 180,
    render(row) {
      return `${row.package_name || '--'} / ${row.points_amount || 0} 积分`
    },
  },
  {
    title: '金额',
    key: 'amount_label',
    width: 100,
  },
  {
    title: '支付方式',
    key: 'pay_method_label',
    width: 100,
  },
  {
    title: '状态',
    key: 'status',
    width: 110,
    render(row) {
      const typeMap = {
        pending: 'warning',
        paid: 'success',
        cancelled: 'default',
        failed: 'error',
      }
      return h(
        NTag,
        { size: 'small', round: true, type: typeMap[row.status] || 'default' },
        { default: () => row.status_label || row.status || '--' },
      )
    },
  },
  {
    title: '备注',
    key: 'payment_hint',
    minWidth: 220,
    ellipsis: { tooltip: true },
    render(row) {
      return row.remark || row.payment_hint || '--'
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
    title: '到账时间',
    key: 'paid_at',
    width: 180,
    render(row) {
      return row.paid_at ? formatDate(row.paid_at) : '--'
    },
  },
  {
    title: '操作',
    key: 'actions',
    width: 240,
    fixed: 'right',
    render(row) {
      if (row.status !== 'pending') return '--'
      return h('div', { class: 'action-list' }, [
        withDirectives(
          h(
            NButton,
            {
              size: 'small',
              quaternary: true,
              type: 'success',
              onClick: () => updateStatus(row.order_no, 'paid'),
            },
            {
              default: () => '确认到账',
              icon: renderIcon('material-symbols:check-circle-outline-rounded', { size: 16 }),
            },
          ),
          [[vPermission, 'post/api/v1/recharge_order/update_status']],
        ),
        h(
          NPopconfirm,
          {
            onPositiveClick: () => updateStatus(row.order_no, 'failed'),
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
                    default: () => '标记失败',
                    icon: renderIcon('material-symbols:error-outline-rounded', { size: 16 }),
                  },
                ),
                [[vPermission, 'post/api/v1/recharge_order/update_status']],
              ),
            default: () => h('div', {}, '确认将这笔充值标记为失败吗？'),
          },
        ),
      ])
    },
  },
]

onMounted(async () => {
  const res = await api.getUserList({ page: 1, page_size: 9999 })
  userOptions.value = [
    { label: '全部用户', value: null },
    ...(res.data || []).map((item) => ({
      label: item.alias?.trim() ? `${item.alias} @${item.username}` : item.username,
      value: item.id,
    })),
  ]
})

async function updateStatus(orderNo, status) {
  await api.updateRechargeOrderStatus({
    order_no: orderNo,
    status,
  })
  $message.success(status === 'paid' ? '充值订单已确认到账' : '充值订单状态已更新')
  await $table.value?.handleSearch()
}
</script>

<template>
  <CommonPage show-footer>
    <template #header>
      <div class="page-head">
        <div>
          <p class="page-head__eyebrow">RECHARGE ORDERS</p>
          <h2>充值订单</h2>
          <p>统一查看 App 发起的积分充值订单，并在当前阶段手动确认到账或标记失败。</p>
        </div>
      </div>
    </template>

    <section class="page-card">
      <CrudTable
        ref="$table"
        v-model:query-items="queryItems"
        :columns="columns"
        :get-data="api.getRechargeOrderList"
        :scroll-x="1580"
      >
        <template #queryBar>
          <QueryBarItem label="用户" :label-width="44">
            <NSelect v-model:value="queryItems.user_id" clearable :options="userOptions" placeholder="筛选用户" />
          </QueryBarItem>
          <QueryBarItem label="状态" :label-width="44">
            <NSelect v-model:value="queryItems.status" clearable :options="statusOptions" placeholder="筛选状态" />
          </QueryBarItem>
        </template>
      </CrudTable>
    </section>
  </CommonPage>
</template>

<style scoped>
.page-head {
  width: 100%;
}

.page-head__eyebrow {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  color: var(--brand-primary);
  text-transform: uppercase;
}

.page-head h2 {
  margin: 0;
  font-size: 32px;
  color: var(--app-text);
}

.page-head p {
  margin: 10px 0 0;
  color: var(--app-muted);
  line-height: 1.6;
}

.page-card {
  padding: 18px;
  border: 1px solid var(--shell-border);
  border-radius: 18px;
  background: rgba(255, 251, 248, 0.68);
  box-shadow: var(--soft-shadow);
  backdrop-filter: blur(18px);
}

.action-list {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
</style>
