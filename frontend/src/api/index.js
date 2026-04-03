import { request } from '@/utils'

export default {
  login: (data) => request.post('/base/access_token', data, { noNeedToken: true }),
  getUserInfo: () => request.get('/base/userinfo'),
  getUserMenu: () => request.get('/base/usermenu'),
  getUserApi: () => request.get('/base/userapi'),
  // profile
  updatePassword: (data = {}) => request.post('/base/update_password', data),
  updateCurrentProfile: (data = {}) => request.post('/base/update_profile', data),
  // users
  getUserList: (params = {}) => request.get('/user/list', { params }),
  getUserById: (params = {}) => request.get('/user/get', { params }),
  createUser: (data = {}) => request.post('/user/create', data),
  updateUser: (data = {}) => request.post('/user/update', data),
  deleteUser: (params = {}) => request.delete(`/user/delete`, { params }),
  resetPassword: (data = {}) => request.post(`/user/reset_password`, data),
  // role
  getRoleList: (params = {}) => request.get('/role/list', { params }),
  createRole: (data = {}) => request.post('/role/create', data),
  updateRole: (data = {}) => request.post('/role/update', data),
  deleteRole: (params = {}) => request.delete('/role/delete', { params }),
  updateRoleAuthorized: (data = {}) => request.post('/role/authorized', data),
  getRoleAuthorized: (params = {}) => request.get('/role/authorized', { params }),
  // menus
  getMenus: (params = {}) => request.get('/menu/list', { params }),
  createMenu: (data = {}) => request.post('/menu/create', data),
  updateMenu: (data = {}) => request.post('/menu/update', data),
  deleteMenu: (params = {}) => request.delete('/menu/delete', { params }),
  // apis
  getApis: (params = {}) => request.get('/api/list', { params }),
  createApi: (data = {}) => request.post('/api/create', data),
  updateApi: (data = {}) => request.post('/api/update', data),
  deleteApi: (params = {}) => request.delete('/api/delete', { params }),
  refreshApi: (data = {}) => request.post('/api/refresh', data),
  // depts
  getDepts: (params = {}) => request.get('/dept/list', { params }),
  createDept: (data = {}) => request.post('/dept/create', data),
  updateDept: (data = {}) => request.post('/dept/update', data),
  deleteDept: (params = {}) => request.delete('/dept/delete', { params }),
  // auditlog
  getAuditLogList: (params = {}) => request.get('/auditlog/list', { params }),
  // task center
  getTaskList: (params = {}) => request.get('/task/list', { params }),
  syncTask: (params = {}) => request.post('/task/sync', null, { params }),
  retryTask: (params = {}) => request.post('/task/retry', null, { params }),
  getVoiceLogList: (params = {}) => request.get('/voice_log/list', { params }),
  // user app config
  getUserAppConfigList: (params = {}) => request.get('/app_config/list', { params }),
  getUserAppConfigDetail: (params = {}) => request.get('/app_config/get', { params }),
  updateUserAppConfig: (data = {}) => request.post('/app_config/update', data),
  resetUserAppConfig: (data = {}) => request.post('/app_config/reset', data),
  // ai debug
  debugUploadImages: (data) =>
    request.post('/ai_debug/upload_images', data, {
      headers: { 'Content-Type': 'multipart/form-data' },
    }),
  debugPolishText: (data = {}) => request.post('/ai_debug/polish_text', data),
  debugGeneratePrompt: (data = {}) => request.post('/ai_debug/generate_prompt', data),
  debugCreateTask: (data = {}) => request.post('/ai_debug/create_task', data),
  debugTranscribe: (data) =>
    request.post('/ai_debug/transcribe', data, {
      headers: { 'Content-Type': 'multipart/form-data' },
    }),
  // app release
  getAppReleaseList: (params = {}) => request.get('/app_release/list', { params }),
  createAppRelease: (data = {}) => request.post('/app_release/create', data),
  updateAppRelease: (data = {}) => request.post('/app_release/update', data),
  deleteAppRelease: (params = {}) => request.delete('/app_release/delete', { params }),
}
