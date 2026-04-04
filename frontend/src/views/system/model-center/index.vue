<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import {
  NButton,
  NEmpty,
  NSelect,
  NTabPane,
  NTag,
  NTabs,
} from 'naive-ui'

import CommonPage from '@/components/page/CommonPage.vue'
import api from '@/api'

defineOptions({ name: '模型管理' })

const activeService = ref('video')
const loadingGlobal = ref(false)
const globalConfig = ref(createGlobalConfig())
const listLoading = reactive({
  image: false,
  video: false,
  speech: false,
  llm: false,
})
const syncLoading = reactive({
  image: false,
  video: false,
  speech: false,
  llm: false,
})
const recommendLoading = reactive({
  image: false,
  video: false,
  speech: false,
  llm: false,
})
const applyLoading = ref('')
const catalogByService = reactive({
  image: [],
  video: [],
  speech: [],
  llm: [],
})
const recommendedByService = reactive({
  image: null,
  video: null,
  speech: null,
  llm: null,
})
const prioritizeMap = reactive({
  image: 'balanced',
  video: 'balanced',
  speech: 'fast',
  llm: 'balanced',
})

const serviceMeta = {
  image: {
    label: '图片生成',
    description: '能力已实现，当前主要用于后台能力预留。',
    color: 'primary',
    requireImageInput: false,
  },
  video: {
    label: '视频生成',
    description: '当前线上默认使用 veo_3_1-fast-components-4K。',
    color: 'warning',
    requireImageInput: true,
  },
  speech: {
    label: '音频解析',
    description: '用于语音识别转文字和后台音频解析。',
    color: 'info',
    requireImageInput: false,
  },
  llm: {
    label: '文字解析',
    description: '用于纠错、校准输入和生成视频提示词。',
    color: 'success',
    requireImageInput: false,
  },
}

const prioritizeOptions = [
  { label: '综合最优', value: 'balanced' },
  { label: '优先低价', value: 'cheap' },
  { label: '优先速度', value: 'fast' },
  { label: '优先质量', value: 'quality' },
]

const summaryCards = computed(() => [
  {
    key: 'image',
    label: serviceMeta.image.label,
    value: globalConfig.value.image_model || '未应用',
    type: serviceMeta.image.color,
  },
  {
    key: 'video',
    label: serviceMeta.video.label,
    value: globalConfig.value.video_model || '未应用',
    type: serviceMeta.video.color,
  },
  {
    key: 'speech',
    label: serviceMeta.speech.label,
    value: globalConfig.value.speech_model || '未应用',
    type: serviceMeta.speech.color,
  },
  {
    key: 'llm',
    label: serviceMeta.llm.label,
    value: globalConfig.value.llm_model || '未应用',
    type: serviceMeta.llm.color,
  },
])

const currentRecommended = computed(() => recommendedByService[activeService.value] || null)
const currentMeta = computed(() => serviceMeta[activeService.value])

watch(activeService, async (service) => {
  if (!catalogByService[service].length) {
    await loadCatalog(service)
  }
})

onMounted(async () => {
  await loadGlobalConfig()
  await loadCatalog(activeService.value)
})

async function loadGlobalConfig() {
  loadingGlobal.value = true
  try {
    const res = await api.getGlobalAppConfig()
    globalConfig.value = { ...createGlobalConfig(), ...(res.data || {}) }
  } finally {
    loadingGlobal.value = false
  }
}

async function loadCatalog(service, { syncFirst = false } = {}) {
  if (!service) return
  if (syncFirst) {
    syncLoading[service] = true
    try {
      await api.syncModelCatalog({
        scope: 'global',
        service_type: service,
      })
      window.$message?.success(`${serviceMeta[service].label}模型目录已同步`)
    } finally {
      syncLoading[service] = false
    }
  }

  listLoading[service] = true
  try {
    const res = await api.getModelCatalogList({
      scope: 'global',
      service_type: service,
    })
    catalogByService[service] = Array.isArray(res.data) ? res.data : []
    recommendedByService[service] =
      catalogByService[service].find(item => item.is_recommended) || recommendedByService[service] || null
  } finally {
    listLoading[service] = false
  }
}

async function handleRecommend(service) {
  recommendLoading[service] = true
  try {
    const res = await api.recommendModelCatalog({
      scope: 'global',
      service_type: service,
      prioritize: prioritizeMap[service],
      need_image_input: serviceMeta[service].requireImageInput,
    })
    recommendedByService[service] = res.data?.recommended || null
    catalogByService[service] = Array.isArray(res.data?.items) ? res.data.items : catalogByService[service]
    if (recommendedByService[service]?.model_id) {
      window.$message?.success(`已推荐 ${recommendedByService[service].model_id}`)
    }
  } finally {
    recommendLoading[service] = false
  }
}

async function handleApply(service, modelId) {
  if (!modelId) return
  applyLoading.value = `${service}:${modelId}`
  try {
    await api.applyModelCatalog({
      scope: 'global',
      service_type: service,
      model_id: modelId,
    })
    window.$message?.success(`${serviceMeta[service].label}模型已应用`)
    await loadGlobalConfig()
    await loadCatalog(service)
  } finally {
    applyLoading.value = ''
  }
}

function createGlobalConfig() {
  return {
    image_model: '',
    video_model: '',
    speech_model: '',
    llm_model: '',
  }
}

function currentModel(service) {
  const fieldMap = {
    image: 'image_model',
    video: 'video_model',
    speech: 'speech_model',
    llm: 'llm_model',
  }
  return globalConfig.value[fieldMap[service]] || ''
}

function formatSource(item) {
  const sourceMap = {
    remote: '平台同步',
    curated: '系统推荐',
    current_config: '当前配置',
  }
  return sourceMap[item?.source_kind] || item?.source_kind || '模型目录'
}
</script>

<template>
  <CommonPage show-footer>
    <template #header>
      <div class="model-header">
        <div class="model-header__copy">
          <p class="model-header__eyebrow">模型管理</p>
          <h2>全局模型目录、推荐与应用</h2>
          <p>管理员在这里查看四类能力的全部模型，系统会按价格、速度、能力与适配度给出推荐，但也支持手动指定全局模型。</p>
        </div>
        <div class="model-header__actions">
          <NButton quaternary :loading="loadingGlobal" @click="loadGlobalConfig">刷新全局配置</NButton>
          <NButton type="primary" @click="loadCatalog(activeService, { syncFirst: true })">同步当前目录</NButton>
        </div>
      </div>
    </template>

    <div class="model-page">
      <section class="model-summary">
        <article v-for="item in summaryCards" :key="item.key" class="model-summary__card">
          <span>{{ item.label }}</span>
          <strong>{{ item.value }}</strong>
          <NTag :type="item.type" :round="false">当前全局模型</NTag>
        </article>
      </section>

      <section class="model-workspace">
        <div class="model-workspace__head">
          <div>
            <p class="model-workspace__eyebrow">能力分类</p>
            <h3>按能力单独管理模型</h3>
            <p>{{ currentMeta.description }}</p>
          </div>
          <div class="model-workspace__controls">
            <NSelect
              v-model:value="prioritizeMap[activeService]"
              :options="prioritizeOptions"
              style="width: 160px"
            />
            <NButton quaternary type="warning" :loading="recommendLoading[activeService]" @click="handleRecommend(activeService)">
              智能推荐
            </NButton>
          </div>
        </div>

        <NTabs v-model:value="activeService" type="segment" animated>
          <NTabPane v-for="(item, key) in serviceMeta" :key="key" :name="key" :tab="item.label">
            <div class="model-panels">
              <section class="model-panel">
                <p class="model-panel__eyebrow">当前应用</p>
                <h4>{{ currentModel(key) || '暂未应用' }}</h4>
                <p>当前所有普通用户、新生成任务以及后台 AI 调试台，都会默认走这一条模型链路。</p>
              </section>

              <section class="model-panel model-panel--highlight">
                <p class="model-panel__eyebrow">智能推荐</p>
                <template v-if="recommendedByService[key]">
                  <h4>{{ recommendedByService[key].model_id }}</h4>
                  <p>{{ recommendedByService[key].notes || formatSource(recommendedByService[key]) }}</p>
                  <small>
                    推荐分 {{ recommendedByService[key].recommendation_score || recommendedByService[key].capability_score || '--' }}
                    / 价格 {{ recommendedByService[key].price_level }}
                    / 速度 {{ recommendedByService[key].speed_level }}
                    / 质量 {{ recommendedByService[key].quality_level }}
                  </small>
                  <NButton type="primary" @click="handleApply(key, recommendedByService[key].model_id)">应用推荐模型</NButton>
                </template>
                <NEmpty v-else description="先点击智能推荐，系统会根据当前平台目录挑选最适合的模型" />
              </section>
            </div>

            <div class="model-toolbar">
              <NButton quaternary type="primary" :loading="syncLoading[key]" @click="loadCatalog(key, { syncFirst: true })">同步模型目录</NButton>
              <NButton quaternary @click="loadCatalog(key)">刷新列表</NButton>
            </div>

            <div v-if="catalogByService[key].length" class="model-list">
              <article v-for="model in catalogByService[key]" :key="`${key}-${model.model_id}`" class="model-card">
                <div class="model-card__copy">
                  <div class="model-card__top">
                    <strong>{{ model.model_id }}</strong>
                    <div class="model-card__tags">
                      <NTag v-if="model.is_current" type="primary" :round="false">当前生效</NTag>
                      <NTag v-if="model.is_recommended" type="warning" :round="false">推荐靠前</NTag>
                      <NTag :round="false">{{ formatSource(model) }}</NTag>
                    </div>
                  </div>
                  <span>{{ model.notes || '模型目录项' }}</span>
                  <small>
                    价格 {{ model.price_level }} / 速度 {{ model.speed_level }} / 质量 {{ model.quality_level }}
                  </small>
                </div>
                <div class="model-card__meta">
                  <div class="model-card__chips">
                    <NTag v-if="key === 'video'" :type="model.supports_image_input ? 'success' : 'default'" :round="false">
                      {{ model.supports_image_input ? '支持图生视频' : '纯文本视频' }}
                    </NTag>
                    <NTag v-if="Array.isArray(model.tags) && model.tags.length" :round="false">
                      {{ model.tags.slice(0, 2).join(' / ') }}
                    </NTag>
                  </div>
                  <NButton
                    type="primary"
                    :loading="applyLoading === `${key}:${model.model_id}`"
                    @click="handleApply(key, model.model_id)"
                  >
                    应用为全局模型
                  </NButton>
                </div>
              </article>
            </div>
            <NEmpty v-else :description="listLoading[key] ? '正在加载模型目录' : '暂无模型目录，先点击同步模型目录'" />
          </NTabPane>
        </NTabs>
      </section>
    </div>
  </CommonPage>
</template>

<style scoped>
.model-header,
.model-header__actions,
.model-workspace__head,
.model-workspace__controls,
.model-toolbar,
.model-card__top,
.model-card__meta,
.model-card__tags,
.model-card__chips {
  display: flex;
  gap: 12px;
}

.model-header,
.model-workspace__head,
.model-card__top,
.model-card__meta {
  justify-content: space-between;
}

.model-header,
.model-workspace__head {
  align-items: flex-end;
}

.model-header {
  width: 100%;
}

.model-header__copy {
  max-width: 760px;
}

.model-header__eyebrow,
.model-workspace__eyebrow,
.model-panel__eyebrow {
  margin: 0 0 8px;
  color: var(--brand-primary);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
}

.model-header h2,
.model-workspace h3,
.model-panel h4 {
  margin: 0;
  color: var(--app-text);
}

.model-header p:last-child,
.model-workspace__head p:last-child,
.model-panel p:last-child {
  margin: 10px 0 0;
  color: var(--app-muted);
  line-height: 1.7;
}

.model-page,
.model-summary,
.model-panels,
.model-list {
  display: grid;
  gap: 18px;
}

.model-summary {
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.model-summary__card,
.model-workspace,
.model-panel,
.model-card {
  border: 1px solid var(--shell-border);
  border-radius: 20px;
  background: rgba(255, 251, 248, 0.72);
  box-shadow: var(--soft-shadow);
  backdrop-filter: blur(18px);
}

.model-summary__card,
.model-panel,
.model-card {
  padding: 18px;
}

.model-summary__card,
.model-panel,
.model-card__copy {
  display: grid;
  gap: 8px;
}

.model-summary__card span,
.model-panel small,
.model-card span,
.model-card small {
  color: var(--app-muted);
}

.model-summary__card strong,
.model-panel h4,
.model-card strong {
  color: var(--app-text);
}

.model-workspace {
  padding: 22px;
}

.model-panels {
  grid-template-columns: repeat(2, minmax(0, 1fr));
  margin-bottom: 18px;
}

.model-panel--highlight {
  background: linear-gradient(135deg, rgba(255, 179, 106, 0.16), rgba(255, 251, 248, 0.78));
}

.model-toolbar {
  justify-content: flex-end;
  margin-bottom: 18px;
}

.model-list {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.model-card__meta,
.model-card__tags,
.model-card__chips {
  flex-wrap: wrap;
  align-items: flex-start;
}

@media (max-width: 1200px) {
  .model-summary,
  .model-panels,
  .model-list {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 768px) {
  .model-header,
  .model-workspace__head,
  .model-toolbar,
  .model-card__top,
  .model-card__meta {
    flex-direction: column;
    align-items: flex-start;
  }

  .model-header__actions,
  .model-workspace__controls {
    width: 100%;
    flex-direction: column;
  }
}
</style>
