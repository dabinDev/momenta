import { getToken } from '@/utils'
import { extractResponseMessage, resolveResError } from './helpers'
import { useUserStore } from '@/store'

export function reqResolve(config) {
  if (config.noNeedToken) {
    return config
  }

  const token = getToken()
  if (token) {
    config.headers.token = config.headers.token || token
  }

  return config
}

export function reqReject(error) {
  return Promise.reject(error)
}

export function resResolve(response) {
  const { data, status, statusText } = response
  if (data?.success === false || data?.code !== 200) {
    const code = data?.code ?? status
    const message = resolveResError(code, data?.msg ?? statusText, data)
    window.$message?.error(message, { keepAliveOnHover: true })
    return Promise.reject({ code, message, error: data || response })
  }
  return Promise.resolve(data)
}

export async function resReject(error) {
  if (!error || !error.response) {
    const code = error?.code
    const message = resolveResError(code, error?.message, error)
    window.$message?.error(message)
    return Promise.reject({ code, message, error })
  }

  const { data, status } = error.response

  if (data?.code === 401) {
    try {
      const userStore = useUserStore()
      userStore.logout()
    } catch (_) {
      return
    }
  }

  const code = data?.code ?? status
  const message = resolveResError(code, extractResponseMessage(data) || error.message, data)
  window.$message?.error(message, { keepAliveOnHover: true })
  return Promise.reject({ code, message, error: error.response?.data || error.response })
}
