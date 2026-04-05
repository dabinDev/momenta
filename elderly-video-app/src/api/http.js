import axios from 'axios'

import { useAuthStore } from '@/stores/auth'

function parseErrorMessage(error) {
  const responseData = error?.response?.data
  if (responseData && typeof responseData === 'object') {
    return (
      responseData.msg ||
      responseData.error?.message ||
      responseData.detail ||
      '请求处理失败，请稍后重试'
    )
  }
  return error?.message || '请求处理失败，请稍后重试'
}

function createAppError(error) {
  const appError = new Error(parseErrorMessage(error))
  appError.status = error?.response?.status || 500
  appError.payload = error?.response?.data || null
  return appError
}

const http = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '',
  timeout: 120000,
})

http.interceptors.request.use((config) => {
  const authStore = useAuthStore()
  const token = authStore.token
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
    config.headers.token = token
  }
  return config
})

http.interceptors.response.use(
  (response) => response,
  (error) => {
    throw createAppError(error)
  }
)

function normalizePayload(payload) {
  if (payload?.success === false || Number(payload?.code || 200) >= 400) {
    const appError = new Error(payload?.msg || '请求处理失败，请稍后重试')
    appError.status = Number(payload?.code || 400)
    appError.payload = payload
    throw appError
  }
  return payload
}

export async function request(config) {
  const response = await http(config)
  const payload = normalizePayload(response.data)
  return payload?.data ?? null
}

export async function requestEnvelope(config) {
  const response = await http(config)
  return normalizePayload(response.data)
}

export async function downloadRequest(config) {
  return http({
    ...config,
    responseType: 'blob',
  })
}
