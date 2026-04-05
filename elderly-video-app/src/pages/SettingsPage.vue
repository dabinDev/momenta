<template>
  <div class="workspace">
    <article class="surface-card">
      <div class="profile-hero">
        <div class="profile-hero__avatar">
          <img v-if="user?.avatar" :src="user.avatar" :alt="user.displayName" />
          <span v-else>{{ avatarLetter }}</span>
        </div>
        <div>
          <h3>{{ user?.displayName || '未登录用户' }}</h3>
          <p>{{ user?.username ? `@${user.username}` : '请先登录账号' }}</p>
        </div>
      </div>

      <div class="settings-block">
        <div class="settings-row">
          <span>账号</span>
          <strong>{{ user?.username || '--' }}</strong>
        </div>
        <div class="settings-row">
          <span>手机号</span>
          <strong>{{ user?.phone || '未设置' }}</strong>
        </div>
        <div v-if="user?.pointsEnabled" class="settings-row">
          <span>当前积分</span>
          <strong>{{ user.pointsBalance }}</strong>
        </div>
        <div v-if="user?.pointsEnabled" class="settings-row">
          <span>视频生成</span>
          <strong>每次 {{ user.videoGenerationCost }} 积分</strong>
        </div>
      </div>

      <div class="entry-list">
        <button class="entry-item" type="button" @click="profileSheetOpen = true">
          <div>
            <strong>编辑资料</strong>
            <span>修改昵称、邮箱和手机号</span>
          </div>
          <span>›</span>
        </button>
        <button class="entry-item" type="button" @click="passwordSheetOpen = true">
          <div>
            <strong>修改密码</strong>
            <span>更新当前账号的登录密码</span>
          </div>
          <span>›</span>
        </button>
        <button class="entry-item" type="button" @click="openInviteCenter">
          <div>
            <strong>我的邀请</strong>
            <span>查看邀请码、邀请二维码和邀请记录</span>
          </div>
          <span>›</span>
        </button>
        <button class="entry-item" type="button" @click="openDownloadGuide">
          <div>
            <strong>App 下载</strong>
            <span>{{ releaseText }}</span>
          </div>
          <span>›</span>
        </button>
      </div>

      <div class="submit-wrap submit-wrap--settings">
        <button class="primary-btn primary-btn--muted" type="button" @click="logout">
          退出登录
        </button>
      </div>
    </article>

    <AppSheet
      v-model="profileSheetOpen"
      title="编辑资料"
      subtitle="保存后会立刻同步到当前账号。"
      eyebrow="个人资料"
      size="md"
    >
      <form class="form-stack" @submit.prevent="submitProfile">
        <label class="field">
          <span>昵称</span>
          <input v-model.trim="profileForm.alias" type="text" placeholder="请输入昵称" />
        </label>
        <label class="field">
          <span>邮箱</span>
          <input v-model.trim="profileForm.email" type="email" placeholder="请输入邮箱" />
        </label>
        <label class="field">
          <span>手机号</span>
          <input v-model.trim="profileForm.phone" type="text" placeholder="请输入手机号" />
        </label>
        <button class="primary-btn" type="submit" :disabled="profileSubmitting">
          {{ profileSubmitting ? '保存中...' : '保存资料' }}
        </button>
      </form>
    </AppSheet>

    <AppSheet
      v-model="passwordSheetOpen"
      title="修改密码"
      subtitle="修改成功后，下次登录使用新密码。"
      eyebrow="账号安全"
      size="md"
    >
      <form class="form-stack" @submit.prevent="submitPassword">
        <label class="field">
          <span>原密码</span>
          <input v-model.trim="passwordForm.oldPassword" type="password" placeholder="请输入原密码" />
        </label>
        <label class="field">
          <span>新密码</span>
          <input v-model.trim="passwordForm.newPassword" type="password" placeholder="请输入新密码" />
        </label>
        <label class="field">
          <span>确认新密码</span>
          <input v-model.trim="passwordForm.confirmPassword" type="password" placeholder="请再次输入新密码" />
        </label>
        <button class="primary-btn" type="submit" :disabled="passwordSubmitting">
          {{ passwordSubmitting ? '提交中...' : '修改密码' }}
        </button>
      </form>
    </AppSheet>

    <AppSheet
      v-model="inviteSheetOpen"
      title="我的邀请"
      subtitle="邀请码和邀请记录统一由后端维护。"
      eyebrow="邀请中心"
      size="lg"
      position="side"
    >
      <div v-if="inviteLoading" class="empty-placeholder">正在加载邀请码信息...</div>
      <div v-else class="invite-sheet">
        <div class="invite-sheet__hero">
          <div>
            <p class="eyebrow">当前邀请码</p>
            <h3>{{ inviteCode }}</h3>
            <p>已邀请 {{ inviteOverview?.summary?.total_invited_users || inviteOverview?.invited_users?.length || 0 }} 位用户</p>
          </div>
          <div class="invite-sheet__qr">
            <img v-if="inviteQrDataUrl" :src="inviteQrDataUrl" alt="邀请码二维码" />
          </div>
        </div>
        <div class="button-row">
          <button class="secondary-btn" type="button" @click="copyInviteCode">复制邀请码</button>
          <button class="secondary-btn" type="button" @click="copyInviteLink">复制注册链接</button>
        </div>
        <div class="invite-records">
          <div v-if="!inviteUsers.length" class="empty-placeholder">还没有邀请记录，分享二维码后新用户注册就会显示在这里。</div>
          <article v-for="item in inviteUsers" :key="item.id" class="invite-record">
            <div>
              <strong>{{ item.alias || item.username }}</strong>
              <p>{{ item.phone || item.email || '--' }}</p>
            </div>
            <span>{{ formatDateTime(item.created_at) }}</span>
          </article>
        </div>
      </div>
    </AppSheet>

    <AppSheet
      v-model="downloadSheetOpen"
      title="Android 下载"
      subtitle="H5 不参与版本更新检测，点击后直接获取 APK 下载链接。"
      eyebrow="App 下载"
      size="md"
    >
      <div class="download-guide">
        <div class="settings-block">
          <div class="settings-row">
            <span>最新版本</span>
            <strong>{{ latestVersion }}</strong>
          </div>
          <div class="settings-row">
            <span>下载地址</span>
            <strong class="download-guide__url">{{ apkDownloadUrl || '暂未配置' }}</strong>
          </div>
        </div>
        <p class="download-guide__hint">
          {{ wechatHint }}
        </p>
        <div class="button-row">
          <button class="primary-btn" type="button" @click="downloadApk">打开下载链接</button>
          <button class="secondary-btn" type="button" @click="copyApkLink">复制下载地址</button>
        </div>
      </div>
    </AppSheet>
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from 'vue'
import QRCode from 'qrcode'
import { useRouter } from 'vue-router'

import * as api from '@/api'
import AppSheet from '@/components/AppSheet.vue'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { formatDateTime } from '@/utils/format'
import { APP_TAB_RESELECT_EVENT } from '@/utils/events'
import { isWeChatBrowser, resolveApkDownloadUrl } from '@/utils/browser'

const router = useRouter()
const authStore = useAuthStore()
const toastStore = useToastStore()

const profileSheetOpen = ref(false)
const passwordSheetOpen = ref(false)
const inviteSheetOpen = ref(false)
const downloadSheetOpen = ref(false)
const profileSubmitting = ref(false)
const passwordSubmitting = ref(false)
const inviteLoading = ref(false)
const inviteOverview = ref(null)
const inviteQrDataUrl = ref('')

const profileForm = reactive({
  alias: '',
  email: '',
  phone: '',
})

const passwordForm = reactive({
  oldPassword: '',
  newPassword: '',
  confirmPassword: '',
})

const user = computed(() => authStore.user)
const avatarLetter = computed(() => (user.value?.displayName || '拾').slice(0, 1))
const inviteUsers = computed(() => inviteOverview.value?.invited_users || [])
const inviteCode = computed(() => inviteOverview.value?.primary_invite_code?.code || '--')
const apkDownloadUrl = computed(() => resolveApkDownloadUrl(authStore.latestRelease?.latest || authStore.latestRelease))
const latestVersion = computed(() => {
  const latest = authStore.latestRelease?.latest
  if (!latest) {
    return '暂未配置'
  }
  return latest.version_label || latest.version || '最新版本'
})
const releaseText = computed(() => (apkDownloadUrl.value ? '查看 APK 下载地址和版本信息' : '当前还没有可用下载地址'))
const wechatHint = computed(() =>
  isWeChatBrowser()
    ? '当前处于微信内打开环境，请先复制下载地址并在系统浏览器中打开。'
    : '建议在系统浏览器中下载并安装最新 Android 安装包。'
)

watch(
  user,
  (value) => {
    profileForm.alias = value?.alias || ''
    profileForm.email = value?.email || ''
    profileForm.phone = value?.phone || ''
  },
  { immediate: true }
)

async function ensureInviteQrCode() {
  if (!inviteCode.value || inviteCode.value === '--') {
    inviteQrDataUrl.value = ''
    return
  }
  const inviteLink = `${window.location.origin}/register?inviteCode=${encodeURIComponent(inviteCode.value)}`
  inviteQrDataUrl.value = await QRCode.toDataURL(inviteLink, {
    margin: 1,
    width: 180,
    color: {
      dark: '#302219',
      light: '#ffffff',
    },
  })
}

async function refreshProfile() {
  try {
    await authStore.fetchCurrentUser()
  } catch (error) {
    toastStore.push(error.message || '同步账号失败', 'danger')
  }
}

async function openInviteCenter() {
  inviteSheetOpen.value = true
  inviteLoading.value = true
  try {
    inviteOverview.value = await api.fetchInviteOverview()
    await ensureInviteQrCode()
  } catch (error) {
    toastStore.push(error.message || '读取邀请信息失败', 'danger')
  } finally {
    inviteLoading.value = false
  }
}

function openDownloadGuide() {
  downloadSheetOpen.value = true
}

async function submitProfile() {
  profileSubmitting.value = true
  try {
    await authStore.submitProfile({
      alias: profileForm.alias,
      email: profileForm.email,
      phone: profileForm.phone,
    })
    toastStore.push('资料已更新', 'success')
    profileSheetOpen.value = false
  } catch (error) {
    toastStore.push(error.message || '保存资料失败', 'danger')
  } finally {
    profileSubmitting.value = false
  }
}

async function submitPassword() {
  if (!passwordForm.oldPassword || !passwordForm.newPassword || !passwordForm.confirmPassword) {
    toastStore.push('请完整填写密码信息', 'warn')
    return
  }
  if (passwordForm.newPassword !== passwordForm.confirmPassword) {
    toastStore.push('两次输入的新密码不一致', 'danger')
    return
  }

  passwordSubmitting.value = true
  try {
    await authStore.submitPassword({
      old_password: passwordForm.oldPassword,
      new_password: passwordForm.newPassword,
    })
    toastStore.push('密码修改成功', 'success')
    passwordSheetOpen.value = false
    passwordForm.oldPassword = ''
    passwordForm.newPassword = ''
    passwordForm.confirmPassword = ''
  } catch (error) {
    toastStore.push(error.message || '修改密码失败', 'danger')
  } finally {
    passwordSubmitting.value = false
  }
}

async function copyInviteCode() {
  try {
    await navigator.clipboard.writeText(inviteCode.value)
    toastStore.push('邀请码已复制', 'success')
  } catch (_) {
    toastStore.push('复制失败，请手动长按复制', 'warn')
  }
}

async function copyInviteLink() {
  const inviteLink = `${window.location.origin}/register?inviteCode=${encodeURIComponent(inviteCode.value)}`
  try {
    await navigator.clipboard.writeText(inviteLink)
    toastStore.push('注册链接已复制', 'success')
  } catch (_) {
    toastStore.push('复制失败，请手动复制链接', 'warn')
  }
}

async function copyApkLink() {
  if (!apkDownloadUrl.value) {
    toastStore.push('当前没有可用下载地址', 'warn')
    return
  }
  try {
    await navigator.clipboard.writeText(apkDownloadUrl.value)
    toastStore.push('下载地址已复制', 'success')
  } catch (_) {
    toastStore.push('复制失败，请手动复制下载地址', 'warn')
  }
}

function downloadApk() {
  if (!apkDownloadUrl.value) {
    toastStore.push('当前没有可用下载地址', 'warn')
    return
  }
  if (isWeChatBrowser()) {
    copyApkLink()
    toastStore.push('请到系统浏览器中打开下载地址', 'warn', 3200)
    return
  }
  window.open(apkDownloadUrl.value, '_blank', 'noopener')
}

function logout() {
  authStore.logout()
  toastStore.push('已退出登录', 'success')
  router.replace('/login')
}

function handleTabReselect(event) {
  if (event.detail?.tab === 'settings') {
    refreshProfile()
  }
}

onMounted(() => {
  authStore.fetchLatestRelease()
  window.addEventListener(APP_TAB_RESELECT_EVENT, handleTabReselect)
})

onBeforeUnmount(() => {
  window.removeEventListener(APP_TAB_RESELECT_EVENT, handleTabReselect)
})
</script>
