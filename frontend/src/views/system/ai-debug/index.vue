<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'
import {
  NButton,
  NEmpty,
  NInput,
  NInputNumber,
  NSelect,
  NTag,
} from 'naive-ui'

import CommonPage from '@/components/page/CommonPage.vue'
import { formatDate } from '@/utils'
import { useUserStore } from '@/store'
import api from '@/api'

defineOptions({ name: 'AI 调试台' })

const userStore = useUserStore()

const loadingUsers = ref(false)
const userOptions = ref([])
const activeUserId = ref(null)
const targetConfig = ref(null)
const loadingTargetConfig = ref(false)
const textInput = ref('')
const polishedText = ref('')
const promptText = ref('')
const imageFiles = ref([])
const uploadedImageUrls = ref([])
const taskDuration = ref(5)
const createdTask = ref(null)
const audioFile = ref(null)
const transcribedText = ref('')
const lastPayload = ref(null)
const lastAction = ref('')
const latestResultTime = ref('')
const imageInputRef = ref(null)
const audioInputRef = ref(null)

const actionLoading = reactive({
  polish: false,
  prompt: false,
  upload: false,
  createTask: false,
  transcribe: false,
})

const activeUser = computed(() => userOptions.value.find(item => item.value === activeUserId.value)?.raw || null)
const activeUserLabel = computed(() => {
  const user = activeUser.value
  if (!user) return '未选择用户'
  return user.alias || user.username || '未命名用户'
})
const targetServiceItems = computed(() => [
  {
    label: '文本通道',
    configured: targetConfig.value?.llm_configured,
    title: targetConfig.value?.llm_model || '默认模型',
    desc: targetConfig.value?.llm_configured
      ? shortHost(targetConfig.value?.llm_base_url)
      : '未设置独立密钥，将走默认链路',
  },
  {
    label: '视频通道',
    configured: targetConfig.value?.video_configured,
    title: targetConfig.value?.video_model || '默认模型',
    desc: targetConfig.value?.video_configured
      ? shortHost(targetConfig.value?.video_base_url)
      : '未设置独立密钥，将走默认链路',
  },
])
const latestPayloadPretty = computed(() => {
  if (!lastPayload.value) return ''
  try {
    return JSON.stringify(lastPayload.value, null, 2)
  } catch (error) {
    return String(lastPayload.value)
  }
})
const selectedImageNames = computed(() => imageFiles.value.map(file => file.name))
const canRun = computed(() => Boolean(activeUserId.value))
const createdTaskMeta = computed(() => {
  if (!createdTask.value) return []
  return [
    { label: '任务类型', value: createdTask.value.task_type || '--' },
    { label: '当前状态', value: createdTask.value.status || '--' },
    { label: '上游服务', value: createdTask.value.provider || '--' },
    { label: '上游任务 ID', value: createdTask.value.provider_task_id || '--' },
    { label: '创建时间', value: createdTask.value.created_at ? formatDate(createdTask.value.created_at) : '--' },
  ]
})

watch(
  activeUserId,
  async (value) => {
    if (!value) {
      targetConfig.value = null
      return
    }
    await loadTargetConfig(value)
  },
  { immediate: false }
)

onMounted(async () => {
  await loadUsers()
})

async function loadUsers() {
  loadingUsers.value = true
  try {
    const res = await api.getUserList({ page: 1, page_size: 200 })
    const users = res.data || []
    userOptions.value = users.map(user => ({
      label: `${user.alias || user.username} @${user.username}`,
      value: user.id,
      raw: user,
    }))

    if (!activeUserId.value) {
      const preferredUser = users.find(user => user.id === userStore.userId)
      activeUserId.value = preferredUser?.id || users[0]?.id || null
    }
  } finally {
    loadingUsers.value = false
  }
}

async function loadTargetConfig(userId) {
  loadingTargetConfig.value = true
  try {
    const res = await api.getUserAppConfigDetail({ user_id: userId })
    targetConfig.value = res.data
  } finally {
    loadingTargetConfig.value = false
  }
}

async function handlePolish() {
  if (!ensureUser()) return
  if (!textInput.value.trim()) {
    window.$message?.warning('请先输入原始文案')
    return
  }

  actionLoading.polish = true
  try {
    const res = await api.debugPolishText({
      user_id: activeUserId.value,
      text: textInput.value.trim(),
    })
    polishedText.value = readTextPayload(res.data, ['text']) || polishedText.value
    captureResult('文案润色', res.data)
  } finally {
    actionLoading.polish = false
  }
}

async function handleGeneratePrompt() {
  if (!ensureUser()) return
  const sourceText = polishedText.value.trim() || textInput.value.trim()
  if (!sourceText) {
    window.$message?.warning('请先输入文案或先完成润色')
    return
  }

  actionLoading.prompt = true
  try {
    const res = await api.debugGeneratePrompt({
      user_id: activeUserId.value,
      text: sourceText,
    })
    promptText.value = readTextPayload(res.data, ['prompt', 'text']) || promptText.value
    captureResult('提示词生成', res.data)
  } finally {
    actionLoading.prompt = false
  }
}

async function handleUploadImages() {
  if (!ensureUser()) return
  if (!imageFiles.value.length) {
    window.$message?.warning('请先选择参考图片')
    return
  }

  const formData = new FormData()
  formData.append('user_id', String(activeUserId.value))
  imageFiles.value.forEach(file => formData.append('images', file))

  actionLoading.upload = true
  try {
    const res = await api.debugUploadImages(formData)
    uploadedImageUrls.value = readImageUrls(res.data)
    captureResult('图片上传', res.data)
    window.$message?.success('图片已上传')
  } finally {
    actionLoading.upload = false
  }
}

async function handleCreateTask() {
  if (!ensureUser()) return
  if (!promptText.value.trim()) {
    window.$message?.warning('请先生成或输入最终提示词')
    return
  }

  actionLoading.createTask = true
  try {
    const res = await api.debugCreateTask({
      user_id: activeUserId.value,
      input_text: textInput.value.trim() || null,
      polished_text: polishedText.value.trim() || null,
      prompt: promptText.value.trim(),
      images: uploadedImageUrls.value,
      duration: taskDuration.value || 5,
    })
    createdTask.value = res.data?.task || null
    captureResult('任务创建', res.data)
    window.$message?.success('调试任务已创建')
  } finally {
    actionLoading.createTask = false
  }
}

async function handleTranscribe() {
  if (!ensureUser()) return
  if (!audioFile.value) {
    window.$message?.warning('请先选择音频文件')
    return
  }

  const formData = new FormData()
  formData.append('user_id', String(activeUserId.value))
  formData.append('audio', audioFile.value)
  if (createdTask.value?.id) {
    formData.append('task_id', String(createdTask.value.id))
  }

  actionLoading.transcribe = true
  try {
    const res = await api.debugTranscribe(formData)
    transcribedText.value = readTextPayload(res.data, ['text']) || ''
    captureResult('语音识别', res.data)
  } finally {
    actionLoading.transcribe = false
  }
}

function triggerImagePicker() {
  imageInputRef.value?.click()
}

function triggerAudioPicker() {
  audioInputRef.value?.click()
}

function handleImageFilesChange(event) {
  imageFiles.value = Array.from(event.target.files || [])
  event.target.value = ''
}

function handleAudioFileChange(event) {
  audioFile.value = event.target.files?.[0] || null
  event.target.value = ''
}

function removeImageFile(index) {
  imageFiles.value.splice(index, 1)
}

function clearImages() {
  imageFiles.value = []
  uploadedImageUrls.value = []
}

function clearAudio() {
  audioFile.value = null
  transcribedText.value = ''
}

function captureResult(action, payload) {
  lastAction.value = action
  lastPayload.value = payload
  latestResultTime.value = new Date().toISOString()
}

function ensureUser() {
  if (activeUserId.value) return true
  window.$message?.warning('请先选择调试用户')
  return false
}

function readTextPayload(payload, keys = ['text']) {
  if (!payload) return ''
  if (typeof payload === 'string') return payload
  for (const key of keys) {
    if (typeof payload[key] === 'string' && payload[key].trim()) {
      return payload[key].trim()
    }
  }
  if (payload.data) return readTextPayload(payload.data, keys)
  if (payload.result) return readTextPayload(payload.result, keys)
  return ''
}

function readImageUrls(payload) {
  if (!payload) return []
  if (Array.isArray(payload)) return payload
  if (Array.isArray(payload.images)) return payload.images
  if (Array.isArray(payload.data?.images)) return payload.data.images
  if (Array.isArray(payload.result?.images)) return payload.result.images
  return []
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
      <div class="debug-header">
        <div class="debug-header__copy">
          <p class="debug-header__eyebrow">AI DEBUG</p>
          <h2>AI 调试台</h2>
          <p>把 app 里的上传、润色、提示词生成、建任务和语音识别统一放到 web 后台调试。</p>
        </div>
        <div class="debug-header__controls">
          <NSelect
            v-model:value="activeUserId"
            :loading="loadingUsers"
            :options="userOptions"
            filterable
            clearable
            placeholder="选择调试用户"
          />
          <NButton quaternary @click="loadUsers">刷新用户</NButton>
        </div>
      </div>
    </template>

    <div class="debug-page">
      <aside class="debug-sidebar">
        <section class="debug-sidebar__section">
          <p class="debug-sidebar__label">当前目标</p>
          <div class="debug-target">
            <strong>{{ activeUserLabel }}</strong>
            <span>{{ activeUser?.email || '未选择账号' }}</span>
          </div>

          <div class="debug-service-list">
            <div v-for="item in targetServiceItems" :key="item.label" class="debug-service">
              <div class="debug-service__top">
                <span>{{ item.label }}</span>
                <NTag :type="item.configured ? 'success' : 'default'" :round="false">
                  {{ item.configured ? '独立配置' : '默认配置' }}
                </NTag>
              </div>
              <strong>{{ item.title }}</strong>
              <small>{{ loadingTargetConfig ? '正在读取...' : item.desc }}</small>
            </div>
          </div>
        </section>

        <section class="debug-sidebar__section">
          <p class="debug-sidebar__label">最新返回</p>
          <div v-if="lastAction" class="debug-result-meta">
            <strong>{{ lastAction }}</strong>
            <span>{{ latestResultTime ? formatDate(latestResultTime) : '--' }}</span>
          </div>
          <pre v-if="latestPayloadPretty" class="debug-payload">{{ latestPayloadPretty }}</pre>
          <NEmpty v-else description="执行任一动作后，这里会显示返回内容" />
        </section>
      </aside>

      <div class="debug-main">
        <section class="debug-section">
          <div class="debug-section__header">
            <div>
              <p class="debug-section__eyebrow">文本链路</p>
              <h3>原始文案、润色结果与最终提示词</h3>
            </div>
            <div class="debug-section__actions">
              <NButton
                v-permission="'post/api/v1/ai_debug/polish_text'"
                type="primary"
                ghost
                :loading="actionLoading.polish"
                :disabled="!canRun"
                @click="handlePolish"
              >
                润色文案
              </NButton>
              <NButton
                v-permission="'post/api/v1/ai_debug/generate_prompt'"
                type="primary"
                :loading="actionLoading.prompt"
                :disabled="!canRun"
                @click="handleGeneratePrompt"
              >
                生成提示词
              </NButton>
            </div>
          </div>

          <div class="debug-text-grid">
            <div class="debug-block">
              <span>原始文案</span>
              <NInput
                v-model:value="textInput"
                type="textarea"
                :autosize="{ minRows: 7, maxRows: 10 }"
                placeholder="输入要交给 AI 处理的原始文案"
              />
            </div>
            <div class="debug-block">
              <span>润色结果</span>
              <NInput
                v-model:value="polishedText"
                type="textarea"
                :autosize="{ minRows: 7, maxRows: 10 }"
                placeholder="润色结果会回填到这里，也可以手动改写"
              />
            </div>
          </div>

          <div class="debug-block">
            <span>最终提示词</span>
            <NInput
              v-model:value="promptText"
              type="textarea"
              :autosize="{ minRows: 5, maxRows: 8 }"
              placeholder="最终发给视频生成模型的提示词"
            />
          </div>
        </section>

        <section class="debug-section">
          <div class="debug-section__header">
            <div>
              <p class="debug-section__eyebrow">图片链路</p>
              <h3>上传参考图并回收 URL</h3>
            </div>
            <div class="debug-section__actions">
              <input
                ref="imageInputRef"
                type="file"
                accept="image/*"
                multiple
                hidden
                @change="handleImageFilesChange"
              >
              <NButton quaternary @click="triggerImagePicker">选择图片</NButton>
              <NButton
                v-permission="'post/api/v1/ai_debug/upload_images'"
                type="primary"
                :loading="actionLoading.upload"
                :disabled="!imageFiles.length || !canRun"
                @click="handleUploadImages"
              >
                上传图片
              </NButton>
              <NButton quaternary :disabled="!imageFiles.length && !uploadedImageUrls.length" @click="clearImages">
                清空
              </NButton>
            </div>
          </div>

          <div class="debug-inline-list" v-if="selectedImageNames.length">
            <div v-for="(name, index) in selectedImageNames" :key="`${name}-${index}`" class="debug-chip">
              <span>{{ name }}</span>
              <button type="button" @click="removeImageFile(index)">移除</button>
            </div>
          </div>

          <div v-if="uploadedImageUrls.length" class="debug-image-grid">
            <div v-for="url in uploadedImageUrls" :key="url" class="debug-image-item">
              <img :src="url" alt="uploaded">
              <span>{{ url }}</span>
            </div>
          </div>
          <NEmpty v-else description="尚未上传参考图" />
        </section>

        <section class="debug-section">
          <div class="debug-section__header">
            <div>
              <p class="debug-section__eyebrow">任务链路</p>
              <h3>直接创建与 app 一致的视频任务</h3>
            </div>
            <div class="debug-task-bar">
              <span>时长</span>
              <NInputNumber v-model:value="taskDuration" :min="1" :max="60" style="width: 110px" />
              <NButton
                v-permission="'post/api/v1/ai_debug/create_task'"
                type="primary"
                :loading="actionLoading.createTask"
                :disabled="!canRun"
                @click="handleCreateTask"
              >
                创建任务
              </NButton>
            </div>
          </div>

          <div v-if="createdTask" class="debug-task-result">
            <div v-for="item in createdTaskMeta" :key="item.label" class="debug-task-result__item">
              <span>{{ item.label }}</span>
              <strong>{{ item.value }}</strong>
            </div>
            <div class="debug-task-result__item debug-task-result__item--wide">
              <span>视频地址</span>
              <a v-if="createdTask.video_url" :href="createdTask.video_url" target="_blank" rel="noreferrer">
                打开视频
              </a>
              <strong v-else>等待上游返回</strong>
            </div>
          </div>
          <NEmpty v-else description="创建后会在这里显示任务摘要" />
        </section>

        <section class="debug-section">
          <div class="debug-section__header">
            <div>
              <p class="debug-section__eyebrow">语音链路</p>
              <h3>验证 60 秒内语音识别接口</h3>
            </div>
            <div class="debug-section__actions">
              <input
                ref="audioInputRef"
                type="file"
                accept=".wav,.pcm,audio/wav,audio/*"
                hidden
                @change="handleAudioFileChange"
              >
              <NButton quaternary @click="triggerAudioPicker">选择音频</NButton>
              <NButton
                v-permission="'post/api/v1/ai_debug/transcribe'"
                type="primary"
                :loading="actionLoading.transcribe"
                :disabled="!audioFile || !canRun"
                @click="handleTranscribe"
              >
                开始识别
              </NButton>
              <NButton quaternary :disabled="!audioFile && !transcribedText" @click="clearAudio">清空</NButton>
            </div>
          </div>

          <div class="debug-voice-grid">
            <div class="debug-block">
              <span>当前音频</span>
              <p class="debug-file-text">{{ audioFile?.name || '未选择音频文件' }}</p>
            </div>
            <div class="debug-block">
              <span>识别结果</span>
              <p class="debug-voice-text">{{ transcribedText || '识别完成后将在这里展示文本' }}</p>
            </div>
          </div>
        </section>
      </div>
    </div>
  </CommonPage>
</template>

<style scoped>
.debug-header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 20px;
  width: 100%;
}

.debug-header__copy {
  max-width: 640px;
}

.debug-header__eyebrow,
.debug-sidebar__label,
.debug-section__eyebrow {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--brand-primary);
}

.debug-header h2,
.debug-section h3 {
  margin: 0;
  color: var(--app-text);
}

.debug-header__copy p:last-child,
.debug-section__header p:last-child {
  margin: 10px 0 0;
  color: var(--app-muted);
  line-height: 1.6;
}

.debug-header__controls {
  display: grid;
  grid-template-columns: minmax(280px, 360px) auto;
  gap: 12px;
}

.debug-page {
  display: grid;
  grid-template-columns: 320px minmax(0, 1fr);
  gap: 22px;
}

.debug-sidebar,
.debug-section {
  border: 1px solid var(--shell-border);
  background: var(--surface-card);
}

.debug-sidebar {
  display: grid;
  align-content: start;
}

.debug-sidebar__section {
  padding: 20px;
}

.debug-sidebar__section + .debug-sidebar__section {
  border-top: 1px solid var(--shell-divider);
}

.debug-target {
  display: grid;
  gap: 6px;
}

.debug-target strong,
.debug-service strong,
.debug-result-meta strong,
.debug-task-result__item strong,
.debug-block span,
.debug-section__header h3 {
  color: var(--app-text);
}

.debug-target span,
.debug-result-meta span,
.debug-service small,
.debug-task-result__item span,
.debug-file-text,
.debug-voice-text {
  color: var(--app-muted);
}

.debug-service-list {
  display: grid;
  gap: 16px;
  margin-top: 18px;
}

.debug-service {
  display: grid;
  gap: 8px;
}

.debug-service__top,
.debug-result-meta,
.debug-section__header,
.debug-task-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.debug-main {
  display: grid;
  gap: 18px;
}

.debug-section {
  display: grid;
  gap: 16px;
  padding: 18px;
}

.debug-section__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.debug-text-grid,
.debug-voice-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
}

.debug-block {
  display: grid;
  gap: 10px;
}

.debug-block > span {
  font-size: 13px;
  font-weight: 700;
}

.debug-inline-list {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.debug-chip {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  border: 1px solid var(--shell-border);
  background: var(--surface-overlay);
}

.debug-chip span {
  max-width: 240px;
  color: var(--app-text);
}

.debug-chip button {
  border: 0;
  background: transparent;
  color: var(--brand-primary);
  cursor: pointer;
}

.debug-image-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 14px;
}

.debug-image-item {
  display: grid;
  gap: 10px;
}

.debug-image-item img {
  width: 100%;
  aspect-ratio: 4 / 3;
  object-fit: cover;
  border: 1px solid var(--shell-border);
}

.debug-image-item span {
  color: var(--app-muted);
  line-height: 1.5;
  word-break: break-all;
}

.debug-task-result {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
}

.debug-task-result__item {
  display: grid;
  gap: 6px;
  padding-bottom: 14px;
  border-bottom: 1px solid var(--shell-divider);
}

.debug-task-result__item--wide {
  grid-column: 1 / -1;
}

.debug-task-result__item a {
  color: var(--brand-primary);
  font-weight: 700;
}

.debug-file-text,
.debug-voice-text {
  margin: 0;
  line-height: 1.7;
  white-space: pre-wrap;
}

.debug-payload {
  max-height: 480px;
  margin: 14px 0 0;
  padding: 14px;
  overflow: auto;
  border: 1px solid var(--shell-border);
  background: var(--surface-overlay);
  color: var(--app-text);
  font-size: 12px;
  line-height: 1.65;
}

@media (max-width: 1180px) {
  .debug-page {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 900px) {
  .debug-header {
    flex-direction: column;
    align-items: flex-start;
  }

  .debug-header__controls,
  .debug-text-grid,
  .debug-voice-grid,
  .debug-task-result,
  .debug-image-grid {
    grid-template-columns: 1fr;
  }

  .debug-section__header,
  .debug-task-bar {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
