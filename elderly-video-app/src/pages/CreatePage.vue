<template>
  <div class="workspace workspace--create">
    <section class="workspace-grid">
      <article class="surface-card">
        <div class="section-head">
          <div>
            <p class="eyebrow">创作内容</p>
            <h3>{{ modeInfo.title || modeInfo.label || 'AI 快速创作' }}</h3>
            <p>{{ modeInfo.subtitle || '先输入内容，再完成语音转文字、AI 校准和提示词生成。' }}</p>
          </div>
          <button class="secondary-btn" type="button" @click="modeSheetOpen = true">
            {{ modeInfo.label || '切换模式' }}
          </button>
        </div>

        <div class="chip-row">
          <span v-for="item in modeInfo.highlights || []" :key="item" class="chip">{{ item }}</span>
        </div>

        <div class="form-stack">
          <label class="field">
            <span>输入内容</span>
            <textarea
              v-model.trim="form.inputText"
              rows="5"
              :placeholder="contentPlaceholder"
            />
          </label>

          <label v-if="requiresReferenceLink" class="field">
            <span>视频链接</span>
            <input
              v-model.trim="form.referenceLink"
              type="url"
              placeholder="例如：https://www.douyin.com/..."
            />
            <small>复制公开视频链接后，后端会结合上传图片生成相关视频。</small>
          </label>

          <div class="action-grid">
            <button class="secondary-btn" type="button" :disabled="recording.busy" @click="handleVoiceInput">
              {{ recording.active ? `录音中 ${recording.seconds}s` : recording.busy ? '识别中...' : '语音转文字' }}
            </button>
            <button class="secondary-btn" type="button" :disabled="correcting" @click="handleCorrect">
              {{ correcting ? '校准中...' : 'AI 校准' }}
            </button>
            <button class="secondary-btn" type="button" :disabled="prompting" @click="handleGeneratePrompt">
              {{ prompting ? '生成中...' : '生成提示词' }}
            </button>
          </div>

          <label class="field">
            <span>英文提示词</span>
            <textarea
              v-model.trim="form.prompt"
              rows="6"
              placeholder="例如：Warm family moment, cozy indoor lighting, natural expressions..."
            />
          </label>
        </div>
      </article>

      <article class="surface-card">
        <div class="section-head">
          <div>
            <p class="eyebrow">素材与生成</p>
            <h3>{{ modeAssetTitle }}</h3>
            <p>{{ modeAssetSubtitle }}</p>
          </div>
          <button class="ghost-btn" type="button" :disabled="loadingWorkbench" @click="loadWorkbench">
            {{ loadingWorkbench ? '刷新中...' : '刷新配置' }}
          </button>
        </div>

        <section v-if="isCustomMode" class="block-stack">
          <div class="inline-head">
            <div>
              <h4>模板选择</h4>
              <p>按模板生成目标视频，支持查看样片后再应用。</p>
            </div>
          </div>
          <div class="template-list">
            <button
              v-for="template in videoTemplates"
              :key="template.key"
              class="template-card"
              :class="{ 'is-active': form.selectedVideoTemplateKey === template.key }"
              type="button"
              @click="selectTemplate(template)"
            >
              <div>
                <strong>{{ template.name }}</strong>
                <p>{{ template.description || '暂无模板描述' }}</p>
              </div>
              <div class="template-card__actions">
                <span v-if="template.popularity" class="template-rank">热度 {{ template.popularity }}</span>
                <span v-if="template.preview_video_url" class="template-link">可预览</span>
              </div>
            </button>
          </div>
          <div v-if="selectedTemplate?.preview_video_url" class="button-row">
            <button class="secondary-btn" type="button" @click="openPreview(selectedTemplate.preview_video_url)">
              查看样片
            </button>
          </div>
        </section>

        <section class="block-stack">
          <div class="inline-head">
            <div>
              <h4>视频时长</h4>
              <p>默认使用后端下发时长，可随时切换。</p>
            </div>
          </div>
          <div class="chip-row">
            <button
              v-for="duration in durations"
              :key="duration"
              class="chip chip--button"
              :class="{ 'is-active': form.duration === duration }"
              type="button"
              @click="form.duration = duration"
            >
              {{ duration }} 秒
            </button>
          </div>
        </section>

        <section class="block-stack">
          <div class="inline-head">
            <div>
              <h4>参考图片</h4>
              <p>最多上传 3 张图片，和 App 工作流保持一致。</p>
            </div>
            <label class="secondary-btn secondary-btn--file">
              选择图片
              <input type="file" accept="image/*" multiple @change="handleImagesSelected" />
            </label>
          </div>
          <div class="upload-grid">
            <div
              v-for="(image, index) in imageSlots"
              :key="image?.id || `slot-${index}`"
              class="upload-tile"
              :class="{ 'upload-tile--empty': !image }"
            >
              <template v-if="image">
                <img :src="image.url" :alt="image.name" />
                <button type="button" class="upload-remove" @click="removeImage(index)">×</button>
              </template>
              <template v-else>
                <span>图片 {{ index + 1 }}</span>
                <small>待上传</small>
              </template>
            </div>
          </div>
        </section>

        <section v-if="isCustomMode" class="block-stack">
          <div class="inline-head">
            <div>
              <h4>参考短视频</h4>
              <p>仅自定义模式支持，时长建议在 1 分钟以内。</p>
            </div>
            <label class="secondary-btn secondary-btn--file">
              {{ uploadingReferenceVideo ? '上传中...' : '选择视频' }}
              <input
                type="file"
                accept="video/*"
                :disabled="uploadingReferenceVideo"
                @change="handleReferenceVideoSelected"
              />
            </label>
          </div>
          <div class="reference-video-card" :class="{ 'is-active': Boolean(referenceVideo.url) }">
            <strong>{{ referenceVideo.name || '尚未上传参考视频' }}</strong>
            <span>
              {{ referenceVideo.url ? '已上传成功，生成时会自动带上 reference_video_path。' : '上传后会在自定义模式中随任务一并提交。' }}
            </span>
          </div>
        </section>

        <div class="submit-wrap">
          <button class="primary-btn" type="button" :disabled="submitting" @click="submitTask">
            {{ submitLabel }}
          </button>
        </div>

        <section v-if="currentTask" class="task-panel">
          <div class="task-panel__head">
            <StatusPill :label="currentTaskStatus.label" :tone="currentTaskStatus.tone" />
            <strong>{{ currentTaskStatusText }}</strong>
          </div>
          <div class="progress-track">
            <div class="progress-fill" :style="{ width: `${Math.max(8, Math.round(currentTaskProgress))}%` }"></div>
          </div>
          <div class="task-panel__meta">
            <span v-if="currentTask.duration">{{ currentTask.duration }} 秒</span>
            <span v-if="currentTaskPointsLabel">{{ currentTaskPointsLabel }}</span>
          </div>
          <div v-if="currentTask.status === 'completed'" class="button-row">
            <button class="secondary-btn" type="button" @click="openPreview(currentTask.video_url || currentTask.videoUrl)">
              播放结果
            </button>
            <button class="secondary-btn" type="button" @click="handleDownloadTask(currentTask)">
              下载视频
            </button>
          </div>
          <p v-if="currentTask.error_message || currentTask.errorMessage" class="task-card__error">
            {{ currentTask.error_message || currentTask.errorMessage }}
          </p>
        </section>
      </article>
    </section>

    <AppSheet
      v-model="modeSheetOpen"
      title="创作入口"
      subtitle="简单、入门、自定义三种入口与 App 保持统一。"
      eyebrow="模式切换"
      size="md"
    >
      <div class="mode-sheet-list">
        <button
          v-for="mode in modes"
          :key="mode.code"
          class="mode-sheet-item"
          :class="{ 'is-active': activeMode === mode.code }"
          type="button"
          @click="setActiveMode(mode.code)"
        >
          <div>
            <strong>{{ mode.label || mode.title }}</strong>
            <p>{{ mode.subtitle }}</p>
          </div>
          <span>{{ activeMode === mode.code ? '已选' : '切换' }}</span>
        </button>
      </div>
    </AppSheet>

    <VideoPreviewSheet
      v-model="preview.visible"
      :url="preview.url"
      @download="previewTaskDownload"
    />
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue'

import * as api from '@/api'
import AppSheet from '@/components/AppSheet.vue'
import StatusPill from '@/components/StatusPill.vue'
import VideoPreviewSheet from '@/components/VideoPreviewSheet.vue'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { isWeChatBrowser, resolveApkDownloadUrl } from '@/utils/browser'
import { APP_TAB_RESELECT_EVENT } from '@/utils/events'
import { createWavRecorder } from '@/utils/wavRecorder'
import { statusMeta } from '@/utils/format'

const authStore = useAuthStore()
const toastStore = useToastStore()

const loadingWorkbench = ref(false)
const correcting = ref(false)
const prompting = ref(false)
const submitting = ref(false)
const uploadingReferenceVideo = ref(false)
const modeSheetOpen = ref(false)
const recorderInstance = ref(null)
const pollTimer = ref(null)

const preview = reactive({
  visible: false,
  url: '',
  task: null,
})

const recording = reactive({
  active: false,
  busy: false,
  seconds: 0,
})

const form = reactive({
  inputText: '',
  prompt: '',
  referenceLink: '',
  duration: 5,
  selectedPromptTemplateKey: '',
  selectedVideoTemplateKey: '',
})

const currentTask = ref(null)
const workbench = ref(null)
const activeMode = ref('simple')
const uploadedImages = ref([])
const referenceVideo = reactive({
  url: '',
  name: '',
})

const modes = computed(() => workbench.value?.modes || [])
const videoTemplates = computed(() => workbench.value?.video_templates || [])
const durations = computed(() => workbench.value?.durations?.length ? workbench.value.durations : [5, 10, 20])
const modeInfo = computed(
  () =>
    modes.value.find((item) => item.code === activeMode.value) || {
      code: activeMode.value,
      label: activeMode.value === 'starter' ? '入门' : activeMode.value === 'custom' ? '自定义' : '简单',
      title: activeMode.value === 'starter' ? '链接入门创作' : activeMode.value === 'custom' ? '模板自定义创作' : 'AI 快速创作',
      subtitle:
        activeMode.value === 'starter'
          ? '在简单模式基础上增加视频链接输入。'
          : activeMode.value === 'custom'
            ? '在入门模式基础上增加模板和参考视频。'
            : '输入内容后完成语音转文字、AI 校准与视频生成。',
      highlights:
        activeMode.value === 'starter'
          ? ['视频链接', '上传图片', '快速跟做']
          : activeMode.value === 'custom'
            ? ['热门模板', '样片预览', '参考短视频']
            : ['语音转文字', 'AI 校准', '少参数'],
    }
)
const isCustomMode = computed(() => activeMode.value === 'custom')
const requiresReferenceLink = computed(() => activeMode.value !== 'simple')
const selectedTemplate = computed(() =>
  videoTemplates.value.find((item) => item.key === form.selectedVideoTemplateKey)
)
const contentPlaceholder = computed(() => {
  switch (activeMode.value) {
    case 'starter':
      return '例如：参考目标视频的节奏，生成同主题但更适合长辈观看的版本。'
    case 'custom':
      return '例如：保留模板的镜头节奏与字幕样式，替换成我上传的人物和场景。'
    default:
      return '例如：参考我的照片，帮我生一段边吃热干面边跳舞的视频。'
  }
})
const modeAssetTitle = computed(() =>
  activeMode.value === 'custom' ? '模板与素材' : '素材与生成'
)
const modeAssetSubtitle = computed(() => {
  switch (activeMode.value) {
    case 'starter':
      return '链接、图片和提示词会一起提交给后端生成入门视频。'
    case 'custom':
      return '按模板结合图片、链接和参考视频生成目标视频。'
    default:
      return '上传最多 3 张图片，选择视频时长后直接发起生成。'
  }
})
const imageSlots = computed(() => {
  const slots = [...uploadedImages.value]
  while (slots.length < 3) {
    slots.push(null)
  }
  return slots.slice(0, 3)
})
const submitLabel = computed(() => {
  const suffix =
    authStore.user?.pointsEnabled && authStore.user?.videoGenerationCost > 0
      ? ` · ${authStore.user.videoGenerationCost}积分`
      : ''
  switch (activeMode.value) {
    case 'starter':
      return `生成入门视频${suffix}`
    case 'custom':
      return `生成模板视频${suffix}`
    default:
      return `生成视频${suffix}`
  }
})
const currentTaskStatus = computed(() => statusMeta(currentTask.value?.status))
const currentTaskProgress = computed(() =>
  Number(currentTask.value?.progress || (currentTask.value?.status === 'completed' ? 100 : 32))
)
const currentTaskStatusText = computed(() => {
  switch (currentTask.value?.status) {
    case 'completed':
      return '视频已生成完成'
    case 'failed':
      return '视频生成失败'
    case 'queued':
      return '任务已提交，正在排队'
    default:
      return '任务处理中，请稍候'
  }
})
const currentTaskPointsLabel = computed(() => {
  const cost = Number(currentTask.value?.points_cost ?? currentTask.value?.pointsCost ?? 0)
  if (cost <= 0) {
    return ''
  }
  const refunded =
    currentTask.value?.points_refunded === true ||
    currentTask.value?.pointsRefunded === true
  return refunded ? `已退回 ${cost} 积分` : `已扣 ${cost} 积分`
})

async function loadWorkbench() {
  loadingWorkbench.value = true
  try {
    workbench.value = await api.fetchWorkbench()
    const defaultMode = workbench.value?.default_mode || modes.value[0]?.code || 'simple'
    const supportedModes = Array.isArray(workbench.value?.modes)
      ? workbench.value.modes.map((item) => item.code)
      : []
    if (!supportedModes.includes(activeMode.value)) {
      activeMode.value = defaultMode
    }
    if (durations.value.length && !durations.value.includes(form.duration)) {
      form.duration = durations.value[0]
    }
    applyModeDefaults()
  } catch (error) {
    toastStore.push(error.message || '读取创作配置失败', 'danger')
  } finally {
    loadingWorkbench.value = false
  }
}

function applyModeDefaults() {
  const mode = modeInfo.value
  if (mode.default_prompt_template_key && !form.selectedPromptTemplateKey) {
    form.selectedPromptTemplateKey = mode.default_prompt_template_key
  }
  if (mode.default_video_template_key && !form.selectedVideoTemplateKey) {
    form.selectedVideoTemplateKey = mode.default_video_template_key
  }
  if (isCustomMode.value && selectedTemplate.value == null) {
    const fallback = videoTemplates.value.find((item) => item.is_default) || videoTemplates.value[0]
    if (fallback) {
      form.selectedVideoTemplateKey = fallback.key
      if (fallback.default_duration && durations.value.includes(fallback.default_duration)) {
        form.duration = fallback.default_duration
      }
    }
  }
}

function setActiveMode(modeCode) {
  activeMode.value = modeCode
  modeSheetOpen.value = false
  if (modeCode !== 'custom') {
    referenceVideo.url = ''
    referenceVideo.name = ''
  }
  applyModeDefaults()
}

function selectTemplate(template) {
  form.selectedVideoTemplateKey = template.key
  if (template.default_duration && durations.value.includes(template.default_duration)) {
    form.duration = template.default_duration
  }
}

function removeImage(index) {
  uploadedImages.value.splice(index, 1)
}

async function handleImagesSelected(event) {
  const fileList = Array.from(event.target.files || [])
  event.target.value = ''
  if (!fileList.length) {
    return
  }
  if (uploadedImages.value.length + fileList.length > 3) {
    toastStore.push('最多只能上传 3 张参考图', 'warn')
    return
  }

  try {
    const result = await api.uploadImages(fileList)
    const images = Array.isArray(result?.images) ? result.images : Array.isArray(result) ? result : []
    uploadedImages.value = [...uploadedImages.value, ...images].slice(0, 3)
    toastStore.push(`已上传 ${images.length} 张参考图`, 'success')
  } catch (error) {
    toastStore.push(error.message || '上传图片失败', 'danger')
  }
}

async function handleReferenceVideoSelected(event) {
  const file = event.target.files?.[0]
  event.target.value = ''
  if (!file) {
    return
  }

  uploadingReferenceVideo.value = true
  try {
    const result = await api.uploadReferenceVideo(file)
    referenceVideo.url = result?.path || result?.url || ''
    referenceVideo.name = result?.name || file.name
    toastStore.push('参考视频上传成功', 'success')
  } catch (error) {
    toastStore.push(error.message || '上传参考视频失败', 'danger')
  } finally {
    uploadingReferenceVideo.value = false
  }
}

async function handleCorrect() {
  if (!form.inputText) {
    toastStore.push('请先输入要校准的内容', 'warn')
    return
  }

  correcting.value = true
  try {
    const result = await api.correctText({ text: form.inputText })
    form.inputText = String(result?.text || result?.result || form.inputText)
    toastStore.push('AI 校准完成', 'success')
  } catch (error) {
    toastStore.push(error.message || 'AI 校准失败', 'danger')
  } finally {
    correcting.value = false
  }
}

async function handleGeneratePrompt() {
  const sourceText = form.inputText || form.prompt
  if (!sourceText) {
    toastStore.push('请先输入创作内容', 'warn')
    return
  }

  prompting.value = true
  try {
    const result = await api.generatePrompt({
      text: sourceText,
      prompt_template_key: form.selectedPromptTemplateKey || undefined,
    })
    form.prompt = String(result?.prompt || result?.text || result?.result || '')
    toastStore.push('提示词生成完成', 'success')
  } catch (error) {
    toastStore.push(error.message || '提示词生成失败', 'danger')
  } finally {
    prompting.value = false
  }
}

async function handleVoiceInput() {
  if (recording.active) {
    await stopRecordingAndTranscribe()
    return
  }

  recording.busy = true
  try {
    recorderInstance.value = await createWavRecorder({
      onSecond(second) {
        recording.seconds = second
      },
      maxSeconds: 60,
    })
    recording.active = true
    recording.seconds = 0
    toastStore.push('已开始录音，再点一次可结束并转文字', 'success')
  } catch (error) {
    toastStore.push(error.message || '当前浏览器无法使用麦克风', 'danger')
  } finally {
    recording.busy = false
  }
}

async function stopRecordingAndTranscribe() {
  if (!recorderInstance.value) {
    return
  }

  recording.busy = true
  try {
    const result = await recorderInstance.value.stop()
    recorderInstance.value = null
    recording.active = false
    if (!result?.blob) {
      toastStore.push('没有录到清晰声音，请重试', 'warn')
      return
    }

    const audioFile = new File([result.blob], 'voice.wav', { type: 'audio/wav' })
    const transcription = await api.transcribeAudio(audioFile)
    const text = String(transcription?.text || '').trim()
    if (!text) {
      toastStore.push('未识别到清晰声音，请重试', 'warn')
      return
    }
    form.inputText = `${form.inputText ? `${form.inputText}\n` : ''}${text}`.trim()
    toastStore.push('语音已转成文字', 'success')
  } catch (error) {
    toastStore.push(error.message || '语音转文字失败', 'danger')
  } finally {
    recording.busy = false
    recording.seconds = 0
  }
}

function validateSubmit() {
  if (!form.prompt) {
    throw new Error('请先生成或填写视频提示词')
  }
  if (!uploadedImages.value.length) {
    throw new Error('请先上传至少 1 张参考图片')
  }
  if (requiresReferenceLink.value && !form.referenceLink) {
    throw new Error('请填写参考视频链接')
  }
  if (isCustomMode.value && !form.selectedVideoTemplateKey) {
    throw new Error('请选择视频模板')
  }
}

function readInsufficientPoints(error) {
  const message = String(error?.message || '')
  return message.includes('积分不足')
}

async function submitTask() {
  try {
    validateSubmit()
  } catch (error) {
    toastStore.push(error.message, 'warn')
    return
  }

  submitting.value = true
  try {
    const payload = {
      input_text: form.inputText || undefined,
      polished_text: undefined,
      prompt: form.prompt,
      images: uploadedImages.value.map((item) => item.path || item.url).filter(Boolean),
      duration: form.duration,
      prompt_template_key: form.selectedPromptTemplateKey || undefined,
      video_template_key: form.selectedVideoTemplateKey || undefined,
      reference_link: form.referenceLink || undefined,
      reference_video_path: referenceVideo.url || undefined,
    }

    let task
    if (activeMode.value === 'starter') {
      task = await api.createStarterTask(payload)
    } else if (activeMode.value === 'custom') {
      task = await api.createCustomTask(payload)
    } else {
      task = await api.createSimpleTask(payload)
    }

    currentTask.value = task
    startPolling()
    await authStore.fetchCurrentUser()
    toastStore.push('任务已提交，正在生成视频', 'success')
  } catch (error) {
    if (readInsufficientPoints(error)) {
      openDownloadSheet()
      return
    }
    toastStore.push(error.message || '视频生成失败', 'danger')
  } finally {
    submitting.value = false
  }
}

function startPolling() {
  stopPolling()
  if (!currentTask.value?.id) {
    return
  }
  pollTimer.value = window.setInterval(async () => {
    try {
      const task = await api.getTask(currentTask.value.id)
      currentTask.value = task
      if (task.status === 'completed' || task.status === 'failed') {
        stopPolling()
        await authStore.fetchCurrentUser()
      }
    } catch (_) {
      stopPolling()
    }
  }, 3000)
}

function stopPolling() {
  if (pollTimer.value) {
    window.clearInterval(pollTimer.value)
    pollTimer.value = null
  }
}

function openPreview(url, task = null) {
  preview.url = url || ''
  preview.task = task || currentTask.value
  preview.visible = true
}

async function handleDownloadTask(task) {
  const targetTask = task || currentTask.value
  if (!targetTask?.id) {
    return
  }

  if (isWeChatBrowser()) {
    openDownloadSheet()
    return
  }

  try {
    const response = await api.downloadTaskVideo(targetTask.id)
    const contentDisposition = response.headers['content-disposition'] || ''
    const matched = contentDisposition.match(/filename=\"?([^"]+)\"?/)
    const fileName = matched?.[1] || `拾光视频-${targetTask.id}.mp4`
    const url = window.URL.createObjectURL(response.data)
    const link = document.createElement('a')
    link.href = url
    link.download = decodeURIComponent(fileName)
    document.body.appendChild(link)
    link.click()
    link.remove()
    window.URL.revokeObjectURL(url)
    toastStore.push('视频开始下载', 'success')
  } catch (error) {
    toastStore.push(error.message || '视频下载失败', 'danger')
  }
}

function previewTaskDownload() {
  handleDownloadTask(preview.task)
}

function openDownloadSheet() {
  const latest = authStore.latestRelease?.latest || authStore.latestRelease
  const downloadUrl = resolveApkDownloadUrl(latest)
  if (!downloadUrl) {
    toastStore.push('当前还没有可用的 App 下载地址', 'warn')
    return
  }
  window.alert(`当前积分不足或微信内无法直接下载，请复制后到系统浏览器打开：\n${downloadUrl}`)
}

async function handleTabReselect(event) {
  if (event.detail?.tab !== 'create') {
    return
  }
  await loadWorkbench()
}

onMounted(async () => {
  await loadWorkbench()
  window.addEventListener(APP_TAB_RESELECT_EVENT, handleTabReselect)
})

onBeforeUnmount(async () => {
  stopPolling()
  window.removeEventListener(APP_TAB_RESELECT_EVENT, handleTabReselect)
  if (recorderInstance.value) {
    await recorderInstance.value.cancel()
  }
})
</script>
