const $ = (id) => document.getElementById(id);
const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));

const STORE_KEYS = {
  token: 'sg_video_auth_token',
  user: 'sg_video_auth_user',
  username: 'sg_video_auth_username',
};

const BrowserSpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition || null;

const FALLBACK_MODES = {
  simple: {
    code: 'simple',
    label: '简单',
    title: 'AI快速创作',
    subtitle: '输入内容后，完成语音转文字、AI校验、英文提示词生成和视频生成。',
    highlights: ['语音转文字', 'AI校验', '少参数'],
    default_prompt_template_key: '',
    default_video_template_key: 'warm_album',
  },
  starter: {
    code: 'starter',
    label: '入门',
    title: '链接入门创作',
    subtitle: '在简单模式基础上增加链接地址，结合图片快速生成相关视频。',
    highlights: ['视频链接', '上传图片', '快速跟做'],
    default_prompt_template_key: '',
    default_video_template_key: 'warm_album',
  },
  custom: {
    code: 'custom',
    label: '自定义',
    title: '模板自定义创作',
    subtitle: '在入门模式基础上增加模板选择，可按模板风格生成目标视频。',
    highlights: ['热门模板', '样片预览', '自定义生成'],
    default_prompt_template_key: 'family_memory',
    default_video_template_key: 'warm_album',
  },
};

const APP_LIMITS = {
  maxImages: 3,
  defaultDurations: [5, 10, 20],
  maxPollingTimes: 180,
  pollingIntervalMs: 3000,
  maxSpeechSeconds: 60,
  speechSampleRate: 16000,
};

const APP_META = Object.freeze({
  version: '1.2.0',
  buildNumber: '3',
  platform: 'android',
  channel: 'lan',
  updateHint: '如有新版本，重新安装新的 APK 即可覆盖更新。',
  apkDownloadUrl: 'https://memovideos.cn/file/V1.2.0.apk',
});

const state = {
  authToken: '',
  currentUser: null,
  workbench: null,
  activePage: 'create',
  activeCreateMode: 'simple',
  selectedDuration: APP_LIMITS.defaultDurations[0],
  selectedPromptTemplateKey: '',
  selectedVideoTemplateKey: '',
  selectedCustomTemplateKey: '',
  uploadedImages: [],
  uploadedReferenceVideo: null,
  historyPage: 1,
  currentVideoUrl: '',
  currentVideoTaskId: '',
  currentTask: null,
  historySummary: {
    total: 0,
    completed: 0,
    processing: 0,
    failed: 0,
  },
  latestUpdateInfo: null,
  isSubmitting: false,
  pollingCount: 0,
  pollTimer: null,
  isTranscribing: false,
  isUploadingReferenceVideo: false,
  lastRawTextBeforeCorrection: '',
  lastCorrectedText: '',
  recording: {
    active: false,
    recognition: null,
    seconds: 0,
    timer: null,
    finalText: '',
    interimText: '',
    shouldTranscribe: false,
    errorMessage: '',
  },
  wechatGuide: {
    copyValue: '',
    copySuccessText: '地址已复制，请到系统浏览器中打开',
  },
};

function safeParse(value, fallback) {
  if (!value) {
    return fallback;
  }
  try {
    return JSON.parse(value);
  } catch (_) {
    return fallback;
  }
}

function escapeHtml(value) {
  const div = document.createElement('div');
  div.textContent = value == null ? '' : String(value);
  return div.innerHTML;
}

function escapeAttr(value) {
  return escapeHtml(value).replace(/"/g, '&quot;');
}

function buildAccountMetaRows(user) {
  return [
    ['账号', user?.username || '未设置'],
    ['手机号', user?.phone || '--'],
    ['版本号', versionLabel()],
  ].map(([label, value]) => (
    `<div class="account-meta-row"><span class="account-meta-label">${escapeHtml(label)}</span><strong class="account-meta-value">${escapeHtml(value)}</strong></div>`
  )).join('');
}

function syncAccountSummary(user) {
  const displayName = user?.alias?.trim() || user?.username || '未登录用户';
  const usernameText = user?.username ? `@${user.username}` : '请先登录账号';
  const avatarText = (user?.alias?.trim() || user?.username || '拾').charAt(0) || '拾';
  const avatar = $('accountAvatar');
  if (avatar) {
    if (user?.avatar) {
      avatar.innerHTML = `<img src="${escapeAttr(user.avatar)}" alt="${escapeAttr(displayName)}">`;
    } else {
      avatar.textContent = avatarText;
    }
  }
  if ($('accountDisplayName')) {
    $('accountDisplayName').textContent = displayName;
  }
  if ($('accountUsername')) {
    $('accountUsername').textContent = usernameText;
  }
  if ($('sessionMeta')) {
    $('sessionMeta').innerHTML = buildAccountMetaRows(user);
  }
}

function compactPayload(payload) {
  return Object.fromEntries(
    Object.entries(payload).filter(([, value]) => {
      if (value == null) {
        return false;
      }
      if (typeof value === 'string') {
        return value.trim() !== '';
      }
      return true;
    }),
  );
}

function setHidden(target, shouldHide) {
  if (!target) {
    return;
  }
  target.classList.toggle('hidden', shouldHide);
}

function setDialogOpen(id, open) {
  const target = $(id);
  if (!target) {
    return;
  }
  setHidden(target, !open);
}

function isWeChatBrowser() {
  return /MicroMessenger/i.test(window.navigator.userAgent || '');
}

async function copyPlainText(value) {
  const text = String(value || '').trim();
  if (!text) {
    throw new Error('当前没有可复制的地址');
  }

  if (navigator.clipboard && window.isSecureContext) {
    await navigator.clipboard.writeText(text);
    return;
  }

  const textarea = document.createElement('textarea');
  textarea.value = text;
  textarea.setAttribute('readonly', 'readonly');
  textarea.style.position = 'fixed';
  textarea.style.opacity = '0';
  textarea.style.pointerEvents = 'none';
  document.body.appendChild(textarea);
  textarea.focus();
  textarea.select();
  const copied = document.execCommand('copy');
  textarea.remove();
  if (!copied) {
    throw new Error('复制失败，请手动长按复制地址');
  }
}

function openWechatGuide({
  title = '微信内暂不支持直接下载',
  subtitle = '请点击右上角“…”后选择“在浏览器打开”，再继续下载。',
  copyValue = window.location.href,
  copyLabel = '可复制地址',
  copyTip = '复制后请到系统浏览器中打开。',
  copySuccessText = '地址已复制，请到系统浏览器中打开',
} = {}) {
  state.wechatGuide = {
    copyValue: String(copyValue || window.location.href || '').trim(),
    copySuccessText: sanitizeUiMessage(copySuccessText, '地址已复制，请到系统浏览器中打开'),
  };
  if ($('wechatGuideTitle')) {
    $('wechatGuideTitle').textContent = title;
  }
  if ($('wechatGuideSubtitle')) {
    $('wechatGuideSubtitle').textContent = subtitle;
  }
  if ($('wechatGuideFieldLabel')) {
    $('wechatGuideFieldLabel').textContent = copyLabel;
  }
  if ($('wechatGuideCopyTip')) {
    $('wechatGuideCopyTip').textContent = copyTip;
  }
  if ($('wechatGuideCopyValue')) {
    $('wechatGuideCopyValue').value = state.wechatGuide.copyValue;
  }
  setDialogOpen('wechatGuideDialog', true);
}

function closeWechatGuide() {
  setDialogOpen('wechatGuideDialog', false);
}

async function copyWechatGuideValue() {
  try {
    await copyPlainText(state.wechatGuide.copyValue);
    showToast(state.wechatGuide.copySuccessText, 'success');
  } catch (error) {
    showToast(sanitizeUiMessage(error.message, '复制地址失败，请手动长按复制'), 'error');
  }
}

function interceptWeChatDownload(options = {}) {
  if (!isWeChatBrowser()) {
    return false;
  }
  openWechatGuide(options);
  return true;
}

function versionLabel() {
  return `V${APP_META.version} (${APP_META.buildNumber})`;
}

function showToast(message, type = 'info') {
  const toast = document.createElement('div');
  toast.className = `toast toast--${type}`;
  toast.textContent = sanitizeUiMessage(message);
  document.body.appendChild(toast);
  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(-8px)';
    toast.style.transition = 'opacity .2s ease, transform .2s ease';
    setTimeout(() => toast.remove(), 220);
  }, 2600);
}

function sanitizeUiMessage(message, fallback = '操作失败，请稍后重试。') {
  const text = String(message || '').trim();
  if (!text) {
    return fallback;
  }
  if (text.startsWith('{') || text.startsWith('[')) {
    return fallback;
  }
  return text;
}

function extractPayloadMessage(payload, fallback = '请求失败。') {
  if (payload == null) {
    return fallback;
  }
  if (typeof payload === 'string') {
    return sanitizeUiMessage(payload, fallback);
  }
  if (typeof payload !== 'object') {
    return sanitizeUiMessage(String(payload), fallback);
  }
  const candidate =
    payload.msg ??
    payload.message ??
    payload.detail ??
    payload.error?.message ??
    payload.error?.msg ??
    payload.error?.detail ??
    payload.error;
  return extractPayloadMessage(candidate, fallback);
}

function unwrapApiPayload(payload) {
  if (payload && typeof payload === 'object' && Object.prototype.hasOwnProperty.call(payload, 'data')) {
    return payload.data ?? {};
  }
  return payload;
}

function readSession() {
  state.authToken = localStorage.getItem(STORE_KEYS.token) || '';
  state.currentUser = safeParse(localStorage.getItem(STORE_KEYS.user) || '', null);
  const username = localStorage.getItem(STORE_KEYS.username) || '';
  const loginUsernameInput = $('loginUsername');
  if (username && loginUsernameInput && !loginUsernameInput.value) {
    loginUsernameInput.value = username;
  }
}

function saveSession(token, user, username) {
  state.authToken = token || '';
  state.currentUser = user || null;
  localStorage.setItem(STORE_KEYS.token, state.authToken);
  localStorage.setItem(STORE_KEYS.username, username || user?.username || '');
  if (user) {
    localStorage.setItem(STORE_KEYS.user, JSON.stringify(user));
  } else {
    localStorage.removeItem(STORE_KEYS.user);
  }
}

function clearSession() {
  state.authToken = '';
  state.currentUser = null;
  state.latestUpdateInfo = null;
  state.historySummary = {
    total: 0,
    completed: 0,
    processing: 0,
    failed: 0,
  };
  localStorage.removeItem(STORE_KEYS.token);
  localStorage.removeItem(STORE_KEYS.user);
}

async function apiFetch(url, options = {}, authRequired = true) {
  const headers = { ...(options.headers || {}) };
  const fetchOptions = {
    method: options.method || 'GET',
    headers,
  };

  if (options.body instanceof FormData) {
    fetchOptions.body = options.body;
  } else if (options.body !== undefined) {
    headers['Content-Type'] = headers['Content-Type'] || 'application/json';
    fetchOptions.body = JSON.stringify(options.body);
  }

  if (authRequired && state.authToken) {
    headers.Authorization = `Bearer ${state.authToken}`;
    headers.token = state.authToken;
  }

  const response = await fetch(url, fetchOptions);
  let payload = {};
  try {
    payload = await response.json();
  } catch (_) {
    payload = { success: false, msg: '服务返回了无效数据。' };
  }

  if (response.status === 401) {
    handleUnauthorized();
    throw new Error(extractPayloadMessage(payload, '登录已过期，请重新登录。'));
  }

  const isFailure =
    !response.ok ||
    payload.success === false ||
    (typeof payload.code === 'number' && payload.code !== 200);

  if (isFailure) {
    throw new Error(extractPayloadMessage(payload, '请求失败。'));
  }

  return unwrapApiPayload(payload);
}

function handleUnauthorized() {
  stopTaskPolling();
  clearSession();
  updateUserUI();
  renderHistorySummary();
  renderVersionInfo();
  ['editProfileDialog', 'changePasswordDialog', 'forgotPasswordDialog', 'registerDialog', 'wechatGuideDialog', 'videoModal'].forEach((id) => {
    setDialogOpen(id, false);
  });
  showLoginShell();
}

function showLoginShell() {
  setHidden($('authShell'), false);
}

function hideLoginShell() {
  setHidden($('authShell'), true);
}

function showLoginError(message) {
  $('authError').textContent = sanitizeUiMessage(message, '登录失败，请稍后重试。');
  $('authError').classList.add('active');
}

function clearLoginError() {
  $('authError').textContent = '';
  $('authError').classList.remove('active');
}

function renderHistorySummary() {
  const summary = state.historySummary || {};
  const items = [
    { label: '全部任务', value: Number(summary.total || 0), hint: '当前账号历史总数' },
    { label: '已完成', value: Number(summary.completed || 0), hint: '可播放和下载' },
    { label: '处理中', value: Number(summary.processing || 0), hint: '仍在生成中' },
    { label: '失败', value: Number(summary.failed || 0), hint: '需要重新发起' },
  ];
  $('historySummary').innerHTML = items.map((item) => `
    <div class="summary-pill">
      <strong>${escapeHtml(item.label)} · ${escapeHtml(item.value)}</strong>
      <span>${escapeHtml(item.hint)}</span>
    </div>
  `).join('');
}

function renderVersionInfo() {
  const info = state.latestUpdateInfo;
  const latest = info?.latest || null;
  const latestVersion = latest
    ? `V${latest.version_name || latest.versionName || '--'} (${latest.build_number || latest.buildNumber || '--'})`
    : '请点击下方按钮获取下载地址';
  const downloadUrl = String(
    latest?.download_url || latest?.downloadUrl || APP_META.apkDownloadUrl,
  ).trim();
  $('versionMeta').innerHTML = [
    `H5 版本：${escapeHtml(versionLabel())}`,
    `安卓安装包：${escapeHtml(latestVersion)}`,
    `发布渠道：${escapeHtml(APP_META.channel)}`,
    `下载地址：${escapeHtml(downloadUrl || '暂未配置')}`,
  ].map((item) => `<div>${item}</div>`).join('');
  $('updateNotes').textContent = String(
    latest?.release_notes
    || latest?.releaseNotes
    || 'H5 页面不参与版本更新检测，如需在安卓手机安装 App，请点击下方按钮获取 APK 下载链接。'
  ).trim() || APP_META.updateHint;
}

function updateUserUI() {
  syncAccountSummary(state.currentUser || null);
}

async function login() {
  clearLoginError();
  const username = $('loginUsername').value.trim();
  const password = $('loginPassword').value.trim();
  if (!username || !password) {
    showLoginError('请输入账号和密码。');
    return;
  }

  $('loginBtn').disabled = true;
  $('loginBtn').textContent = '登录中...';
  try {
    const result = await apiFetch('/api/auth/login', {
      method: 'POST',
      body: { username, password },
    }, false);
    saveSession(result.accessToken, result.user, result.username || username);
    $('loginPassword').value = '';
    updateUserUI();
    hideLoginShell();
    await bootstrapAfterLogin();
    showToast('登录成功。', 'success');
  } catch (error) {
    showLoginError(error.message || '登录失败。');
  } finally {
    $('loginBtn').disabled = false;
    $('loginBtn').textContent = '登录';
  }
}

async function logout() {
  stopTaskPolling();
  try {
    await apiFetch('/api/auth/logout', { method: 'POST' }, false);
  } catch (_) {
  }
  clearSession();
  updateUserUI();
  showLoginShell();
  showToast('已退出登录。', 'info');
}

async function restoreLogin() {
  if (!state.authToken) {
    return false;
  }
  try {
    const result = await apiFetch('/api/auth/me');
    saveSession(state.authToken, result.user, result.user?.username || '');
    updateUserUI();
    hideLoginShell();
    await bootstrapAfterLogin();
    return true;
  } catch (_) {
    handleUnauthorized();
    return false;
  }
}

async function bootstrapAfterLogin() {
  await Promise.all([loadWorkbench(), loadSettingsPage()]);
  if (state.activePage === 'history') {
    await loadHistory(1);
  }
}

function availableModes() {
  if (Array.isArray(state.workbench?.modes) && state.workbench.modes.length) {
    return state.workbench.modes.map((item) => String(item.code || '').trim()).filter(Boolean);
  }
  return ['simple', 'starter', 'custom'];
}

function getModeInfo(code) {
  const fallback = FALLBACK_MODES[code] || FALLBACK_MODES.simple;
  const fromWorkbench = Array.isArray(state.workbench?.modes)
    ? state.workbench.modes.find((item) => String(item.code || '').trim() === code)
    : null;
  return {
    ...fallback,
    ...(fromWorkbench || {}),
    highlights: Array.isArray(fromWorkbench?.highlights) && fromWorkbench.highlights.length
      ? fromWorkbench.highlights
      : fallback.highlights,
  };
}

function promptTemplates() {
  return Array.isArray(state.workbench?.prompt_templates) ? state.workbench.prompt_templates : [];
}

function videoTemplates() {
  return Array.isArray(state.workbench?.video_templates) ? state.workbench.video_templates : [];
}

function defaultTemplateKey(items) {
  if (!Array.isArray(items) || !items.length) {
    return '';
  }
  return items.find((item) => item.is_default)?.key || items[0]?.key || '';
}

function modeSupportsPromptTemplate(mode = state.activeCreateMode) {
  return mode === 'custom';
}

function defaultPromptTemplateKey(mode = state.activeCreateMode) {
  if (!modeSupportsPromptTemplate(mode)) {
    return '';
  }
  return String(getModeInfo(mode).default_prompt_template_key || defaultTemplateKey(promptTemplates()) || '');
}

function defaultVideoTemplateKey(mode = state.activeCreateMode) {
  return String(getModeInfo(mode).default_video_template_key || defaultTemplateKey(videoTemplates()) || '');
}

function findVideoTemplate(key) {
  return videoTemplates().find((item) => String(item.key || '') === String(key || '')) || null;
}

function ensureSelections(mode = state.activeCreateMode) {
  if (!state.selectedPromptTemplateKey || !modeSupportsPromptTemplate(mode)) {
    state.selectedPromptTemplateKey = state.selectedPromptTemplateKey || defaultPromptTemplateKey('custom');
  }
  if (!findVideoTemplate(state.selectedVideoTemplateKey)) {
    state.selectedVideoTemplateKey = defaultVideoTemplateKey(mode) || defaultVideoTemplateKey('simple');
  }
  if (!findVideoTemplate(state.selectedCustomTemplateKey)) {
    state.selectedCustomTemplateKey = defaultVideoTemplateKey('custom');
  }
  if (mode === 'starter') {
    state.selectedVideoTemplateKey = defaultVideoTemplateKey('starter') || state.selectedVideoTemplateKey;
  }
  syncDurationForMode(mode);
}

function syncDurationForMode(mode = state.activeCreateMode) {
  const durations = Array.isArray(state.workbench?.durations) && state.workbench.durations.length
    ? state.workbench.durations.map((item) => Number(item)).filter((item) => Number.isFinite(item))
    : APP_LIMITS.defaultDurations;
  if (!durations.includes(state.selectedDuration)) {
    state.selectedDuration = durations[0];
  }
  const template = mode === 'custom'
    ? findVideoTemplate(state.selectedCustomTemplateKey)
    : findVideoTemplate(state.selectedVideoTemplateKey);
  const defaultDuration = Number(template?.default_duration || template?.defaultDuration || 0);
  if (defaultDuration && durations.includes(defaultDuration)) {
    state.selectedDuration = defaultDuration;
  }
}

async function loadWorkbench() {
  try {
    const result = await apiFetch('/api/create-workbench');
    state.workbench = result.workbench || null;
    const supportedModes = availableModes();
    if (!supportedModes.includes(state.activeCreateMode)) {
      state.activeCreateMode = String(state.workbench?.default_mode || supportedModes[0] || 'simple');
    }
    ensureSelections(state.activeCreateMode);
  } catch (_) {
    state.workbench = null;
  }
  renderCreatePage();
}
function modeEyebrow(mode) {
  return {
    simple: 'SIMPLE',
    starter: 'STARTER',
    custom: 'CUSTOM',
  }[mode] || 'CREATE';
}

function contentPlaceholder(mode) {
  if (mode === 'starter') {
    return '例如：参考目标视频的节奏，生成同主题但更适合老年用户观看的版本。';
  }
  if (mode === 'custom') {
    return '例如：保留模板的镜头节奏和字幕风格，替换成我上传的人物和场景。';
  }
  return '例如：帮我做一条适合给家人分享的温暖短视频。';
}

function contentSubtitle(mode) {
  switch (mode) {
    case 'starter':
      return '在简单模式基础上补充视频链接地址，用于入门跟做。';
    case 'custom':
      return '在入门模式基础上增加模板选择，按模板生成目标视频。';
    default:
      return '先输入内容，再完成语音转文字、AI校验和英文提示词生成。';
  }
}

function assetsSubtitle(mode) {
  switch (mode) {
    case 'starter':
      return '链接、图片和提示词会一起提交给后端生成入门视频。';
    case 'custom':
      return '选择模板后，结合链接、图片和提示词生成自定义视频。';
    default:
      return '上传最多 3 张图片，选择视频时长后直接发起生成。';
  }
}

function submitLabel(mode) {
  switch (mode) {
    case 'starter':
      return '生成入门视频';
    case 'custom':
      return '生成模板视频';
    default:
      return '生成视频';
  }
}

function renderModeSheetList() {
  $('modeSheetList').innerHTML = availableModes().map((mode) => {
    const info = getModeInfo(mode);
    const isActive = mode === state.activeCreateMode;
    return `
      <button class="sheet-tile ${isActive ? 'active' : ''}" type="button" data-mode="${escapeAttr(mode)}">
        <div class="sheet-tile__head">
          <div>
            <div class="sheet-tile__title">${escapeHtml(info.label || info.title)}</div>
            <div class="sheet-tile__summary">${escapeHtml(info.subtitle || '')}</div>
          </div>
          <span class="sheet-tile__check">${isActive ? '✓' : ''}</span>
        </div>
        <div class="tag-row">
          ${(info.highlights || []).map((item) => `<span class="tag">${escapeHtml(item)}</span>`).join('')}
        </div>
      </button>
    `;
  }).join('');

  $$('[data-mode]', $('modeSheetList')).forEach((button) => {
    button.addEventListener('click', () => {
      closeModeSheet();
      setCreateMode(button.dataset.mode);
    });
  });
}

function renderDurationRow() {
  const durations = Array.isArray(state.workbench?.durations) && state.workbench.durations.length
    ? state.workbench.durations
    : APP_LIMITS.defaultDurations;
  $('durationRow').innerHTML = durations.map((duration) => `
    <button
      class="duration-chip ${Number(duration) === Number(state.selectedDuration) ? 'active' : ''}"
      type="button"
      data-duration="${escapeAttr(duration)}"
    >
      ${escapeHtml(duration)} 秒
    </button>
  `).join('');

  $$('[data-duration]', $('durationRow')).forEach((button) => {
    button.addEventListener('click', () => {
      state.selectedDuration = Number(button.dataset.duration || APP_LIMITS.defaultDurations[0]);
      renderDurationRow();
    });
  });
}

function renderImages() {
  const slots = [];
  for (let index = 0; index < APP_LIMITS.maxImages; index += 1) {
    const image = state.uploadedImages[index];
    if (image) {
      slots.push(`
        <div class="upload-slot">
          <img src="${escapeAttr(image.url)}" alt="参考图片 ${index + 1}">
          <button class="upload-remove" type="button" data-remove-image="${index}" aria-label="移除图片">×</button>
        </div>
      `);
    } else {
      slots.push(`
        <label class="upload-slot upload-slot--empty" for="imageInput">
          <div class="upload-slot__label">
            <strong>图片 ${index + 1}</strong>
            <span>点击继续上传</span>
          </div>
        </label>
      `);
    }
  }
  $('uploadGrid').innerHTML = slots.join('');
  $$('[data-remove-image]').forEach((button) => {
    button.addEventListener('click', () => {
      state.uploadedImages.splice(Number(button.dataset.removeImage || 0), 1);
      renderImages();
    });
  });
}

function renderReferenceVideo() {
  const wrap = $('referenceVideoWrap');
  if (!wrap) {
    return;
  }

  const modeInfo = getModeInfo(state.activeCreateMode);
  const supportsReferenceVideo =
    state.activeCreateMode === 'custom'
    && (modeInfo.supports_reference_video === true || modeInfo.supportsReferenceVideo === true || !state.workbench);

  setHidden(wrap, !supportsReferenceVideo);
  if (!supportsReferenceVideo) {
    return;
  }

  const uploaded = state.uploadedReferenceVideo;
  const isUploading = state.isUploadingReferenceVideo;
  $('referenceVideoCard').classList.toggle('reference-video-card--active', Boolean(uploaded));
  $('referenceVideoName').textContent = uploaded?.name || '尚未上传参考视频';
  $('referenceVideoTip').textContent = isUploading
    ? '正在上传参考视频，请稍候...'
    : uploaded?.url
      ? '已上传成功，生成时会自动带上 reference_video_path。'
      : '上传后会在自定义视频生成时自动提交给后端。';
  $('pickReferenceVideoBtn').disabled = isUploading;
  $('pickReferenceVideoBtn').textContent = isUploading
    ? '上传中...'
    : uploaded
      ? '重新选择'
      : '选择视频';
  $('removeReferenceVideoBtn').disabled = isUploading || !uploaded;
}

function renderTemplateGrid() {
  if (state.activeCreateMode !== 'custom') {
    $('templateGrid').innerHTML = '';
    return;
  }

  const templates = videoTemplates();
  if (!templates.length) {
    $('templateGrid').innerHTML = '<div class="empty-state">暂时没有可用模板，请刷新后重试。</div>';
    return;
  }

  $('templateGrid').innerHTML = templates.map((template) => {
    const isActive = String(template.key || '') === String(state.selectedCustomTemplateKey || '');
    const tags = Array.isArray(template.tags) ? template.tags : [];
    return `
      <article class="template-card ${isActive ? 'active' : ''}">
        <div class="template-head">
          <div>
            <h4>${escapeHtml(template.name || '未命名模板')}</h4>
            <p class="page-copy">${escapeHtml(template.description || template.preview || '')}</p>
          </div>
          ${template.popularity ? `<span class="template-rank">热度 ${escapeHtml(template.popularity)}</span>` : ''}
        </div>
        ${tags.length ? `<div class="tag-row">${tags.map((tag) => `<span class="tag">${escapeHtml(tag)}</span>`).join('')}</div>` : ''}
        <div class="template-actions">
          <button class="btn btn--outline btn--small" type="button" data-template-select="${escapeAttr(template.key)}">${isActive ? '已选模板' : '使用模板'}</button>
          ${template.preview_video_url ? `<button class="btn btn--ghost btn--small" type="button" data-template-preview="${escapeAttr(template.preview_video_url)}">查看样片</button>` : ''}
        </div>
      </article>
    `;
  }).join('');

  $$('[data-template-select]', $('templateGrid')).forEach((button) => {
    button.addEventListener('click', () => {
      state.selectedCustomTemplateKey = button.dataset.templateSelect || '';
      syncDurationForMode('custom');
      renderTemplateGrid();
      renderDurationRow();
    });
  });

  $$('[data-template-preview]', $('templateGrid')).forEach((button) => {
    button.addEventListener('click', () => {
      openModal(button.dataset.templatePreview || '', '模板样片');
    });
  });
}

function renderCreatePage() {
  const info = getModeInfo(state.activeCreateMode);
  $('createEyebrow').textContent = modeEyebrow(state.activeCreateMode);
  $('createSubtitle').textContent = info.subtitle || FALLBACK_MODES[state.activeCreateMode].subtitle;
  $('modeSwitchLabel').textContent = info.label || FALLBACK_MODES[state.activeCreateMode].label;
  $('contentSectionSubtitle').textContent = contentSubtitle(state.activeCreateMode);
  $('assetsSectionSubtitle').textContent = assetsSubtitle(state.activeCreateMode);
  $('inputText').placeholder = contentPlaceholder(state.activeCreateMode);
  $('generateBtn').textContent = state.isSubmitting ? '生成中，请稍候' : submitLabel(state.activeCreateMode);

  setHidden($('referenceLinkWrap'), state.activeCreateMode === 'simple');
  setHidden($('templateWrap'), state.activeCreateMode !== 'custom');

  $('referenceLinkTip').textContent = state.activeCreateMode === 'starter'
    ? '复制公开视频链接，后端会参考其节奏和结构。'
    : '自定义模式可选填公开视频链接，与模板一起辅助生成。';

  $('imageHint').textContent = state.activeCreateMode === 'simple'
    ? '3 个上传入口横向排布，点击空位可继续补图。'
    : '请上传 1 到 3 张参考图片。';

  renderModeSheetList();
  renderDurationRow();
  renderImages();
  renderReferenceVideo();
  renderTemplateGrid();
  renderTaskStatusPanel();
  renderVoiceButton();
}

function setCreateMode(mode) {
  if (!availableModes().includes(mode)) {
    return;
  }
  state.activeCreateMode = mode;
  ensureSelections(mode);
  renderCreatePage();
}

async function refreshTemplates() {
  try {
    await loadWorkbench();
    showToast('模板和创作配置已刷新。', 'success');
  } catch (error) {
    showToast(sanitizeUiMessage(error.message, '刷新模板失败。'), 'error');
  }
}

function clearCorrectionState() {
  state.lastRawTextBeforeCorrection = '';
  state.lastCorrectedText = '';
}

async function correctText() {
  const rawText = $('inputText').value.trim();
  if (!rawText) {
    showToast('请先输入或识别文字内容。', 'error');
    return;
  }

  $('correctBtn').disabled = true;
  $('correctBtn').textContent = '校验中';
  try {
    const result = await apiFetch('/api/correct-text', {
      method: 'POST',
      body: { text: rawText },
    });
    const corrected = String(result.text || '').trim();
    if (!corrected) {
      throw new Error('AI 校验结果为空，请稍后重试。');
    }
    state.lastRawTextBeforeCorrection = rawText;
    state.lastCorrectedText = corrected;
    $('inputText').value = corrected;
    showToast('已完成 AI 校验。', 'success');
  } catch (error) {
    showToast(sanitizeUiMessage(error.message, 'AI 校验失败。'), 'error');
  } finally {
    $('correctBtn').disabled = false;
    $('correctBtn').textContent = 'AI校验';
  }
}

async function generatePrompt() {
  const rawText = $('inputText').value.trim();
  if (!rawText) {
    showToast('请先输入或识别文字内容。', 'error');
    return;
  }

  $('promptBtn').disabled = true;
  $('promptBtn').textContent = '生成中';
  try {
    const result = await apiFetch('/api/generate-prompt', {
      method: 'POST',
      body: compactPayload({
        text: rawText,
        promptTemplateKey: modeSupportsPromptTemplate(state.activeCreateMode)
          ? (state.selectedPromptTemplateKey || defaultPromptTemplateKey(state.activeCreateMode))
          : '',
      }),
    });
    const prompt = String(result.prompt || '').trim();
    if (!prompt) {
      throw new Error('提示词生成结果为空，请稍后重试。');
    }
    $('promptText').value = prompt;
    showToast('创作提示词已生成，可继续修改。', 'success');
  } catch (error) {
    showToast(sanitizeUiMessage(error.message, '提示词生成失败。'), 'error');
  } finally {
    $('promptBtn').disabled = false;
    $('promptBtn').textContent = '生成提示词';
  }
}

async function uploadImages(files) {
  const remain = Math.max(APP_LIMITS.maxImages - state.uploadedImages.length, 0);
  if (remain <= 0) {
    showToast(`最多只能上传 ${APP_LIMITS.maxImages} 张图片。`, 'error');
    return;
  }
  if (!files.length) {
    return;
  }

  const formData = new FormData();
  files.slice(0, remain).forEach((file) => formData.append('images', file));

  try {
    const result = await apiFetch('/api/upload-images', {
      method: 'POST',
      body: formData,
    });
    state.uploadedImages = state.uploadedImages.concat(result.files || []).slice(0, APP_LIMITS.maxImages);
    renderImages();
    showToast('图片上传成功。', 'success');
  } catch (error) {
    showToast(sanitizeUiMessage(error.message, '图片上传失败。'), 'error');
  }
}

function clearReferenceVideo() {
  state.uploadedReferenceVideo = null;
  if ($('referenceVideoInput')) {
    $('referenceVideoInput').value = '';
  }
  renderReferenceVideo();
}

function readVideoDuration(file) {
  return new Promise((resolve, reject) => {
    const objectUrl = URL.createObjectURL(file);
    const video = document.createElement('video');
    video.preload = 'metadata';
    video.onloadedmetadata = () => {
      const duration = Number(video.duration || 0);
      URL.revokeObjectURL(objectUrl);
      resolve(duration);
    };
    video.onerror = () => {
      URL.revokeObjectURL(objectUrl);
      reject(new Error('无法读取参考视频时长，请更换文件后重试。'));
    };
    video.src = objectUrl;
  });
}

async function uploadReferenceVideo(file) {
  if (!file) {
    return;
  }
  if (!String(file.type || '').startsWith('video/')) {
    showToast('请选择可用的视频文件。', 'error');
    return;
  }

  try {
    const duration = await readVideoDuration(file);
    if (duration && duration > 60) {
      throw new Error('参考视频时长不能超过 1 分钟。');
    }
  } catch (error) {
    showToast(sanitizeUiMessage(error.message, '读取参考视频信息失败。'), 'error');
    return;
  }

  const formData = new FormData();
  formData.append('video', file);

  state.isUploadingReferenceVideo = true;
  renderReferenceVideo();
  try {
    const result = await apiFetch('/api/upload-reference-video', {
      method: 'POST',
      body: formData,
    });
    state.uploadedReferenceVideo = result.file || null;
    showToast('参考视频已上传。', 'success');
  } catch (error) {
    clearReferenceVideo();
    showToast(sanitizeUiMessage(error.message, '参考视频上传失败。'), 'error');
  } finally {
    state.isUploadingReferenceVideo = false;
    renderReferenceVideo();
  }
}

function isValidVideoUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch (_) {
    return false;
  }
}

function resolveCorrectedText(currentText) {
  if (!state.lastCorrectedText || currentText !== state.lastCorrectedText) {
    return '';
  }
  return state.lastCorrectedText;
}

function simplePayload() {
  const prompt = $('promptText').value.trim();
  if (!prompt) {
    throw new Error('请先生成或输入视频提示词。');
  }

  if (!state.uploadedImages.length) {
    throw new Error('请至少上传 1 张参考图片。');
  }

  const currentText = $('inputText').value.trim();
  const correctedText = resolveCorrectedText(currentText);
  return compactPayload({
    mode: 'simple',
    inputText: correctedText ? state.lastRawTextBeforeCorrection : currentText,
    polishedText: correctedText || '',
    prompt,
    images: state.uploadedImages.map((item) => item.url),
    duration: state.selectedDuration,
    videoTemplateKey: state.selectedVideoTemplateKey || defaultVideoTemplateKey('simple'),
  });
}

function starterPayload() {
  const referenceLink = $('referenceLink').value.trim();
  if (!isValidVideoUrl(referenceLink)) {
    throw new Error('请先输入可访问的视频链接。');
  }
  if (!state.uploadedImages.length) {
    throw new Error('入门模式至少上传 1 张图片。');
  }

  return compactPayload({
    mode: 'starter',
    inputText: $('inputText').value.trim(),
    prompt: $('promptText').value.trim(),
    images: state.uploadedImages.map((item) => item.url),
    duration: state.selectedDuration,
    referenceLink,
    videoTemplateKey: state.selectedVideoTemplateKey || defaultVideoTemplateKey('starter'),
  });
}

function customPayload() {
  if (!state.selectedCustomTemplateKey) {
    throw new Error('请先选择一个热门模板。');
  }
  if (!state.uploadedImages.length) {
    throw new Error('自定义模式至少上传 1 张图片。');
  }

  return compactPayload({
    mode: 'custom',
    inputText: $('inputText').value.trim(),
    prompt: $('promptText').value.trim(),
    images: state.uploadedImages.map((item) => item.url),
    duration: state.selectedDuration,
    referenceLink: $('referenceLink').value.trim(),
    referenceVideoPath: state.uploadedReferenceVideo?.url || '',
    promptTemplateKey: state.selectedPromptTemplateKey || defaultPromptTemplateKey('custom'),
    videoTemplateKey: state.selectedCustomTemplateKey,
  });
}

function buildGeneratePayload() {
  switch (state.activeCreateMode) {
    case 'starter':
      return starterPayload();
    case 'custom':
      return customPayload();
    default:
      return simplePayload();
  }
}

function statusDescriptor(status) {
  switch (status) {
    case 'completed':
      return { label: '已完成', className: 'status-chip status-chip--completed' };
    case 'failed':
      return { label: '失败', className: 'status-chip status-chip--failed' };
    default:
      return { label: '处理中', className: 'status-chip status-chip--processing' };
  }
}

function formatDate(value) {
  if (!value) {
    return '--';
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return date.toLocaleString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function effectiveTaskProgress() {
  if (state.currentTask?.status === 'completed') {
    return 1;
  }
  if (typeof state.currentTask?.progress === 'number' && state.currentTask.progress > 0) {
    return Math.min(1, Math.max(0, state.currentTask.progress));
  }
  if (!state.isSubmitting) {
    return 0;
  }
  return Math.min(0.94, Math.max(0.12, state.pollingCount / APP_LIMITS.maxPollingTimes));
}

function renderTaskStatusPanel() {
  const hasTask = Boolean(state.currentTask);
  const shouldShow = state.isSubmitting || hasTask;
  const taskStatusPanel = $('taskStatusPanel');
  setHidden(taskStatusPanel, !shouldShow);
  if (!shouldShow) {
    return;
  }

  const status = state.currentTask?.status || 'processing';
  const descriptor = statusDescriptor(status);
  $('taskStatusChip').className = descriptor.className;
  $('taskStatusChip').textContent = descriptor.label;

  const label = state.currentTask?.error
    ? sanitizeUiMessage(state.currentTask.error, '视频生成失败，请稍后重试。')
    : state.isSubmitting
      ? `正在跟进任务进度 ${state.pollingCount}/${APP_LIMITS.maxPollingTimes}`
      : state.currentTask?.id
        ? `任务编号：${state.currentTask.id}`
        : '任务处理中';
  $('taskStatusLabel').textContent = label;
  $('taskProgressFill').style.width = `${Math.round(effectiveTaskProgress() * 100)}%`;

  const metaLines = [
    state.currentTask?.mode ? `模式：${state.currentTask.mode}` : '',
    state.currentTask?.duration ? `时长：${state.currentTask.duration} 秒` : '',
    state.currentTask?.videoTemplateName ? `模板：${state.currentTask.videoTemplateName}` : '',
    state.currentTask?.createdAt ? `创建时间：${formatDate(state.currentTask.createdAt)}` : '',
  ].filter(Boolean);
  $('taskMeta').innerHTML = metaLines.map((line) => `<div>${escapeHtml(line)}</div>`).join('');

  const canPlay = Boolean(state.currentTask?.videoUrl && status === 'completed');
  taskStatusPanel.classList.toggle('task-status--clickable', canPlay);
  if (canPlay) {
    taskStatusPanel.setAttribute('tabindex', '0');
    taskStatusPanel.setAttribute('role', 'button');
    taskStatusPanel.setAttribute('title', '点击预览生成结果');
    taskStatusPanel.setAttribute('aria-label', '点击预览生成结果');
  } else {
    taskStatusPanel.removeAttribute('tabindex');
    taskStatusPanel.removeAttribute('role');
    taskStatusPanel.removeAttribute('title');
    taskStatusPanel.removeAttribute('aria-label');
  }
  const actions = $('taskActions');
  if (status === 'completed' && state.currentTask?.videoUrl) {
    actions.innerHTML = `
      <button class="btn btn--outline btn--small" type="button" data-task-action="play">播放结果</button>
      <button class="btn btn--outline btn--small" type="button" data-task-action="download">保存到本地</button>
    `;
    setHidden(actions, false);
  } else if (status === 'failed' && state.currentTask?.id) {
    actions.innerHTML = `
      <button class="btn btn--outline btn--small" type="button" data-task-action="retry">重新生成</button>
      <button class="btn btn--ghost btn--small" type="button" data-task-action="delete">删除</button>
    `;
    setHidden(actions, false);
  } else {
    actions.innerHTML = '';
    setHidden(actions, true);
  }
}

function setSubmitting(nextSubmitting) {
  state.isSubmitting = nextSubmitting;
  $('generateBtn').disabled = nextSubmitting;
  $('generateBtn').textContent = nextSubmitting ? '生成中，请稍候' : submitLabel(state.activeCreateMode);
  renderTaskStatusPanel();
}

function isProcessingLimitMessage(message) {
  const normalized = String(message || '').trim();
  return normalized.includes('当前已有视频正在处理')
    || normalized.includes('等待当前任务完成或失败后再试')
    || normalized.includes('当前发布请求正在提交')
    || normalized.includes('请勿重复点击');
}

async function restoreCurrentTaskFromHistory() {
  try {
    const result = await apiFetch('/api/history?page=1&limit=10');
    const records = Array.isArray(result.records) ? result.records : [];
    const processingTask = records.find((item) =>
      item && ['queued', 'processing'].includes(String(item.status || '').toLowerCase()));
    const latestTask = processingTask || records[0] || null;
    if (latestTask) {
      state.currentTask = latestTask;
      renderTaskStatusPanel();
    }
  } catch (_) {
    // Ignore follow-up refresh failures and keep the original feedback toast.
  }
}

function previewCurrentTask() {
  if (state.currentTask?.status !== 'completed' || !state.currentTask?.videoUrl) {
    return;
  }
  openModal(state.currentTask.videoUrl, '生成结果预览', state.currentTask.id || '');
}

async function downloadCurrentTask() {
  if (state.currentTask?.status !== 'completed' || !state.currentTask?.id) {
    showToast('当前没有可保存的视频。', 'error');
    return;
  }

  try {
    const started = await downloadTaskById(
      state.currentTask.id,
      '拾光视频',
      state.currentTask.videoUrl || '',
    );
    if (started) {
      showToast('视频已开始保存到本地。', 'success');
    }
  } catch (error) {
    showToast(sanitizeUiMessage(error.message, '保存视频失败。'), 'error');
  }
}

function openModal(url, title = '视频预览', taskId = '') {
  if (!url) {
    return;
  }
  state.currentVideoUrl = url;
  state.currentVideoTaskId = taskId || '';
  $('modalTitle').textContent = title;
  $('modalVideo').src = url;
  setHidden($('videoModal'), false);
  $('modalVideo').play().catch(() => {});
}

function closeModal() {
  $('modalVideo').pause();
  $('modalVideo').src = '';
  state.currentVideoTaskId = '';
  setHidden($('videoModal'), true);
}

function stopTaskPolling() {
  if (state.pollTimer) {
    clearInterval(state.pollTimer);
    state.pollTimer = null;
  }
}

function markTaskCompleted(task, modalTitle) {
  state.currentTask = task;
  setSubmitting(false);
  renderTaskStatusPanel();
  showToast('视频生成完成。', 'success');
  if (task.videoUrl) {
    openModal(task.videoUrl, modalTitle, task.id || '');
  }
  if (state.activePage === 'history') {
    loadHistory(state.historyPage);
  }
}

function markTaskFailed(task) {
  state.currentTask = task;
  setSubmitting(false);
  renderTaskStatusPanel();
  showToast(sanitizeUiMessage(task.error, '视频生成失败，请稍后重试。'), 'error');
  if (state.activePage === 'history') {
    loadHistory(state.historyPage);
  }
}

function startTaskPolling(taskId) {
  stopTaskPolling();
  state.pollingCount = 0;
  renderTaskStatusPanel();

  state.pollTimer = setInterval(async () => {
    state.pollingCount += 1;
    renderTaskStatusPanel();
    try {
      const result = await apiFetch(`/api/video-status/${taskId}`);
      state.currentTask = result.record || state.currentTask;
      renderTaskStatusPanel();

      if (state.currentTask?.status === 'completed') {
        stopTaskPolling();
        markTaskCompleted(state.currentTask, '生成结果预览');
        return;
      }
      if (state.currentTask?.status === 'failed') {
        stopTaskPolling();
        markTaskFailed(state.currentTask);
        return;
      }
    } catch (error) {
      stopTaskPolling();
      setSubmitting(false);
      showToast(sanitizeUiMessage(error.message, '任务状态查询失败。'), 'error');
      return;
    }

    if (state.pollingCount >= APP_LIMITS.maxPollingTimes) {
      stopTaskPolling();
      setSubmitting(false);
      showToast('视频生成超时，请稍后到记录页查看。', 'info');
    }
  }, APP_LIMITS.pollingIntervalMs);
}

async function generateVideo() {
  if (state.isSubmitting) {
    return;
  }
  let payload;
  try {
    payload = buildGeneratePayload();
  } catch (error) {
    showToast(sanitizeUiMessage(error.message, '提交参数不完整。'), 'error');
    return;
  }

  stopTaskPolling();
  if (!state.currentTask || !['queued', 'processing'].includes(String(state.currentTask.status || '').toLowerCase())) {
    state.currentTask = null;
  }
  state.pollingCount = 0;
  setSubmitting(true);

  try {
    const result = await apiFetch('/api/generate-video', {
      method: 'POST',
      body: payload,
    });
    state.currentTask = result.record || null;
    renderTaskStatusPanel();

    if (state.currentTask?.status === 'completed' && state.currentTask.videoUrl) {
      markTaskCompleted(state.currentTask, '生成结果预览');
      return;
    }
    if (!state.currentTask?.id) {
      throw new Error('未拿到任务编号，请稍后重试。');
    }
    startTaskPolling(state.currentTask.id);
  } catch (error) {
    setSubmitting(false);
    const message = error.message || '视频生成失败。';
    if (isProcessingLimitMessage(message)) {
      showToast(message, 'info');
      await restoreCurrentTaskFromHistory();
    } else {
      showToast(message, 'error');
    }
  }
}

function renderHistory(records, totalPages) {
  if (!records.length) {
    $('historyList').innerHTML = '<div class="empty-state">还没有任务记录，先去创作一条视频吧。</div>';
    $('pagination').innerHTML = '';
    return;
  }

  $('historyList').innerHTML = records.map((item) => {
    const descriptor = statusDescriptor(item.status);
    return `
      <article class="history-item">
        <div class="history-preview" ${item.videoUrl ? `data-play-video="${escapeAttr(item.videoUrl)}"` : ''}>
          ${item.videoUrl ? `<video src="${escapeAttr(item.videoUrl)}" muted playsinline></video>` : '<div class="empty-state">暂无视频</div>'}
        </div>
        <div class="history-info">
          <div class="history-title">${escapeHtml(item.displayText || item.prompt || '无提示词')}</div>
          <div class="history-meta">
            <span class="${descriptor.className}">${escapeHtml(descriptor.label)}</span>
            <span>${escapeHtml(item.duration || 0)} 秒</span>
            <span>${escapeHtml(formatDate(item.createdAt))}</span>
            ${item.mode ? `<span>模式：${escapeHtml(item.mode)}</span>` : ''}
            ${item.videoTemplateName ? `<span>模板：${escapeHtml(item.videoTemplateName)}</span>` : ''}
            ${item.referenceLink ? '<span>含链接参考</span>' : ''}
            ${item.referenceVideoPath ? '<span>含参考视频</span>' : ''}
          </div>
        </div>
        <div class="history-actions">
          ${item.videoUrl ? `<button class="btn btn--outline btn--small" type="button" data-play-video="${escapeAttr(item.videoUrl)}">播放</button>` : ''}
          <button class="btn btn--ghost btn--small" type="button" data-delete-history="${escapeAttr(item.id)}">删除</button>
        </div>
      </article>
    `;
  }).join('');

  $$('[data-play-video]').forEach((node) => {
    node.addEventListener('click', () => openModal(node.dataset.playVideo || '', '历史视频'));
  });
  $$('[data-delete-history]').forEach((node) => {
    node.addEventListener('click', () => deleteHistory(node.dataset.deleteHistory || ''));
  });

  if (totalPages <= 1) {
    $('pagination').innerHTML = '';
    return;
  }

  let html = `<button ${state.historyPage <= 1 ? 'disabled' : ''} data-page="${state.historyPage - 1}">上一页</button>`;
  for (let page = 1; page <= totalPages; page += 1) {
    html += `<button class="${page === state.historyPage ? 'active' : ''}" data-page="${page}">${page}</button>`;
  }
  html += `<button ${state.historyPage >= totalPages ? 'disabled' : ''} data-page="${state.historyPage + 1}">下一页</button>`;
  $('pagination').innerHTML = html;
  $$('[data-page]', $('pagination')).forEach((button) => {
    button.addEventListener('click', () => loadHistory(Number(button.dataset.page || 1)));
  });
}

async function loadHistory(page = 1) {
  state.historyPage = page;
  try {
    const result = await apiFetch(`/api/history?page=${page}&limit=10`);
    renderHistory(result.records || [], result.totalPages || 1);
  } catch (error) {
    $('historyList').innerHTML = `<div class="empty-state">${escapeHtml(sanitizeUiMessage(error.message, '记录加载失败。'))}</div>`;
    $('pagination').innerHTML = '';
  }
}

async function deleteHistory(taskId) {
  if (!taskId) {
    return;
  }
  if (!window.confirm('确定删除这条记录吗？')) {
    return;
  }
  try {
    await apiFetch(`/api/history/${taskId}`, { method: 'DELETE' });
    showToast('记录已删除。', 'success');
    await loadHistory(state.historyPage);
  } catch (error) {
    showToast(sanitizeUiMessage(error.message, '删除记录失败。'), 'error');
  }
}

function openModeSheet() {
  renderModeSheetList();
  setHidden($('modeSheet'), false);
}

function closeModeSheet() {
  setHidden($('modeSheet'), true);
}
function formatRecordingClock(seconds) {
  const mins = Math.floor(seconds / 60).toString().padStart(2, '0');
  const secs = Math.floor(seconds % 60).toString().padStart(2, '0');
  return `${mins}:${secs}`;
}

function combineRecognitionText(finalText, interimText) {
  return [finalText, interimText]
    .map((value) => String(value || '').trim())
    .filter(Boolean)
    .join('');
}

function friendlyBrowserSpeechError(code) {
  const normalized = String(code || '').trim().toLowerCase();
  if (!normalized) {
    return '';
  }
  if (normalized.includes('not-allowed') || normalized.includes('service-not-allowed')) {
    return '请先允许浏览器使用麦克风和语音识别权限。';
  }
  if (normalized.includes('audio-capture')) {
    return '没有检测到可用麦克风，请检查设备后重试。';
  }
  if (normalized.includes('network')) {
    return '浏览器语音识别暂时不可用，请检查网络后重试。';
  }
  if (normalized.includes('no-speech')) {
    return '没有检测到清晰语音，请重试。';
  }
  if (normalized.includes('aborted')) {
    return '';
  }
  return '浏览器语音识别失败，请稍后重试。';
}

function ensureRecordingDialogExtras() {}

function updateRecordingDialog() {
  $('recordingTime').textContent = `${formatRecordingClock(state.recording.seconds)} / 01:00`;
  const ratio = Math.min(1, state.recording.seconds / APP_LIMITS.maxSpeechSeconds);
  $('recordingProgressFill').style.width = `${Math.round(ratio * 100)}%`;
  const previewText = $('recordingPreviewText');
  const hint = $('recordingHint');
  if (previewText) {
    const value = combineRecognitionText(
      state.recording.finalText,
      state.recording.interimText,
    );
    previewText.textContent = value || '请直接说话，识别结果会实时显示在这里。';
  }
  if (hint) {
    hint.textContent = state.recording.errorMessage
      || (state.recording.active
        ? '说完后点“识别文字”，系统会直接写入输入框。'
        : '识别完成后会自动写入输入框。');
  }
}

function showTranscribeState(active, text = '正在识别语音内容...') {
  $('transcribeStateText').textContent = text;
  setHidden($('transcribeState'), !active);
}

function renderVoiceButton() {
  $('voiceBtn').disabled = state.recording.active || state.isTranscribing;
  $('voiceBtn').textContent = state.recording.active
    ? '录音中'
    : state.isTranscribing
      ? '识别中'
      : '语音转文字';
}

async function cleanupRecordingResources() {
  const { recognition, timer } = state.recording;
  if (timer) {
    clearInterval(timer);
  }
  if (recognition) {
    recognition.onstart = null;
    recognition.onresult = null;
    recognition.onerror = null;
    recognition.onend = null;
    try {
      recognition.abort();
    } catch (_) {
    }
  }
}

function resetRecordingState() {
  state.recording = {
    active: false,
    recognition: null,
    seconds: 0,
    timer: null,
    finalText: '',
    interimText: '',
    shouldTranscribe: false,
    errorMessage: '',
  };
  updateRecordingDialog();
  renderVoiceButton();
}

async function startRecording() {
  if (state.recording.active || state.isTranscribing) {
    return;
  }
  if (!BrowserSpeechRecognition) {
    showToast('\u5f53\u524d\u6d4f\u89c8\u5668\u4e0d\u652f\u6301\u7cfb\u7edf\u8bed\u97f3\u8bc6\u522b\uff0c\u8bf7\u76f4\u63a5\u624b\u52a8\u8f93\u5165\u6587\u5b57\u3002', 'error');
    return;
  }

  try {
    const recognition = new BrowserSpeechRecognition();
    recognition.lang = 'zh-CN';
    recognition.continuous = false;
    recognition.interimResults = false;
    recognition.maxAlternatives = 1;

    state.recording = {
      active: true,
      recognition,
      seconds: 0,
      timer: setInterval(() => {
        state.recording.seconds += 1;
        updateRecordingDialog();
        if (state.recording.seconds >= APP_LIMITS.maxSpeechSeconds) {
          finishRecording();
        }
      }, 1000),
      finalText: '',
      interimText: '',
      shouldTranscribe: true,
      errorMessage: '',
    };

    recognition.onresult = (event) => {
      let finalText = state.recording.finalText || '';
      for (let index = event.resultIndex; index < event.results.length; index += 1) {
        const transcript = String(event.results[index][0]?.transcript || '');
        finalText += transcript;
      }
      state.recording.finalText = finalText;
      state.recording.interimText = '';
      state.recording.errorMessage = '';
      updateRecordingDialog();
    };

    recognition.onerror = (event) => {
      state.recording.errorMessage = friendlyBrowserSpeechError(event.error);
      updateRecordingDialog();
    };

    recognition.onend = () => {
      finalizeRecording();
    };

    ensureRecordingDialogExtras();
    updateRecordingDialog();
    renderVoiceButton();
    setHidden($('recordingDialog'), false);
    recognition.start();
  } catch (_) {
    showToast('\u672a\u6388\u4e88\u9ea6\u514b\u98ce\u6743\u9650\uff0c\u4ecd\u53ef\u624b\u52a8\u8f93\u5165\u6587\u5b57\u3002', 'error');
    await cleanupRecordingResources();
    resetRecordingState();
  }
}

async function finalizeRecording() {
  const shouldTranscribe = state.recording.shouldTranscribe === true;
  const text = combineRecognitionText(
    state.recording.finalText,
    state.recording.interimText,
  ).trim();
  const errorMessage = state.recording.errorMessage;
  await cleanupRecordingResources();
  setHidden($('recordingDialog'), true);
  resetRecordingState();

  if (!shouldTranscribe) {
    state.isTranscribing = false;
    renderVoiceButton();
    showTranscribeState(false);
    return;
  }

  state.isTranscribing = true;
  renderVoiceButton();
  showTranscribeState(true, '\u6b63\u5728\u6574\u7406\u8bed\u97f3\u6587\u5b57...');

  try {
    if (!text) {
      throw new Error(errorMessage || '\u6ca1\u6709\u8bc6\u522b\u5230\u6e05\u6670\u8bed\u97f3\uff0c\u8bf7\u91cd\u8bd5\u3002');
    }
    const currentText = $('inputText').value.trim();
    $('inputText').value = currentText ? `${currentText}\n${text}` : text;
    clearCorrectionState();
    showToast('\u8bed\u97f3\u5df2\u8f6c\u6210\u6587\u5b57\u3002', 'success');
  } catch (error) {
    showToast(sanitizeUiMessage(error.message, '\u8bed\u97f3\u8bc6\u522b\u5931\u8d25\u3002'), 'error');
  } finally {
    state.isTranscribing = false;
    renderVoiceButton();
    showTranscribeState(false);
  }
}

function finishRecording() {
  if (!state.recording.active) {
    return;
  }
  state.recording.shouldTranscribe = true;
  state.isTranscribing = true;
  renderVoiceButton();
  showTranscribeState(true, '\u6b63\u5728\u6574\u7406\u8bed\u97f3\u6587\u5b57...');
  try {
    state.recording.recognition?.stop();
  } catch (_) {
    finalizeRecording();
  }
}

function cancelRecording() {
  if (!state.recording.active) {
    setHidden($('recordingDialog'), true);
    return;
  }
  state.recording.shouldTranscribe = false;
  try {
    state.recording.recognition?.abort();
  } catch (_) {
    finalizeRecording();
  }
}
function switchPage(name) {
  const isSamePage = state.activePage === name;
  state.activePage = name;
  $$('.page').forEach((page) => page.classList.remove('active'));
  $$('.tab').forEach((tab) => tab.classList.remove('active'));
  const pageNode = $(`page-${name}`);
  if (!pageNode) {
    return;
  }
  pageNode.classList.add('active');
  document.querySelector(`.tab[data-page="${name}"]`)?.classList.add('active');
  if (name === 'history' && state.authToken) {
    loadHistory(1);
  }
  if (name === 'settings') {
    loadSettingsPage();
  }
  if (isSamePage && name === 'create' && state.authToken) {
    loadWorkbench();
  }
}

function bindEvents() {
  $('loginBtn').addEventListener('click', login);
  $('clearLoginBtn').addEventListener('click', () => {
    $('loginUsername').value = '';
    $('loginPassword').value = '';
    clearLoginError();
  });
  $('loginPassword').addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
      login();
    }
  });
  $('settingsLogoutBtn').addEventListener('click', logout);

  $('modeSwitchBtn').addEventListener('click', openModeSheet);
  $('closeModeSheetBtn').addEventListener('click', closeModeSheet);
  $('modeSheet').addEventListener('click', (event) => {
    if (event.target === $('modeSheet')) {
      closeModeSheet();
    }
  });

  $('voiceBtn').addEventListener('click', startRecording);
  $('finishRecordingBtn').addEventListener('click', finishRecording);
  $('cancelRecordingBtn').addEventListener('click', cancelRecording);
  $('recordingDialog').addEventListener('click', (event) => {
    if (event.target === $('recordingDialog')) {
      cancelRecording();
    }
  });

  $('correctBtn').addEventListener('click', correctText);
  $('promptBtn').addEventListener('click', generatePrompt);
  $('inputText').addEventListener('input', () => {
    if ($('inputText').value.trim() !== state.lastCorrectedText) {
      clearCorrectionState();
    }
  });

  $('pickImagesBtn').addEventListener('click', () => $('imageInput').click());
  $('imageInput').addEventListener('change', (event) => {
    uploadImages(Array.from(event.target.files || []));
    event.target.value = '';
  });
  $('pickReferenceVideoBtn').addEventListener('click', () => $('referenceVideoInput').click());
  $('referenceVideoInput').addEventListener('change', (event) => {
    uploadReferenceVideo(Array.from(event.target.files || [])[0] || null);
    event.target.value = '';
  });
  $('removeReferenceVideoBtn').addEventListener('click', clearReferenceVideo);
  $('refreshTemplatesBtn').addEventListener('click', refreshTemplates);
  $('generateBtn').addEventListener('click', generateVideo);
  $('playCurrentTaskBtn').addEventListener('click', previewCurrentTask);
  $('downloadCurrentTaskBtn').addEventListener('click', downloadCurrentTask);
  $('taskStatusPanel').addEventListener('click', (event) => {
    const actionButton = event.target.closest('[data-task-action]');
    if (actionButton) {
      const action = actionButton.dataset.taskAction || '';
      if (action === 'play') {
        previewCurrentTask();
      } else if (action === 'download') {
        downloadCurrentTask();
      } else if (action === 'retry') {
        retryCurrentTask();
      } else if (action === 'delete') {
        deleteCurrentTask();
      }
      return;
    }
    previewCurrentTask();
  });
  $('taskStatusPanel').addEventListener('keydown', (event) => {
    if (event.key !== 'Enter' && event.key !== ' ') {
      return;
    }
    event.preventDefault();
    previewCurrentTask();
  });

  $$('.tab').forEach((tab) => {
    tab.addEventListener('click', () => switchPage(tab.dataset.page));
  });

  $('closeModalBtn').addEventListener('click', closeModal);
  $('downloadBtn').addEventListener('click', downloadVideo);
  $('videoModal').addEventListener('click', (event) => {
    if (event.target === $('videoModal')) {
      closeModal();
    }
  });

  window.addEventListener('beforeunload', () => {
    stopTaskPolling();
    cleanupRecordingResources();
  });
}

function updateUserUI() {
  const user = state.currentUser || null;
  syncAccountSummary(user);

  $('profileAlias').value = user?.alias || '';
  $('profileEmail').value = user?.email || '';
  $('profilePhone').value = user?.phone || '';
  if (!$('forgotUsername').value.trim()) {
    $('forgotUsername').value = user?.username || $('loginUsername').value.trim();
  }
}

async function syncCurrentUserInfo({ silent = false } = {}) {
  if (!state.authToken) {
    updateUserUI();
    return null;
  }
  try {
    const result = await apiFetch('/api/auth/me');
    saveSession(state.authToken, result.user, result.user?.username || '');
    updateUserUI();
    return result.user || null;
  } catch (error) {
    if (!silent) {
      showToast(sanitizeUiMessage(error.message, '读取账号信息失败。'), 'error');
    }
    throw error;
  }
}

function openDialog(id) {
  setDialogOpen(id, true);
}

function closeDialog(id) {
  setDialogOpen(id, false);
}

function resetForgotPasswordForm() {
  $('forgotEmail').value = '';
  $('forgotNewPassword').value = '';
  $('forgotConfirmPassword').value = '';
}

function resetRegisterForm() {
  $('registerUsername').value = '';
  $('registerEmail').value = '';
  $('registerInviteCode').value = '';
  $('registerPassword').value = '';
  $('registerConfirmPassword').value = '';
}

function openRegisterDialog() {
  resetRegisterForm();
  $('registerUsername').value = $('loginUsername').value.trim();
  const inviteCode = new URLSearchParams(window.location.search).get('inviteCode');
  if (inviteCode) {
    $('registerInviteCode').value = String(inviteCode).trim();
  }
  openDialog('registerDialog');
}

function closeRegisterDialog() {
  closeDialog('registerDialog');
}

async function submitRegister() {
  const username = $('registerUsername').value.trim();
  const email = $('registerEmail').value.trim();
  const inviteCode = $('registerInviteCode').value.trim();
  const password = $('registerPassword').value.trim();
  const confirmPassword = $('registerConfirmPassword').value.trim();

  if (!username || !email || !inviteCode || !password || !confirmPassword) {
    showToast('请完整填写注册信息。', 'error');
    return;
  }
  if (password.length < 6) {
    showToast('密码至少 6 位。', 'error');
    return;
  }
  if (password !== confirmPassword) {
    showToast('两次输入的密码不一致。', 'error');
    return;
  }

  $('submitRegisterBtn').disabled = true;
  $('submitRegisterBtn').textContent = '提交中...';
  try {
    await apiFetch('/api/auth/register', {
      method: 'POST',
      body: {
        username,
        email,
        inviteCode,
        password,
      },
    }, false);
    $('loginUsername').value = username;
    closeRegisterDialog();
    resetRegisterForm();
    showToast('注册成功，请返回登录。', 'success');
  } catch (error) {
    showToast(sanitizeUiMessage(error.message, '注册失败。'), 'error');
  } finally {
    $('submitRegisterBtn').disabled = false;
    $('submitRegisterBtn').textContent = '确认注册';
  }
}

function openForgotPasswordDialog() {
  $('forgotUsername').value = state.currentUser?.username || $('loginUsername').value.trim();
  resetForgotPasswordForm();
  openDialog('forgotPasswordDialog');
}

function closeForgotPasswordDialog() {
  closeDialog('forgotPasswordDialog');
}

async function submitForgotPassword() {
  const username = $('forgotUsername').value.trim();
  const email = $('forgotEmail').value.trim();
  const newPassword = $('forgotNewPassword').value.trim();
  const confirmPassword = $('forgotConfirmPassword').value.trim();

  if (!username || !email || !newPassword || !confirmPassword) {
    showToast('请完整填写重置密码信息。', 'error');
    return;
  }
  if (newPassword.length < 6) {
    showToast('新密码至少 6 位。', 'error');
    return;
  }
  if (newPassword !== confirmPassword) {
    showToast('两次输入的新密码不一致。', 'error');
    return;
  }

  $('submitForgotPasswordBtn').disabled = true;
  $('submitForgotPasswordBtn').textContent = '提交中...';
  try {
    await apiFetch('/api/auth/forgot-password', {
      method: 'POST',
      body: {
        username,
        email,
        newPassword,
      },
    }, false);
    $('loginUsername').value = username;
    closeForgotPasswordDialog();
    resetForgotPasswordForm();
    showToast('密码已重置，请使用新密码登录。', 'success');
  } catch (error) {
    showToast(sanitizeUiMessage(error.message, '重置密码失败。'), 'error');
  } finally {
    $('submitForgotPasswordBtn').disabled = false;
    $('submitForgotPasswordBtn').textContent = '重置密码';
  }
}

function openEditProfileDialog() {
  if (!state.authToken) {
    showToast('请先登录后再编辑资料。', 'error');
    return;
  }
  updateUserUI();
  openDialog('editProfileDialog');
}

function closeEditProfileDialog() {
  closeDialog('editProfileDialog');
}

async function submitProfileUpdate() {
  if (!state.authToken) {
    showToast('请先登录后再保存资料。', 'error');
    return;
  }

  const alias = $('profileAlias').value.trim();
  const email = $('profileEmail').value.trim();
  const phone = $('profilePhone').value.trim();
  if (!email) {
    showToast('邮箱不能为空。', 'error');
    return;
  }

  $('submitProfileBtn').disabled = true;
  $('submitProfileBtn').textContent = '保存中...';
  try {
    const result = await apiFetch('/api/auth/update-profile', {
      method: 'POST',
      body: { alias, email, phone },
    });
    saveSession(state.authToken, result.user || state.currentUser, result.user?.username || state.currentUser?.username || '');
    updateUserUI();
    closeEditProfileDialog();
    showToast('资料已更新。', 'success');
  } catch (error) {
    showToast(sanitizeUiMessage(error.message, '更新资料失败。'), 'error');
  } finally {
    $('submitProfileBtn').disabled = false;
    $('submitProfileBtn').textContent = '保存资料';
  }
}

function openChangePasswordDialog() {
  if (!state.authToken) {
    showToast('请先登录后再修改密码。', 'error');
    return;
  }
  $('oldPassword').value = '';
  $('newPassword').value = '';
  $('confirmNewPassword').value = '';
  openDialog('changePasswordDialog');
}

function closeChangePasswordDialog() {
  closeDialog('changePasswordDialog');
}

async function submitChangePassword() {
  if (!state.authToken) {
    showToast('请先登录后再修改密码。', 'error');
    return;
  }

  const oldPassword = $('oldPassword').value.trim();
  const newPassword = $('newPassword').value.trim();
  const confirmPassword = $('confirmNewPassword').value.trim();
  if (!oldPassword || !newPassword || !confirmPassword) {
    showToast('请完整填写密码信息。', 'error');
    return;
  }
  if (newPassword.length < 6) {
    showToast('新密码至少 6 位。', 'error');
    return;
  }
  if (newPassword !== confirmPassword) {
    showToast('两次输入的新密码不一致。', 'error');
    return;
  }

  $('submitChangePasswordBtn').disabled = true;
  $('submitChangePasswordBtn').textContent = '保存中...';
  try {
    await apiFetch('/api/auth/change-password', {
      method: 'POST',
      body: { oldPassword, newPassword },
    });
    closeChangePasswordDialog();
    showToast('密码已修改。', 'success');
  } catch (error) {
    showToast(sanitizeUiMessage(error.message, '修改密码失败。'), 'error');
  } finally {
    $('submitChangePasswordBtn').disabled = false;
    $('submitChangePasswordBtn').textContent = '确认修改';
  }
}

async function openApkDownload(silent = false) {
  const button = $('checkUpdateBtn');
  button.disabled = true;
  button.textContent = silent ? '准备中...' : '获取中...';
  try {
    const params = new URLSearchParams({
      platform: APP_META.platform,
      channel: APP_META.channel,
      currentVersion: '0.0.0',
      currentBuildNumber: '0',
    });
    const result = await apiFetch(`/api/app-release/latest?${params.toString()}`, {}, false);
    state.latestUpdateInfo = result.info || null;
    renderVersionInfo();
    const latest = state.latestUpdateInfo?.latest || null;
    const downloadUrl = String(
      latest?.download_url || latest?.downloadUrl || APP_META.apkDownloadUrl,
    ).trim();
    if (!downloadUrl) {
      throw new Error('当前未配置安卓安装包下载地址。');
    }
    if (interceptWeChatDownload({
      title: '微信内无法直接下载 APK',
      subtitle: '请点击右上角“…”后选择“在浏览器打开”，再下载安装包。',
      copyValue: downloadUrl,
      copyLabel: 'APK 下载地址',
      copyTip: '复制后可在系统浏览器中直接打开并下载 APK。',
      copySuccessText: 'APK 下载地址已复制，请到系统浏览器中打开',
    })) {
      return;
    }
    window.open(downloadUrl, '_blank', 'noopener');
    if (!silent) {
      window.prompt('请复制或直接打开下面的 APK 下载地址：', downloadUrl);
      showToast('已为你打开 APK 下载链接。', 'success');
    }
  } catch (error) {
    renderVersionInfo();
    if (!silent) {
      showToast(sanitizeUiMessage(error.message, '获取 APK 下载地址失败。'), 'error');
    }
  } finally {
    button.disabled = false;
    button.textContent = '下载安卓 APK';
  }
}

async function loadSettingsPage() {
  if (state.authToken) {
    try {
      await syncCurrentUserInfo({ silent: true });
    } catch (_) {
    }
  } else {
    updateUserUI();
  }
  renderVersionInfo();
  updateUserUI();
}

async function bootstrapAfterLogin() {
  await Promise.all([loadWorkbench(), loadSettingsPage()]);
  if (state.activePage === 'history') {
    await loadHistory(1);
  }
}

async function logout() {
  stopTaskPolling();
  try {
    await apiFetch('/api/auth/logout', { method: 'POST' }, false);
  } catch (_) {
  }
  clearSession();
  renderHistorySummary();
  renderVersionInfo();
  updateUserUI();
  closeEditProfileDialog();
  closeChangePasswordDialog();
  closeForgotPasswordDialog();
  closeModal();
  showLoginShell();
  showToast('已退出登录。', 'info');
}

async function downloadVideoByProxy(url, filenamePrefix = '拾光视频') {
  if (!url) {
    showToast('当前没有可下载的视频。', 'error');
    return false;
  }

  if (interceptWeChatDownload({
    title: '微信内无法直接下载视频',
    subtitle: '请点击右上角“…”后选择“在浏览器打开”，再继续下载视频。',
    copyValue: url,
    copyLabel: '视频地址',
    copyTip: '复制后可在系统浏览器中直接打开视频地址。',
    copySuccessText: '视频地址已复制，请到系统浏览器中打开',
  })) {
    return false;
  }

  const filename = `${filenamePrefix}_${Date.now()}.mp4`;
  const response = await fetch(
    `/api/download-video?${new URLSearchParams({ url, filename }).toString()}`,
    {
      headers: state.authToken
        ? {
            Authorization: `Bearer ${state.authToken}`,
            token: state.authToken,
          }
        : {},
    },
  );

  if (!response.ok) {
    let payload = {};
    try {
      payload = await response.json();
    } catch (_) {
      payload = {};
    }
    if (response.status === 401) {
      handleUnauthorized();
    }
    throw new Error(extractPayloadMessage(payload, '下载视频失败。'));
  }

  const blob = await response.blob();
  const objectUrl = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = objectUrl;
  link.download = filename;
  link.click();
  setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
  return true;
}

async function downloadVideo() {
  try {
    await downloadVideoByProxy(state.currentVideoUrl, '拾光视频');
  } catch (error) {
    showToast(sanitizeUiMessage(error.message, '下载视频失败。'), 'error');
  }
}

function renderHistory(records, totalPages) {
  if (!records.length) {
    $('historyList').innerHTML = '<div class="empty-state">还没有任务记录，先去创作一条视频吧。</div>';
    $('pagination').innerHTML = '';
    return;
  }

  $('historyList').innerHTML = records.map((item) => {
    const descriptor = statusDescriptor(item.status);
    return `
      <article class="history-item">
        <div class="history-preview" ${item.videoUrl ? `data-play-video="${escapeAttr(item.videoUrl)}"` : ''}>
          ${item.videoUrl ? `<video src="${escapeAttr(item.videoUrl)}" muted playsinline></video>` : '<div class="empty-state">暂无视频</div>'}
        </div>
        <div class="history-info">
          <div class="history-title">${escapeHtml(item.displayText || item.prompt || '无提示词')}</div>
          <div class="history-meta">
            <span class="${descriptor.className}">${escapeHtml(descriptor.label)}</span>
            <span>${escapeHtml(item.duration || 0)} 秒</span>
            <span>${escapeHtml(formatDate(item.createdAt))}</span>
            ${item.mode ? `<span>模式：${escapeHtml(item.mode)}</span>` : ''}
            ${item.videoTemplateName ? `<span>模板：${escapeHtml(item.videoTemplateName)}</span>` : ''}
            ${item.referenceLink ? '<span>含链接参考</span>' : ''}
            ${item.referenceVideoPath ? '<span>含参考视频</span>' : ''}
          </div>
        </div>
        <div class="history-actions">
          ${item.videoUrl ? `<button class="btn btn--outline btn--small" type="button" data-play-video="${escapeAttr(item.videoUrl)}">播放</button>` : ''}
          ${item.videoUrl ? `<button class="btn btn--outline btn--small" type="button" data-download-video="${escapeAttr(item.videoUrl)}">下载</button>` : ''}
          <button class="btn btn--ghost btn--small" type="button" data-delete-history="${escapeAttr(item.id)}">删除</button>
        </div>
      </article>
    `;
  }).join('');

  $$('[data-play-video]').forEach((node) => {
    node.addEventListener('click', () => openModal(node.dataset.playVideo || '', '历史视频'));
  });
  $$('[data-download-video]').forEach((node) => {
    node.addEventListener('click', async () => {
      try {
        await downloadVideoByProxy(node.dataset.downloadVideo || '', '历史视频');
        showToast('视频已开始下载。', 'success');
      } catch (error) {
        showToast(sanitizeUiMessage(error.message, '下载视频失败。'), 'error');
      }
    });
  });
  $$('[data-delete-history]').forEach((node) => {
    node.addEventListener('click', () => deleteHistory(node.dataset.deleteHistory || ''));
  });

  if (totalPages <= 1) {
    $('pagination').innerHTML = '';
    return;
  }

  let html = `<button ${state.historyPage <= 1 ? 'disabled' : ''} data-page="${state.historyPage - 1}">上一页</button>`;
  for (let page = 1; page <= totalPages; page += 1) {
    html += `<button class="${page === state.historyPage ? 'active' : ''}" data-page="${page}">${page}</button>`;
  }
  html += `<button ${state.historyPage >= totalPages ? 'disabled' : ''} data-page="${state.historyPage + 1}">下一页</button>`;
  $('pagination').innerHTML = html;
  $$('[data-page]', $('pagination')).forEach((button) => {
    button.addEventListener('click', () => loadHistory(Number(button.dataset.page || 1)));
  });
}

async function loadHistory(page = 1) {
  state.historyPage = page;
  try {
    const [historyResult, summaryResult] = await Promise.all([
      apiFetch(`/api/history?page=${page}&limit=10`),
      apiFetch('/api/history-summary').catch(() => null),
    ]);
    if (summaryResult?.summary) {
      state.historySummary = {
        total: Number(summaryResult.summary.total || 0),
        completed: Number(summaryResult.summary.completed || 0),
        processing: Number(summaryResult.summary.processing || 0),
        failed: Number(summaryResult.summary.failed || 0),
      };
    }
    renderHistorySummary();
    renderHistory(historyResult.records || [], historyResult.totalPages || 1);
  } catch (error) {
    renderHistorySummary();
    $('historyList').innerHTML = `<div class="empty-state">${escapeHtml(sanitizeUiMessage(error.message, '加载历史记录失败。'))}</div>`;
    $('pagination').innerHTML = '';
  }
}

async function clearAllHistory() {
  if (!window.confirm('确定清空当前账号下的全部历史记录吗？')) {
    return;
  }
  try {
    await apiFetch('/api/history', { method: 'DELETE' });
    state.historySummary = {
      total: 0,
      completed: 0,
      processing: 0,
      failed: 0,
    };
    renderHistorySummary();
    renderHistory([], 1);
    showToast('历史记录已清空。', 'success');
  } catch (error) {
    showToast(sanitizeUiMessage(error.message, '清空记录失败。'), 'error');
  }
}

function bindDialogMaskClose(id, onClose) {
  const target = $(id);
  if (!target) {
    return;
  }
  target.addEventListener('click', (event) => {
    if (event.target === target) {
      onClose();
    }
  });
}

function ensureRegisterUi() {
  const forgotPasswordBtn = $('forgotPasswordBtn');
  if (forgotPasswordBtn && !$('registerBtn')) {
    const registerBtn = document.createElement('button');
    registerBtn.className = 'text-action';
    registerBtn.id = 'registerBtn';
    registerBtn.type = 'button';
    registerBtn.textContent = '注册账号';
    forgotPasswordBtn.parentElement?.appendChild(registerBtn);
  }

  if ($('registerDialog')) {
    return;
  }

  const dialog = document.createElement('div');
  dialog.className = 'dialog hidden';
  dialog.id = 'registerDialog';
  dialog.innerHTML = `
    <div class="dialog-card dialog-card--form dialog-card--register">
      <div class="register-dialog__hero">
        <div class="register-dialog__brand">
          <div class="dialog-icon">注</div>
          <div>
            <p class="eyebrow">邀请码注册</p>
            <h3>注册账号</h3>
          </div>
        </div>
        <p class="register-dialog__copy">沿用当前登录页的浅暖色与轻玻璃层次。注册必须填写后台生成的邀请码，注册成功后会自动进入同一套账号体系。</p>
        <div class="register-dialog__pills">
          <span class="hero-pill hero-pill--sky">邀请码校验</span>
          <span class="hero-pill hero-pill--coral">统一账号</span>
          <span class="hero-pill hero-pill--jade">后端同步</span>
        </div>
      </div>
      <div class="field-stack field-stack--compact">
        <div class="register-dialog__grid">
          <label class="field">
            <span class="field-label">用户名</span>
            <input class="input" id="registerUsername" type="text" placeholder="请输入用户名">
          </label>
          <label class="field">
            <span class="field-label">邮箱</span>
            <input class="input" id="registerEmail" type="email" placeholder="请输入邮箱">
          </label>
        </div>
        <section class="register-dialog__invite">
          <div class="register-dialog__invite-head">
            <strong>邀请码</strong>
            <span>注册成功后可在个人信息里再补充资料</span>
          </div>
          <label class="field">
            <span class="field-label">受邀口令</span>
            <input class="input" id="registerInviteCode" type="text" placeholder="请输入邀请码">
          </label>
        </section>
        <div class="register-dialog__grid">
          <label class="field">
            <span class="field-label">密码</span>
            <input class="input" id="registerPassword" type="password" placeholder="请输入密码">
          </label>
          <label class="field">
            <span class="field-label">确认密码</span>
            <input class="input" id="registerConfirmPassword" type="password" placeholder="请再次输入密码">
          </label>
        </div>
      </div>
      <div class="button-row register-dialog__actions">
        <button class="btn btn--primary" id="submitRegisterBtn" type="button">确认注册</button>
        <button class="btn btn--ghost" id="closeRegisterBtn" type="button">返回登录</button>
      </div>
    </div>
  `;
  document.body.appendChild(dialog);
}

function bindEvents() {
  const bind = (id, eventName, handler) => {
    const node = $(id);
    if (node) {
      node.addEventListener(eventName, handler);
    }
    return node;
  };

  bind('loginBtn', 'click', login);
  bind('clearLoginBtn', 'click', () => {
    const loginUsername = $('loginUsername');
    const loginPassword = $('loginPassword');
    if (loginUsername) {
      loginUsername.value = '';
    }
    if (loginPassword) {
      loginPassword.value = '';
    }
    clearLoginError();
  });
  bind('forgotPasswordBtn', 'click', openForgotPasswordDialog);
  bind('registerBtn', 'click', openRegisterDialog);
  bind('submitForgotPasswordBtn', 'click', submitForgotPassword);
  bind('submitRegisterBtn', 'click', submitRegister);
  bind('closeForgotPasswordBtn', 'click', closeForgotPasswordDialog);
  bind('closeRegisterBtn', 'click', closeRegisterDialog);
  bind('loginPassword', 'keydown', (event) => {
    if (event.key === 'Enter') {
      login();
    }
  });
  bind('settingsLogoutBtn', 'click', logout);

  bind('modeSwitchBtn', 'click', openModeSheet);
  bind('closeModeSheetBtn', 'click', closeModeSheet);
  bind('modeSheet', 'click', (event) => {
    if (event.target === $('modeSheet')) {
      closeModeSheet();
    }
  });

  bind('voiceBtn', 'click', startRecording);
  bind('finishRecordingBtn', 'click', finishRecording);
  bind('cancelRecordingBtn', 'click', cancelRecording);
  bind('recordingDialog', 'click', (event) => {
    if (event.target === $('recordingDialog')) {
      cancelRecording();
    }
  });

  bind('correctBtn', 'click', correctText);
  bind('promptBtn', 'click', generatePrompt);
  bind('inputText', 'input', () => {
    const inputText = $('inputText');
    if (inputText && inputText.value.trim() !== state.lastCorrectedText) {
      clearCorrectionState();
    }
  });

  bind('pickImagesBtn', 'click', () => $('imageInput')?.click());
  bind('imageInput', 'change', (event) => {
    uploadImages(Array.from(event.target.files || []));
    event.target.value = '';
  });
  bind('pickReferenceVideoBtn', 'click', () => $('referenceVideoInput')?.click());
  bind('referenceVideoInput', 'change', (event) => {
    uploadReferenceVideo(Array.from(event.target.files || [])[0] || null);
    event.target.value = '';
  });
  bind('removeReferenceVideoBtn', 'click', clearReferenceVideo);
  bind('refreshTemplatesBtn', 'click', refreshTemplates);
  bind('generateBtn', 'click', generateVideo);
  bind('playCurrentTaskBtn', 'click', previewCurrentTask);
  bind('downloadCurrentTaskBtn', 'click', downloadCurrentTask);
  bind('taskStatusPanel', 'click', (event) => {
    if (event.target.closest('#playCurrentTaskBtn, #downloadCurrentTaskBtn')) {
      return;
    }
    previewCurrentTask();
  });
  bind('taskStatusPanel', 'keydown', (event) => {
    if (event.key !== 'Enter' && event.key !== ' ') {
      return;
    }
    event.preventDefault();
    previewCurrentTask();
  });

  bind('refreshHistoryBtn', 'click', () => loadHistory(1));
  document.querySelector('.history-toolbar')?.addEventListener('dblclick', () => loadHistory(1));
  bind('clearHistoryBtn', 'click', clearAllHistory);

  bind('editProfileBtn', 'click', openEditProfileDialog);
  bind('submitProfileBtn', 'click', submitProfileUpdate);
  bind('closeEditProfileBtn', 'click', closeEditProfileDialog);
  bind('changePasswordBtn', 'click', openChangePasswordDialog);
  bind('submitChangePasswordBtn', 'click', submitChangePassword);
  bind('closeChangePasswordBtn', 'click', closeChangePasswordDialog);
  bind('refreshProfileBtn', 'click', async () => {
    try {
      await syncCurrentUserInfo();
      showToast('账号信息已同步。', 'success');
    } catch (_) {
    }
  });
  bind('checkUpdateBtn', 'click', () => openApkDownload(false));

  $$('.tab').forEach((tab) => {
    tab.addEventListener('click', () => switchPage(tab.dataset.page));
  });

  bind('closeModalBtn', 'click', closeModal);
  bind('downloadBtn', 'click', downloadVideo);
  bind('copyWechatGuideBtn', 'click', copyWechatGuideValue);
  bind('closeWechatGuideBtn', 'click', closeWechatGuide);
  bind('videoModal', 'click', (event) => {
    if (event.target === $('videoModal')) {
      closeModal();
    }
  });

  bindDialogMaskClose('forgotPasswordDialog', closeForgotPasswordDialog);
  bindDialogMaskClose('registerDialog', closeRegisterDialog);
  bindDialogMaskClose('editProfileDialog', closeEditProfileDialog);
  bindDialogMaskClose('changePasswordDialog', closeChangePasswordDialog);
  bindDialogMaskClose('wechatGuideDialog', closeWechatGuide);

  window.addEventListener('beforeunload', () => {
    stopTaskPolling();
    cleanupRecordingResources();
  });
}

async function downloadTaskById(taskId, filenamePrefix = '拾光视频', fallbackUrl = '') {
  if (!taskId) {
    throw new Error('当前没有可下载的视频。');
  }
  if (interceptWeChatDownload({
    title: '微信内无法直接下载视频',
    subtitle: '请点击右上角“…”后选择“在浏览器打开”，再继续下载视频。',
    copyValue: fallbackUrl || window.location.href,
    copyLabel: fallbackUrl ? '视频地址' : '当前页面地址',
    copyTip: fallbackUrl
      ? '复制后可在系统浏览器中直接打开视频地址。'
      : '复制后请在系统浏览器中打开页面并重新登录后下载。',
    copySuccessText: fallbackUrl
      ? '视频地址已复制，请到系统浏览器中打开'
      : '页面地址已复制，请到系统浏览器中打开',
  })) {
    return false;
  }
  const filename = `${filenamePrefix}_${Date.now()}.mp4`;
  const response = await fetch(`/api/history/${encodeURIComponent(taskId)}/download`, {
    headers: state.authToken
      ? {
          Authorization: `Bearer ${state.authToken}`,
          token: state.authToken,
        }
      : {},
  });
  if (!response.ok) {
    let payload = {};
    try {
      payload = await response.json();
    } catch (_) {
      payload = {};
    }
    if (response.status === 401) {
      handleUnauthorized();
    }
    throw new Error(extractPayloadMessage(payload, '下载视频失败。'));
  }
  const blob = await response.blob();
  const objectUrl = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = objectUrl;
  link.download = filename;
  link.click();
  setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
  return true;
}

async function retryTask(taskId) {
  const result = await apiFetch(`/api/history/${encodeURIComponent(taskId)}/retry`, {
    method: 'POST',
  });
  return result.record || null;
}

async function deleteCurrentTask() {
  if (!state.currentTask?.id) {
    return;
  }
  await deleteHistory(state.currentTask.id);
  state.currentTask = null;
  renderTaskStatusPanel();
}

async function retryCurrentTask() {
  if (!state.currentTask?.id || state.currentTask?.status !== 'failed') {
    return;
  }
  try {
    const task = await retryTask(state.currentTask.id);
    state.currentTask = task;
    state.pollingCount = 0;
    renderTaskStatusPanel();
    if (task?.id && ['queued', 'processing'].includes(String(task.status || '').toLowerCase())) {
      setSubmitting(true);
      startTaskPolling(task.id);
    }
    showToast('已重新提交任务。', 'success');
  } catch (error) {
    showToast(sanitizeUiMessage(error.message, '重新生成失败。'), 'error');
  }
}

async function downloadVideo() {
  try {
    if (state.currentVideoTaskId) {
      await downloadTaskById(state.currentVideoTaskId, '拾光视频', state.currentVideoUrl || '');
      return;
    }
    await downloadVideoByProxy(state.currentVideoUrl, '拾光视频');
  } catch (error) {
    showToast(sanitizeUiMessage(error.message, '下载视频失败。'), 'error');
  }
}

function renderHistory(records, totalPages) {
  if (!records.length) {
    $('historyList').innerHTML = '<div class="empty-state">还没有任务记录，先去创作一条视频吧。</div>';
    $('pagination').innerHTML = '';
    return;
  }

  $('historyList').innerHTML = records.map((item) => {
    const descriptor = statusDescriptor(item.status);
    const canPlay = item.status === 'completed' && item.videoUrl;
    const canDownload = item.status === 'completed' && item.id;
    const canRetry = item.status === 'failed' && item.id;
    return `
      <article class="history-item">
        <div class="history-preview" ${canPlay ? `data-play-video="${escapeAttr(item.videoUrl)}" data-task-id="${escapeAttr(item.id)}"` : ''}>
          ${canPlay ? `<video src="${escapeAttr(item.videoUrl)}" muted playsinline></video>` : '<div class="empty-state">暂无视频</div>'}
        </div>
        <div class="history-info">
          <div class="history-title">${escapeHtml(item.displayText || item.prompt || '无提示词')}</div>
          <div class="history-meta">
            <span class="${descriptor.className}">${escapeHtml(descriptor.label)}</span>
            <span>${escapeHtml(item.duration || 0)} 秒</span>
            <span>${escapeHtml(formatDate(item.createdAt))}</span>
          </div>
        </div>
        <div class="history-actions">
          ${canPlay ? `<button class="btn btn--outline btn--small" type="button" data-play-video="${escapeAttr(item.videoUrl)}" data-task-id="${escapeAttr(item.id)}">播放</button>` : ''}
          ${canDownload ? `<button class="btn btn--outline btn--small" type="button" data-download-task="${escapeAttr(item.id)}">下载</button>` : ''}
          ${canRetry ? `<button class="btn btn--outline btn--small" type="button" data-retry-history="${escapeAttr(item.id)}">重新生成</button>` : ''}
          <button class="btn btn--ghost btn--small" type="button" data-delete-history="${escapeAttr(item.id)}">删除</button>
        </div>
      </article>
    `;
  }).join('');

  $$('[data-play-video]').forEach((node) => {
    node.addEventListener('click', () => openModal(node.dataset.playVideo || '', '历史视频', node.dataset.taskId || ''));
  });
  $$('[data-download-task]').forEach((node) => {
    node.addEventListener('click', async () => {
      try {
        const started = await downloadTaskById(
          node.dataset.downloadTask || '',
          '历史视频',
          node.closest('.history-item')?.querySelector('[data-play-video]')?.dataset.playVideo || '',
        );
        if (started) {
          showToast('视频已开始下载。', 'success');
        }
      } catch (error) {
        showToast(sanitizeUiMessage(error.message, '下载视频失败。'), 'error');
      }
    });
  });
  $$('[data-retry-history]').forEach((node) => {
    node.addEventListener('click', async () => {
      try {
        await retryTask(node.dataset.retryHistory || '');
        showToast('已重新提交任务。', 'success');
        await loadHistory(state.historyPage);
      } catch (error) {
        showToast(sanitizeUiMessage(error.message, '重新生成失败。'), 'error');
      }
    });
  });
  $$('[data-delete-history]').forEach((node) => {
    node.addEventListener('click', () => deleteHistory(node.dataset.deleteHistory || ''));
  });

  if (totalPages <= 1) {
    $('pagination').innerHTML = '';
    return;
  }

  let html = `<button ${state.historyPage <= 1 ? 'disabled' : ''} data-page="${state.historyPage - 1}">上一页</button>`;
  for (let page = 1; page <= totalPages; page += 1) {
    html += `<button class="${page === state.historyPage ? 'active' : ''}" data-page="${page}">${page}</button>`;
  }
  html += `<button ${state.historyPage >= totalPages ? 'disabled' : ''} data-page="${state.historyPage + 1}">下一页</button>`;
  $('pagination').innerHTML = html;
  $$('[data-page]', $('pagination')).forEach((button) => {
    button.addEventListener('click', () => loadHistory(Number(button.dataset.page || 1)));
  });
}

document.addEventListener('DOMContentLoaded', async () => {
  ensureRegisterUi();
  bindEvents();
  readSession();
  updateUserUI();
  renderHistorySummary();
  renderVersionInfo();
  renderCreatePage();
  ensureRecordingDialogExtras();
  updateRecordingDialog();
  showTranscribeState(false);
  const restored = await restoreLogin();
  if (!restored) {
    showLoginShell();
  }
});
