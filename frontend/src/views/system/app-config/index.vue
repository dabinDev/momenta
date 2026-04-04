<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import {
  NButton,
  NDrawer,
  NDrawerContent,
  NEmpty,
  NForm,
  NFormItem,
  NInput,
  NPagination,
  NSwitch,
  NTag,
} from 'naive-ui'

import CommonPage from '@/components/page/CommonPage.vue'
import api from '@/api'

defineOptions({ name: '平台配置' })

const router = useRouter()

const loading = ref(false)
const saveLoading = ref(false)
const resetLoading = ref(false)
const globalForm = ref(createGlobalForm())
const privateDrawerVisible = ref(false)
const privateListLoading = ref(false)
const privateDetailLoading = ref(false)
const privateSaveLoading = ref(false)
const privateResetLoading = ref(false)
const privateKeyword = ref('')
const privateRows = ref([])
const privatePagination = ref({
  page: 1,
  pageSize: 8,
  itemCount: 0,
})
const activePrivateUserId = ref(null)
const privateForm = ref(createPrivateForm())

const summaryCards = computed(() => [
  {
    key: 'text',
    label: '文字解析',
    model: globalForm.value.llm_model || '未配置',
    hint: globalForm.value.llm_configured ? '已接入全局通道' : '等待配置平台密钥',
    type: globalForm.value.llm_configured ? 'success' : 'default',
  },
  {
    key: 'video',
    label: '视频生成',
    model: globalForm.value.video_model || '未配置',
    hint: globalForm.value.video_configured ? '全站统一使用该模型' : '等待配置平台密钥',
    type: globalForm.value.video_configured ? 'warning' : 'default',
  },
  {
    key: 'speech',
    label: '音频解析',
    model: globalForm.value.speech_model || '未配置',
    hint: globalForm.value.speech_configured ? '语音识别统一走该模型' : '等待配置平台密钥',
    type: globalForm.value.speech_configured ? 'info' : 'default',
  },
  {
    key: 'image',
    label: '图片生成',
    model: globalForm.value.image_model || '未应用',
    hint: globalForm.value.image_configured ? '能力已打通，暂未公开使用' : '先去模型管理页选择模型',
    type: globalForm.value.image_configured ? 'primary' : 'default',
  },
])

const privateListTitle = computed(() => {
  const current = privateRows.value.find(item => item.user_id === activePrivateUserId.value)
  return current?.user?.alias || current?.user?.username || '内部专属通道'
})

const privateStatusLabel = computed(() => {
  if (!privateForm.value.user_id) return '未选择用户'
  if (privateForm.value.using_private_override) return '已使用专属通道'
  if (privateForm.value.allow_private_ai_override) return '已开通，暂未启用'
  return '未开通'
})

onMounted(async () => {
  await loadGlobalConfig()
})

async function loadGlobalConfig() {
  loading.value = true
  try {
    const res = await api.getGlobalAppConfig()
    globalForm.value = toGlobalForm(res.data || {})
  } finally {
    loading.value = false
  }
}

async function handleSaveGlobal() {
  saveLoading.value = true
  try {
    const res = await api.updateGlobalAppConfig(globalForm.value)
    globalForm.value = toGlobalForm(res.data || {})
    window.$message?.success('平台配置已保存')
  } finally {
    saveLoading.value = false
  }
}

async function handleResetGlobal() {
  resetLoading.value = true
  try {
    const res = await api.resetGlobalAppConfig()
    globalForm.value = toGlobalForm(res.data || {})
    window.$message?.success('平台配置已恢复默认')
  } finally {
    resetLoading.value = false
  }
}

function openModelCenter() {
  router.push('/config/model-center')
}

async function openPrivateDrawer() {
  privateDrawerVisible.value = true
  await loadPrivateList()
}

async function loadPrivateList() {
  privateListLoading.value = true
  try {
    const res = await api.getUserAppConfigList({
      page: privatePagination.value.page,
      page_size: privatePagination.value.pageSize,
      keyword: privateKeyword.value || undefined,
    })
    privateRows.value = Array.isArray(res.data) ? res.data : []
    privatePagination.value.itemCount = res.total || 0
    if (!activePrivateUserId.value && privateRows.value.length) {
      await openPrivateUser(privateRows.value[0].user_id)
    }
    if (activePrivateUserId.value && !privateRows.value.some(item => item.user_id === activePrivateUserId.value)) {
      const first = privateRows.value[0]
      if (first) {
        await openPrivateUser(first.user_id)
      } else {
        activePrivateUserId.value = null
        privateForm.value = createPrivateForm()
      }
    }
  } finally {
    privateListLoading.value = false
  }
}

async function openPrivateUser(userId) {
  if (!userId) return
  activePrivateUserId.value = userId
  privateDetailLoading.value = true
  try {
    const res = await api.getUserAppConfigDetail({ user_id: userId })
    privateForm.value = toPrivateForm(res.data || {})
  } finally {
    privateDetailLoading.value = false
  }
}

async function handleSavePrivate() {
  if (!privateForm.value.user_id) return
  privateSaveLoading.value = true
  try {
    const res = await api.updateUserAppConfig(privateForm.value)
    privateForm.value = toPrivateForm(res.data || {})
    window.$message?.success('专属通道已保存')
    await loadPrivateList()
  } finally {
    privateSaveLoading.value = false
  }
}

async function handleResetPrivate() {
  if (!privateForm.value.user_id) return
  privateResetLoading.value = true
  try {
    const res = await api.resetUserAppConfig({ user_id: privateForm.value.user_id })
    privateForm.value = toPrivateForm(res.data || {})
    window.$message?.success('专属通道已关闭')
    await loadPrivateList()
  } finally {
    privateResetLoading.value = false
  }
}

async function handlePrivateSearch() {
  privatePagination.value.page = 1
  await loadPrivateList()
}

async function handlePrivatePageChange(page) {
  privatePagination.value.page = page
  await loadPrivateList()
}

function createGlobalForm() {
  return {
    provider_base_url: 'https://api.99hub.top',
    provider_api_key: '',
    llm_base_url: '',
    llm_api_key: '',
    llm_model: 'gpt-5.4-mini',
    video_base_url: '',
    video_api_key: '',
    video_model: 'veo_3_1-fast-components-4K',
    speech_base_url: '',
    speech_api_key: '',
    speech_model: 'gpt-4o-mini-audio-preview',
    image_base_url: '',
    image_api_key: '',
    image_model: '',
    llm_configured: false,
    video_configured: false,
    speech_configured: false,
    image_configured: false,
  }
}

function toGlobalForm(item = {}) {
  return {
    ...createGlobalForm(),
    ...item,
  }
}

function createPrivateForm() {
  return {
    user_id: null,
    allow_private_ai_override: false,
    override_enabled: false,
    using_private_override: false,
    provider_base_url: '',
    provider_api_key: '',
    llm_base_url: '',
    llm_api_key: '',
    llm_model: '',
    video_base_url: '',
    video_api_key: '',
    video_model: '',
    speech_base_url: '',
    speech_api_key: '',
    speech_model: '',
    image_base_url: '',
    image_api_key: '',
    image_model: '',
    user: null,
  }
}

function toPrivateForm(item = {}) {
  return {
    ...createPrivateForm(),
    ...item,
  }
}
</script>

<template>
  <CommonPage show-footer>
    <template #header>
      <div class="platform-header">
        <div class="platform-header__copy">
          <p class="platform-header__eyebrow">平台配置</p>
          <h2>统一维护全局模型与平台密钥</h2>
          <p>默认所有用户、App、H5、后台调试台都共用这一套平台能力。模型切换放在模型管理页，当前页只负责全局接入和隐藏的专属通道。</p>
        </div>
        <div class="platform-header__actions">
          <NButton quaternary @click="loadGlobalConfig">刷新配置</NButton>
          <NButton type="primary" @click="openModelCenter">进入模型管理</NButton>
        </div>
      </div>
    </template>

    <div class="platform-page">
      <section class="platform-summary">
        <article v-for="item in summaryCards" :key="item.key" class="platform-card">
          <span>{{ item.label }}</span>
          <strong>{{ item.model }}</strong>
          <small>{{ item.hint }}</small>
          <NTag :type="item.type" :round="false">{{ item.type === 'default' ? '待完善' : '已生效' }}</NTag>
        </article>
      </section>

      <div class="platform-grid">
        <section class="platform-panel">
          <div class="platform-panel__head">
            <div>
              <p class="platform-panel__eyebrow">全局接入</p>
              <h3>统一平台地址与全局 SK</h3>
              <p>平台提供的是统一 base URL 与统一 SK，管理员只需要维护这一份，全站即可同步生效。</p>
            </div>
          </div>

          <NForm label-placement="top" :model="globalForm" class="platform-form">
            <NFormItem label="平台 Base URL">
              <NInput v-model:value="globalForm.provider_base_url" placeholder="https://api.memovideos.cn 或第三方平台地址" />
            </NFormItem>
            <NFormItem label="全局平台 SK">
              <NInput v-model:value="globalForm.provider_api_key" type="password" show-password-on="mousedown" placeholder="输入全局共享 SK" />
            </NFormItem>

            <div class="platform-form__models">
              <div class="platform-model-chip">
                <span>文字解析</span>
                <strong>{{ globalForm.llm_model || '未配置' }}</strong>
              </div>
              <div class="platform-model-chip">
                <span>视频生成</span>
                <strong>{{ globalForm.video_model || '未配置' }}</strong>
              </div>
              <div class="platform-model-chip">
                <span>音频解析</span>
                <strong>{{ globalForm.speech_model || '未配置' }}</strong>
              </div>
              <div class="platform-model-chip">
                <span>图片生成</span>
                <strong>{{ globalForm.image_model || '未应用' }}</strong>
              </div>
            </div>
          </NForm>

          <div class="platform-panel__footer">
            <NButton quaternary type="warning" :loading="resetLoading" @click="handleResetGlobal">恢复默认</NButton>
            <NButton type="primary" :loading="saveLoading" @click="handleSaveGlobal">保存平台配置</NButton>
          </div>
        </section>

        <section class="platform-panel">
          <div class="platform-panel__head">
            <div>
              <p class="platform-panel__eyebrow">能力说明</p>
              <h3>模型应用规则</h3>
              <p>管理端手动应用某个能力的模型后，后续所有普通用户都会直接走新的全局模型。少量付费用户如果开通专属通道，才会覆盖全局配置。</p>
            </div>
          </div>

          <div class="platform-rules">
            <article class="platform-rule">
              <strong>默认生效</strong>
              <p>视频生成、提示词生成、语音识别与后台 AI 调试台，都会优先读取平台全局模型。</p>
            </article>
            <article class="platform-rule">
              <strong>管理员手动切换</strong>
              <p>去模型管理页同步目录、查看推荐模型并点击应用，即可切换对应能力的全局模型。</p>
            </article>
            <article class="platform-rule">
              <strong>隐藏付费能力</strong>
              <p>专属 SK 与私有模型覆盖不出现在公开菜单中，只能通过当前页右上角的隐藏入口进入。</p>
            </article>
          </div>

          <div class="platform-mini-actions">
            <NButton quaternary type="primary" @click="openModelCenter">查看模型管理</NButton>
          </div>

          <p class="platform-secret" @dblclick="openPrivateDrawer">内部运维位</p>
        </section>
      </div>
    </div>
  </CommonPage>

  <NDrawer v-model:show="privateDrawerVisible" placement="right" :width="920">
    <NDrawerContent closable>
      <template #header>
        <div class="private-header">
          <div>
            <p class="platform-panel__eyebrow">内部专属通道</p>
            <h3>{{ privateListTitle }}</h3>
            <p>只有少量付费用户才需要开通。留空表示继续跟随平台全局配置。</p>
          </div>
          <NTag type="warning" :round="false">{{ privateStatusLabel }}</NTag>
        </div>
      </template>

      <div class="private-layout">
        <aside class="private-list">
          <div class="private-list__toolbar">
            <NInput v-model:value="privateKeyword" clearable placeholder="搜索用户名 / 别名 / 邮箱" @keyup.enter="handlePrivateSearch" />
            <NButton type="primary" @click="handlePrivateSearch">查询</NButton>
          </div>

          <div v-if="privateRows.length" class="private-list__items">
            <button
              v-for="item in privateRows"
              :key="item.user_id"
              type="button"
              class="private-user"
              :class="{ 'private-user--active': item.user_id === activePrivateUserId }"
              @click="openPrivateUser(item.user_id)"
            >
              <strong>{{ item.user?.alias || item.user?.username }}</strong>
              <span>@{{ item.user?.username }}</span>
              <small>{{ item.using_private_override ? '已启用专属通道' : item.allow_private_ai_override ? '已开通，未启用' : '未开通' }}</small>
            </button>
          </div>
          <NEmpty v-else :description="privateListLoading ? '正在加载用户' : '暂无可选用户'" />

          <div class="private-list__pagination">
            <NPagination
              :page="privatePagination.page"
              :page-size="privatePagination.pageSize"
              :item-count="privatePagination.itemCount"
              @update:page="handlePrivatePageChange"
            />
          </div>
        </aside>

        <section class="private-panel">
          <div v-if="privateDetailLoading" class="private-panel__loading">正在读取用户专属配置...</div>
          <NEmpty v-else-if="!privateForm.user_id" description="请先从左侧选择用户" />
          <template v-else>
            <div class="private-switches">
              <div class="private-switch">
                <span>允许专属通道</span>
                <NSwitch v-model:value="privateForm.allow_private_ai_override" />
              </div>
              <div class="private-switch">
                <span>立即启用覆盖</span>
                <NSwitch v-model:value="privateForm.override_enabled" :disabled="!privateForm.allow_private_ai_override" />
              </div>
            </div>

            <NForm label-placement="top" :model="privateForm" class="private-form">
              <NFormItem label="专属 Base URL">
                <NInput v-model:value="privateForm.provider_base_url" placeholder="留空则跟随平台全局地址" />
              </NFormItem>
              <NFormItem label="专属 SK">
                <NInput v-model:value="privateForm.provider_api_key" type="password" show-password-on="mousedown" placeholder="留空则继续使用平台全局 SK" />
              </NFormItem>
              <div class="private-form__models">
                <NFormItem label="文字模型">
                  <NInput v-model:value="privateForm.llm_model" placeholder="留空则跟随平台文字模型" />
                </NFormItem>
                <NFormItem label="视频模型">
                  <NInput v-model:value="privateForm.video_model" placeholder="留空则跟随平台视频模型" />
                </NFormItem>
                <NFormItem label="音频模型">
                  <NInput v-model:value="privateForm.speech_model" placeholder="留空则跟随平台音频模型" />
                </NFormItem>
                <NFormItem label="图片模型">
                  <NInput v-model:value="privateForm.image_model" placeholder="留空则跟随平台图片模型" />
                </NFormItem>
              </div>
            </NForm>

            <div class="private-panel__footer">
              <NButton quaternary type="warning" :loading="privateResetLoading" @click="handleResetPrivate">关闭专属通道</NButton>
              <NButton type="primary" :loading="privateSaveLoading" @click="handleSavePrivate">保存专属配置</NButton>
            </div>
          </template>
        </section>
      </div>
    </NDrawerContent>
  </NDrawer>
</template>

<style scoped>
.platform-header,
.platform-header__actions,
.platform-panel__footer,
.platform-mini-actions,
.private-header,
.private-list__toolbar,
.private-switches,
.private-panel__footer {
  display: flex;
  gap: 12px;
}

.platform-header,
.private-header {
  align-items: flex-end;
  justify-content: space-between;
}

.platform-header {
  width: 100%;
}

.platform-header__copy {
  max-width: 760px;
}

.platform-header__eyebrow,
.platform-panel__eyebrow {
  margin: 0 0 8px;
  color: var(--brand-primary);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
}

.platform-header h2,
.platform-panel h3,
.private-header h3 {
  margin: 0;
  color: var(--app-text);
}

.platform-header p:last-child,
.platform-panel p:last-child,
.private-header p:last-child {
  margin: 10px 0 0;
  color: var(--app-muted);
  line-height: 1.7;
}

.platform-page {
  display: grid;
  gap: 22px;
}

.platform-summary,
.platform-grid,
.private-layout,
.platform-form__models,
.platform-rules,
.private-form__models {
  display: grid;
  gap: 16px;
}

.platform-summary {
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.platform-grid {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.platform-card,
.platform-panel,
.platform-model-chip,
.platform-rule,
.private-list,
.private-panel,
.private-user {
  border: 1px solid var(--shell-border);
  border-radius: 20px;
  background: rgba(255, 251, 248, 0.72);
  box-shadow: var(--soft-shadow);
  backdrop-filter: blur(18px);
}

.platform-card,
.platform-model-chip,
.platform-rule,
.private-user {
  display: grid;
  gap: 8px;
  padding: 18px;
}

.platform-panel,
.private-list,
.private-panel {
  padding: 22px;
}

.platform-card span,
.platform-model-chip span,
.platform-rule p,
.private-user span,
.private-user small,
.private-panel__loading {
  color: var(--app-muted);
}

.platform-card strong,
.platform-model-chip strong,
.platform-rule strong,
.private-user strong {
  color: var(--app-text);
}

.platform-card strong {
  font-size: 20px;
  line-height: 1.3;
}

.platform-panel {
  display: grid;
  gap: 18px;
}

.platform-panel__head {
  display: flex;
  justify-content: space-between;
  gap: 16px;
}

.platform-form {
  display: grid;
  gap: 12px;
}

.platform-form__models,
.private-form__models {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.platform-panel__footer,
.platform-mini-actions,
.private-panel__footer {
  justify-content: flex-end;
}

.platform-secret {
  margin: 2px 0 0;
  color: rgba(120, 126, 139, 0.48);
  font-size: 12px;
  text-align: right;
  user-select: none;
}

.private-layout {
  grid-template-columns: 300px minmax(0, 1fr);
  height: 100%;
}

.private-list,
.private-panel {
  display: grid;
  align-content: start;
}

.private-list__items {
  display: grid;
  gap: 10px;
  margin-top: 16px;
}

.private-user {
  text-align: left;
  cursor: pointer;
  transition: transform 0.2s ease, border-color 0.2s ease, box-shadow 0.2s ease;
}

.private-user--active {
  border-color: rgba(255, 105, 0, 0.28);
  transform: translateY(-1px);
}

.private-list__pagination {
  margin-top: 16px;
  display: flex;
  justify-content: flex-end;
}

.private-panel {
  gap: 18px;
}

.private-switches {
  align-items: center;
  justify-content: flex-start;
  flex-wrap: wrap;
}

.private-switch {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  padding: 12px 14px;
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.58);
  color: var(--app-text);
}

.private-form {
  display: grid;
  gap: 12px;
}

@media (max-width: 1200px) {
  .platform-summary,
  .platform-grid,
  .private-layout {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 768px) {
  .platform-header,
  .platform-panel__head,
  .private-header {
    flex-direction: column;
    align-items: flex-start;
  }

  .platform-summary,
  .platform-form__models,
  .private-form__models {
    grid-template-columns: 1fr;
  }

  .platform-panel__footer,
  .platform-mini-actions,
  .private-panel__footer {
    flex-direction: column;
  }
}
</style>
