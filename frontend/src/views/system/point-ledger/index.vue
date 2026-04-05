<script setup>
import { h, onMounted, ref } from 'vue'
import { NInput, NSelect, NTag } from 'naive-ui'

import CommonPage from '@/components/page/CommonPage.vue'
import QueryBarItem from '@/components/query-bar/QueryBarItem.vue'
import CrudTable from '@/components/table/CrudTable.vue'

import api from '@/api'
import { formatDate } from '@/utils'

defineOptions({ name: '积分流水' })

const $table = ref(null)
const userOptions = ref([])
const queryItems = ref({
  user_id: null,
  transaction_type: '',
})

const transactionOptions = [
  { label: '全部类型', value: '' },
  { label: '邀请注册奖励', value: 'invite_signup' },
  { label: '邀请好友奖励', value: 'invite_reward' },
  { label: '管理员赠送', value: 'admin_gift' },
  { label: '视频生成扣费', value: 'video_consume' },
  { label: '视频失败退回', value: 'video_refund' },
  { label: '充值到账', value: 'recharge' },
]

const columns = [
  {
    title: '用户',
    key: 'user',
    width: 180,
    render(row) {
      return row.user?.alias || row.user?.username || '--'
    },
  },
  {
    title: '类型',
    key: 'transaction_type',
    width: 150,
    render(row) {
      const isCredit = String(row.direction || '').toLowerCase() === 'credit'
      return h(
        NTag,
        { size: 'small', round: true, type: isCredit ? 'success' : 'warning' },
        { default: () => row.title || row.transaction_type || '--' },
      )
    },
  },
  {
    title: '积分变动',
    key: 'change_amount',
    width: 120,
    render(row) {
      const value = Number(row.change_amount || 0)
      return value > 0 ? `+${value}` : `${value}`
    },
  },
  {
    title: '变更后余额',
    key: 'balance_after',
    width: 120,
  },
  {
    title: '关联对象',
    key: 'related_object',
    width: 220,
    render(row) {
      if (row.task_id) return `任务 #${row.task_id}`
      if (row.recharge_order_id) return `充值单 #${row.recharge_order_id}`
      if (row.invite_code_id) return `邀请码 #${row.invite_code_id}`
      return row.related_user?.username ? `关联用户 @${row.related_user.username}` : '--'
    },
  },
  {
    title: '备注',
    key: 'remark',
    minWidth: 220,
    ellipsis: { tooltip: true },
    render(row) {
      return row.remark || '--'
    },
  },
  {
    title: '时间',
    key: 'created_at',
    width: 180,
    render(row) {
      return row.created_at ? formatDate(row.created_at) : '--'
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
</script>

<template>
  <CommonPage show-footer>
    <template #header>
      <div class="page-head">
        <div>
          <p class="page-head__eyebrow">POINT LEDGER</p>
          <h2>积分流水</h2>
          <p>统一查看邀请奖励、管理员赠送、视频扣费与失败退款、充值到账等全部积分变更记录。</p>
        </div>
      </div>
    </template>

    <section class="page-card">
      <CrudTable
        ref="$table"
        v-model:query-items="queryItems"
        :columns="columns"
        :get-data="api.getPointLedgerList"
        :scroll-x="1280"
      >
        <template #queryBar>
          <QueryBarItem label="用户" :label-width="44">
            <NSelect v-model:value="queryItems.user_id" clearable :options="userOptions" placeholder="筛选用户" />
          </QueryBarItem>
          <QueryBarItem label="类型" :label-width="44">
            <NSelect
              v-model:value="queryItems.transaction_type"
              clearable
              :options="transactionOptions"
              placeholder="筛选流水类型"
            />
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
</style>
