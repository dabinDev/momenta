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
  getUserMetrics: (params = {}) => request.get('/user/metrics', { params }),
  getUserById: (params = {}) => request.get('/user/get', { params }),
  createUser: (data = {}) => request.post('/user/create', data),
  updateUser: (data = {}) => request.post('/user/update', data),
  deleteUser: (params = {}) => request.delete(`/user/delete`, { params }),
  resetPassword: (data = {}) => request.post(`/user/reset_password`, data),
  giftUserPoints: (data = {}) => request.post('/user/gift_points', data),
  // invite codes
  getInviteCodeList: (params = {}) => request.get('/invite_code/list', { params }),
  createInviteCode: (data = {}) => request.post('/invite_code/create', data),
  updateInviteCode: (data = {}) => request.post('/invite_code/update', data),
  toggleInviteCode: (data = {}) => request.post('/invite_code/toggle', data),
  deleteInviteCode: (params = {}) => request.delete('/invite_code/delete', { params }),
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
  getPointLedgerList: (params = {}) => request.get('/point_ledger/list', { params }),
  getRechargeOrderList: (params = {}) => request.get('/recharge_order/list', { params }),
  updateRechargeOrderStatus: (data = {}) => request.post('/recharge_order/update_status', data),
  // user app config
  getGlobalAppConfig: () => request.get('/app_config/global'),
  updateGlobalAppConfig: (data = {}) => request.post('/app_config/global', data),
  resetGlobalAppConfig: () => request.post('/app_config/global/reset'),
  getEffectiveAppConfig: (params = {}) => request.get('/app_config/effective', { params }),
  getUserAppConfigList: (params = {}) => request.get('/app_config/list', { params }),
  getUserAppConfigDetail: (params = {}) => request.get('/app_config/get', { params }),
  updateUserAppConfig: (data = {}) => request.post('/app_config/update', data),
  resetUserAppConfig: (data = {}) => request.post('/app_config/reset', data),
  getModelCatalogList: (params = {}) => request.get('/model_catalog/list', { params }),
  syncModelCatalog: (data = {}) => request.post('/model_catalog/sync', data),
  recommendModelCatalog: (data = {}) => request.post('/model_catalog/recommend', data),
  applyModelCatalog: (data = {}) => request.post('/model_catalog/apply', data),
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
  uploadAppReleasePackage: (data) =>
    request.post('/app_release/upload_package', data, {
      headers: { 'Content-Type': 'multipart/form-data' },
      timeout: 120000,
    }),
}
