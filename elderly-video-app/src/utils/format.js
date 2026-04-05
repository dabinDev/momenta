const dateFormatter = new Intl.DateTimeFormat('zh-CN', {
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
})

export function formatDateTime(value) {
  if (!value) {
    return '--'
  }

  const date = typeof value === 'string' ? new Date(value) : value
  if (Number.isNaN(date.getTime())) {
    return String(value)
  }
  return dateFormatter.format(date)
}

export function formatDuration(seconds) {
  const value = Number(seconds || 0)
  if (!value) {
    return '--'
  }
  return `${value} 秒`
}

export function statusMeta(status) {
  switch (String(status || '').toLowerCase()) {
    case 'completed':
      return { label: '已完成', tone: 'success' }
    case 'failed':
      return { label: '已失败', tone: 'danger' }
    case 'queued':
      return { label: '排队中', tone: 'warn' }
    case 'processing':
      return { label: '生成中', tone: 'primary' }
    default:
      return { label: '处理中', tone: 'muted' }
  }
}
