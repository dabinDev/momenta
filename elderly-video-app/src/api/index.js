import { downloadRequest, request, requestEnvelope } from './http'

export function login(data) {
  return request({
    url: '/api/v1/base/access_token',
    method: 'post',
    data,
  })
}

export function registerAccount(data) {
  return requestEnvelope({
    url: '/api/v1/base/register',
    method: 'post',
    data,
  })
}

export function forgotPassword(data) {
  return requestEnvelope({
    url: '/api/v1/base/forgot_password',
    method: 'post',
    data,
  })
}

export function getCurrentUser() {
  return request({
    url: '/api/v1/base/userinfo',
    method: 'get',
  })
}

export function updateCurrentProfile(data) {
  return request({
    url: '/api/v1/base/update_profile',
    method: 'post',
    data,
  })
}

export function changePassword(data) {
  return requestEnvelope({
    url: '/api/v1/base/change_password',
    method: 'post',
    data,
  })
}

export function fetchWorkbench() {
  return request({
    url: '/api/create-workbench',
    method: 'get',
  })
}

export function correctText(data) {
  return request({
    url: '/api/correct-text',
    method: 'post',
    data,
  })
}

export function generatePrompt(data) {
  return request({
    url: '/api/generate-prompt',
    method: 'post',
    data,
  })
}

export function uploadImages(files) {
  const formData = new FormData()
  files.forEach((file) => {
    formData.append('images', file)
  })
  return request({
    url: '/api/upload-images',
    method: 'post',
    data: formData,
    headers: { 'Content-Type': 'multipart/form-data' },
  })
}

export function uploadReferenceVideo(file) {
  const formData = new FormData()
  formData.append('video', file)
  return request({
    url: '/api/upload-reference-video',
    method: 'post',
    data: formData,
    headers: { 'Content-Type': 'multipart/form-data' },
  })
}

export function transcribeAudio(file, taskId = null) {
  const formData = new FormData()
  formData.append('audio', file)
  if (taskId) {
    formData.append('task_id', taskId)
  }
  return request({
    url: '/api/voice/transcribe',
    method: 'post',
    data: formData,
    timeout: 180000,
    headers: { 'Content-Type': 'multipart/form-data' },
  })
}

export function createSimpleTask(data) {
  return request({
    url: '/api/tasks',
    method: 'post',
    data,
  })
}

export function createStarterTask(data) {
  return request({
    url: '/api/starter-tasks',
    method: 'post',
    data,
  })
}

export function createCustomTask(data) {
  return request({
    url: '/api/custom-tasks',
    method: 'post',
    data,
  })
}

export function getTask(taskId) {
  return request({
    url: `/api/tasks/${taskId}`,
    method: 'get',
  })
}

export function listTasks(params) {
  return request({
    url: '/api/tasks',
    method: 'get',
    params,
  })
}

export function getTaskSummary() {
  return request({
    url: '/api/tasks/summary',
    method: 'get',
  })
}

export function retryTask(taskId) {
  return request({
    url: `/api/tasks/${taskId}/retry`,
    method: 'post',
  })
}

export function deleteTask(taskId) {
  return requestEnvelope({
    url: `/api/tasks/${taskId}`,
    method: 'delete',
  })
}

export function clearTasks() {
  return requestEnvelope({
    url: '/api/tasks',
    method: 'delete',
  })
}

export function fetchInviteOverview() {
  return request({
    url: '/api/invite/overview',
    method: 'get',
  })
}

export function checkLatestRelease(params) {
  return request({
    url: '/api/app/releases/latest',
    method: 'get',
    params,
  })
}

export function downloadTaskVideo(taskId) {
  return downloadRequest({
    url: `/api/tasks/${taskId}/download`,
    method: 'get',
  })
}
