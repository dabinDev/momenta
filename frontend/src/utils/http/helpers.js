import { useUserStore } from '@/store'

export function addBaseParams(params) {
  if (!params.userId) {
    params.userId = useUserStore().userId
  }
}

export function extractResponseMessage(payload) {
  if (payload == null) {
    return ''
  }

  if (typeof payload === 'string') {
    return payload.trim()
  }

  if (typeof payload !== 'object') {
    return String(payload).trim()
  }

  const candidate =
    payload.msg ??
    payload.message ??
    payload.detail ??
    payload.error?.message ??
    payload.error?.msg ??
    payload.error?.detail ??
    payload.error

  return extractResponseMessage(candidate)
}

export function resolveResError(code, message, payload) {
  const normalized = extractResponseMessage(payload ?? message)
  const safeMessage =
    !normalized || normalized.startsWith('{') || normalized.startsWith('[') || normalized === '[object Object]'
      ? null
      : normalized

  switch (code) {
    case 400:
      return safeMessage ?? '请求参数有误'
    case 401:
      return safeMessage ?? '登录已过期，请重新登录'
    case 403:
      return safeMessage ?? '当前账号没有权限执行该操作'
    case 404:
      return safeMessage ?? '请求的资源不存在'
    case 409:
      return safeMessage ?? '数据冲突，请检查后重试'
    case 422:
      return safeMessage ?? '提交参数校验失败，请检查后重试'
    case 500:
      return safeMessage ?? '服务异常，请稍后重试'
    default:
      return safeMessage ?? `请求失败（${code || '未知状态'}）`
  }
}
