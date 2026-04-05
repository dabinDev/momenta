import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

import * as api from '@/api'
import { clearSession, readToken, readUser, writeToken, writeUser } from '@/utils/storage'

const RELEASE_QUERY = {
  platform: 'android',
  channel: 'lan',
  current_version: '1.3.0',
  current_build_number: '4',
}

function normalizeUser(user) {
  const pointsSummary =
    user?.points_summary && typeof user.points_summary === 'object'
      ? user.points_summary
      : {}
  const featureFlags =
    user?.feature_flags && typeof user.feature_flags === 'object'
      ? user.feature_flags
      : {}

  const pointsEnabled =
    (user?.points_enabled ??
      featureFlags.points_enabled ??
      pointsSummary.points_enabled) !== false
  const rechargeEnabled =
    (user?.recharge_enabled ??
      featureFlags.recharge_enabled ??
      pointsSummary.recharge_enabled) === true
  const wechatPayEnabled =
    (user?.wechat_pay_enabled ??
      featureFlags.wechat_pay_enabled ??
      pointsSummary.wechat_pay_enabled) === true
  const alipayPayEnabled =
    (user?.alipay_pay_enabled ??
      featureFlags.alipay_pay_enabled ??
      pointsSummary.alipay_pay_enabled) === true
  const paymentEnabled =
    (user?.payment_enabled ?? pointsSummary.payment_enabled) === true

  return {
    ...user,
    displayName: String(user?.alias || user?.username || '未登录用户').trim() || '未登录用户',
    pointsBalance: Number(user?.points_balance ?? pointsSummary.points_balance ?? 0),
    totalPointsSpent: Number(
      user?.total_points_spent ?? pointsSummary.total_points_spent ?? 0
    ),
    totalPointsRecharged: Number(
      user?.total_points_recharged ?? pointsSummary.total_points_recharged ?? 0
    ),
    videoGenerationCost: Number(
      user?.video_generation_cost ?? pointsSummary.video_generation_cost ?? 0
    ),
    pointsEnabled,
    rechargeEnabled: pointsEnabled && rechargeEnabled,
    wechatPayEnabled: pointsEnabled && rechargeEnabled && wechatPayEnabled,
    alipayPayEnabled: pointsEnabled && rechargeEnabled && alipayPayEnabled,
    paymentEnabled: pointsEnabled && rechargeEnabled && paymentEnabled,
    paymentMethods: Array.isArray(user?.payment_methods)
      ? user.payment_methods
      : Array.isArray(pointsSummary.payment_methods)
        ? pointsSummary.payment_methods
        : [],
  }
}

export const useAuthStore = defineStore('auth', () => {
  const token = ref('')
  const user = ref(null)
  const latestRelease = ref(null)
  const hydrated = ref(false)

  const isLoggedIn = computed(() => Boolean(token.value))

  function hydrate() {
    if (hydrated.value) {
      return
    }
    token.value = readToken()
    const savedUser = readUser()
    user.value = savedUser ? normalizeUser(savedUser) : null
    hydrated.value = true
  }

  async function login(credentials) {
    const data = await api.login(credentials)
    token.value = data?.access_token || ''
    writeToken(token.value)
    await fetchCurrentUser()
    return user.value
  }

  async function fetchCurrentUser() {
    const profile = await api.getCurrentUser()
    user.value = normalizeUser(profile)
    writeUser(user.value)
    return user.value
  }

  async function refreshAppContext() {
    if (!token.value) {
      return
    }
    await Promise.allSettled([fetchCurrentUser(), fetchLatestRelease()])
  }

  async function fetchLatestRelease() {
    latestRelease.value = await api.checkLatestRelease(RELEASE_QUERY)
    return latestRelease.value
  }

  async function register(payload) {
    return api.registerAccount(payload)
  }

  async function submitForgotPassword(payload) {
    return api.forgotPassword(payload)
  }

  async function submitProfile(payload) {
    const profile = await api.updateCurrentProfile(payload)
    user.value = normalizeUser(profile)
    writeUser(user.value)
    return user.value
  }

  async function submitPassword(payload) {
    return api.changePassword(payload)
  }

  function logout() {
    token.value = ''
    user.value = null
    latestRelease.value = null
    clearSession()
  }

  return {
    token,
    user,
    latestRelease,
    isLoggedIn,
    hydrate,
    login,
    register,
    fetchCurrentUser,
    refreshAppContext,
    fetchLatestRelease,
    submitForgotPassword,
    submitProfile,
    submitPassword,
    logout,
  }
})
