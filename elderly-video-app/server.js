const express = require('express');
const multer = require('multer');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const FormData = require('form-data');

let fetchImpl;
try {
  // Keep multipart proxy uploads on node-fetch because the app uses the
  // `form-data` package, which is not compatible with the built-in fetch body handling.
  fetchImpl = require('node-fetch');
} catch (error) {
  fetchImpl = global.fetch;
  if (!fetchImpl) {
    throw new Error('Node.js < 18 requires node-fetch. Run: npm install node-fetch@2');
  }
}
const fetch = (...args) => fetchImpl(...args);

const app = express();
const PORT = process.env.PORT || 3000;
const CONFIG_FILE = path.join(__dirname, 'config.json');
const DEFAULT_CONFIG = {
  backendBaseUrl: 'http://192.168.101.21:10099',
};

app.use(cors());
app.use(express.json({ limit: '20mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, 'public')));

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 25 * 1024 * 1024,
  },
});

function ensureConfigFile() {
  if (!fs.existsSync(CONFIG_FILE)) {
    fs.writeFileSync(CONFIG_FILE, JSON.stringify(DEFAULT_CONFIG, null, 2));
  }
}

function loadConfig() {
  ensureConfigFile();
  try {
    const raw = fs.readFileSync(CONFIG_FILE, 'utf-8');
    const parsed = JSON.parse(raw);
    return {
      ...DEFAULT_CONFIG,
      ...(parsed && typeof parsed === 'object' ? parsed : {}),
    };
  } catch (_) {
    return { ...DEFAULT_CONFIG };
  }
}

function saveConfig(nextConfig) {
  fs.writeFileSync(CONFIG_FILE, JSON.stringify(nextConfig, null, 2));
}

function normalizeBaseUrl(value) {
  return String(value || DEFAULT_CONFIG.backendBaseUrl).trim().replace(/\/+$/, '');
}

function getBackendBaseUrl() {
  return normalizeBaseUrl(loadConfig().backendBaseUrl);
}

function buildBackendUrl(targetPath) {
  const normalizedPath = String(targetPath || '').startsWith('/')
    ? targetPath
    : `/${targetPath}`;
  return `${getBackendBaseUrl()}${normalizedPath}`;
}

function readToken(req) {
  const authHeader = String(req.headers.authorization || '').trim();
  const tokenHeader = String(req.headers.token || '').trim();
  if (tokenHeader) {
    return tokenHeader;
  }
  if (authHeader.toLowerCase().startsWith('bearer ')) {
    return authHeader.slice(7).trim();
  }
  return '';
}

function buildTokenHeaders(req, extraHeaders = {}) {
  const token = readToken(req);
  return {
    ...(token ? { Authorization: `Bearer ${token}`, token } : {}),
    ...extraHeaders,
  };
}

async function readResponsePayload(response) {
  const rawText = await response.text();
  let payload = {};
  if (rawText) {
    try {
      payload = JSON.parse(rawText);
    } catch (_) {
      payload = { raw: rawText };
    }
  }
  return {
    ok: response.ok,
    status: response.status,
    payload,
  };
}

function unwrapEnvelope(payload) {
  if (payload && typeof payload === 'object' && payload.data !== undefined) {
    return payload.data;
  }
  return payload;
}

function readErrorMessage(payload, fallback) {
  if (payload && typeof payload === 'object') {
    for (const key of ['msg', 'message', 'detail', 'error']) {
      if (payload[key]) {
        return String(payload[key]);
      }
    }
  }
  const data = unwrapEnvelope(payload);
  if (typeof data === 'string' && data.trim()) {
    return data.trim();
  }
  if (data && typeof data === 'object') {
    const error = data.error;
    if (error && typeof error === 'object') {
      for (const key of ['message', 'detail', 'code']) {
        if (error[key]) {
          return String(error[key]);
        }
      }
    }
    for (const key of ['detail', 'msg', 'message', 'error']) {
      if (data[key]) {
        return String(data[key]);
      }
    }
  }
  return fallback;
}

function resolvePublicUrl(rawUrl) {
  const normalized = String(rawUrl || '').trim();
  if (!normalized) {
    return '';
  }
  if (/^https?:\/\//i.test(normalized)) {
    return normalized;
  }
  return `${getBackendBaseUrl()}${normalized.startsWith('/') ? normalized : `/${normalized}`}`;
}

function isBackendAssetUrl(url) {
  return String(url || '').toLowerCase().startsWith(getBackendBaseUrl().toLowerCase());
}

function sanitizeDownloadFilename(filename, fallback = 'video.mp4') {
  const normalized = String(filename || '').trim();
  const candidate = normalized || fallback;
  return candidate.replace(/[<>:"/\\|?*\u0000-\u001f]+/g, '_').slice(0, 180) || fallback;
}

function buildContentDisposition(filename) {
  const normalized = sanitizeDownloadFilename(filename, 'video.mp4');
  const asciiFallback = normalized.replace(/[^\x20-\x7E]+/g, '_') || 'video.mp4';
  const encoded = encodeURIComponent(normalized).replace(/['()]/g, escape).replace(/\*/g, '%2A');
  return `attachment; filename="${asciiFallback}"; filename*=UTF-8''${encoded}`;
}

function readDownloadFilename(targetUrl, fallback = 'video.mp4') {
  try {
    const parsed = new URL(targetUrl);
    const basename = path.basename(parsed.pathname || '') || fallback;
    return sanitizeDownloadFilename(basename, fallback);
  } catch (_) {
    return sanitizeDownloadFilename(fallback, fallback);
  }
}

function normalizeUploadedFiles(payload) {
  const data = unwrapEnvelope(payload);
  const files = Array.isArray(data?.images) ? data.images : Array.isArray(data) ? data : [];
  return files.map((item) => ({
    url: resolvePublicUrl(item?.url || item?.path || ''),
    name: String(item?.name || item?.file_name || 'image'),
  }));
}

function normalizeTask(task) {
  const assets = Array.isArray(task?.assets) ? task.assets : [];
  const images = assets
    .filter((asset) => (asset?.asset_type || 'reference_image') === 'reference_image')
    .map((asset) => resolvePublicUrl(asset?.file_url || ''))
    .filter(Boolean);
  const requestContext =
    task?.request_context && typeof task.request_context === 'object'
      ? task.request_context
      : {};

  return {
    id: String(task?.id || ''),
    prompt: String(task?.prompt || ''),
    originalImages: images,
    duration: Number(task?.duration || 5),
    status: String(task?.status || 'processing'),
    videoUrl: resolvePublicUrl(task?.video_url || ''),
    taskId: String(task?.provider_task_id || ''),
    createdAt: task?.created_at || '',
    updatedAt: task?.updated_at || '',
    error: String(task?.error_message || ''),
    progress: Number(task?.progress || 0),
    mode: String(task?.creation_mode || requestContext.creation_mode || 'simple'),
    referenceLink: String(task?.reference_link || requestContext.reference_link || ''),
    referenceVideoPath: String(task?.reference_video_path || requestContext.reference_video_path || ''),
    promptTemplateKey: String(requestContext?.prompt_template?.key || ''),
    promptTemplateName: String(requestContext?.prompt_template?.name || ''),
    videoTemplateKey: String(requestContext?.video_template?.key || ''),
    videoTemplateName: String(requestContext?.video_template?.name || ''),
    rawTask: task,
  };
}

function requireToken(req, res, next) {
  if (!readToken(req)) {
    return res.status(401).json({
      success: false,
      error: '请先登录后再继续使用。',
    });
  }
  return next();
}

async function proxyJsonRequest(req, res, options) {
  const {
    method = 'GET',
    targetPath,
    body,
    headers = {},
    auth = true,
    successMapper,
    fallbackError = '请求失败',
  } = options;

  try {
    const response = await fetch(buildBackendUrl(targetPath), {
      method,
      headers: {
        ...(auth ? buildTokenHeaders(req) : {}),
        ...headers,
      },
      body,
    });
    const result = await readResponsePayload(response);
    if (!result.ok) {
      return res.status(result.status).json({
        success: false,
        error: readErrorMessage(result.payload, fallbackError),
      });
    }

    if (typeof successMapper === 'function') {
      return res.json(successMapper(result.payload));
    }

    return res.json({
      success: true,
      data: unwrapEnvelope(result.payload),
    });
  } catch (error) {
    return res.status(502).json({
      success: false,
      error: error.message || fallbackError,
    });
  }
}

app.get('/api/proxy-config', (req, res) => {
  const config = loadConfig();
  res.json({
    success: true,
    backendBaseUrl: normalizeBaseUrl(config.backendBaseUrl),
  });
});

app.post('/api/proxy-config', (req, res) => {
  const nextConfig = {
    ...DEFAULT_CONFIG,
    ...loadConfig(),
  };
  if (req.body && req.body.backendBaseUrl) {
    nextConfig.backendBaseUrl = normalizeBaseUrl(req.body.backendBaseUrl);
  }
  saveConfig(nextConfig);
  res.json({
    success: true,
    backendBaseUrl: nextConfig.backendBaseUrl,
  });
});

app.get('/api/config', requireToken, (req, res) =>
  proxyJsonRequest(req, res, {
    targetPath: '/api/config',
    successMapper: (payload) => ({
      success: true,
      ...(unwrapEnvelope(payload) || {}),
    }),
    fallbackError: '读取 AI 配置失败',
  })
);

app.post('/api/config', requireToken, (req, res) =>
  proxyJsonRequest(req, res, {
    method: 'POST',
    targetPath: '/api/config',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      llmBaseUrl: String(req.body?.llmBaseUrl || '').trim(),
      llmApiKey: String(req.body?.llmApiKey || '').trim(),
      llmModel: String(req.body?.llmModel || '').trim(),
      videoBaseUrl: String(req.body?.videoBaseUrl || '').trim(),
      videoApiKey: String(req.body?.videoApiKey || '').trim(),
      videoModel: String(req.body?.videoModel || '').trim(),
      speechBaseUrl: String(req.body?.speechBaseUrl || '').trim(),
      speechApiKey: String(req.body?.speechApiKey || '').trim(),
      speechModel: String(req.body?.speechModel || '').trim(),
    }),
    successMapper: (payload) => ({
      success: true,
      ...(unwrapEnvelope(payload) || {}),
    }),
    fallbackError: '保存 AI 配置失败',
  })
);

app.post('/api/auth/login', async (req, res) => {
  const username = String(req.body?.username || '').trim();
  const password = String(req.body?.password || '').trim();

  if (!username || !password) {
    return res.status(400).json({
      success: false,
      error: '请输入账号和密码。',
    });
  }

  try {
    const loginResponse = await fetch(buildBackendUrl('/api/v1/base/access_token'), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ username, password }),
    });
    const loginResult = await readResponsePayload(loginResponse);
    if (!loginResult.ok) {
      return res.status(loginResult.status).json({
        success: false,
        error: readErrorMessage(loginResult.payload, '登录失败'),
      });
    }

    const session = unwrapEnvelope(loginResult.payload) || {};
    const accessToken = String(session.access_token || '').trim();
    if (!accessToken) {
      return res.status(502).json({
        success: false,
        error: '登录接口未返回有效 token。',
      });
    }

    let user = null;
    try {
      const userResponse = await fetch(buildBackendUrl('/api/v1/base/userinfo'), {
        headers: {
          Authorization: `Bearer ${accessToken}`,
          token: accessToken,
        },
      });
      const userResult = await readResponsePayload(userResponse);
      if (userResult.ok) {
        user = unwrapEnvelope(userResult.payload);
      }
    } catch (_) {
      user = null;
    }

    return res.json({
      success: true,
      accessToken,
      username: String(session.username || username),
      user,
    });
  } catch (error) {
    return res.status(502).json({
      success: false,
      error: error.message || '登录失败',
    });
  }
});

app.get('/api/auth/me', requireToken, (req, res) =>
  proxyJsonRequest(req, res, {
    targetPath: '/api/v1/base/userinfo',
    successMapper: (payload) => ({
      success: true,
      user: unwrapEnvelope(payload),
    }),
    fallbackError: '获取用户信息失败',
  })
);

app.post('/api/auth/forgot-password', async (req, res) => {
  const username = String(req.body?.username || '').trim();
  const email = String(req.body?.email || '').trim();
  const newPassword = String(req.body?.newPassword || '').trim();

  if (!username || !email || !newPassword) {
    return res.status(400).json({
      success: false,
      error: '请完整填写账号、邮箱和新密码。',
    });
  }

  return proxyJsonRequest(req, res, {
    method: 'POST',
    targetPath: '/api/v1/base/forgot_password',
    auth: false,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      username,
      email,
      new_password: newPassword,
    }),
    successMapper: (payload) => ({
      success: true,
      message: readErrorMessage(payload, '密码已重置'),
    }),
    fallbackError: '重置密码失败',
  });
});

app.post('/api/auth/change-password', requireToken, (req, res) => {
  const oldPassword = String(req.body?.oldPassword || '').trim();
  const newPassword = String(req.body?.newPassword || '').trim();

  if (!oldPassword || !newPassword) {
    return res.status(400).json({
      success: false,
      error: '请完整填写旧密码和新密码。',
    });
  }

  return proxyJsonRequest(req, res, {
    method: 'POST',
    targetPath: '/api/v1/base/change_password',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      old_password: oldPassword,
      new_password: newPassword,
    }),
    successMapper: (payload) => ({
      success: true,
      message: readErrorMessage(payload, '密码修改成功'),
    }),
    fallbackError: '修改密码失败',
  });
});

app.post('/api/auth/update-profile', requireToken, (req, res) =>
  proxyJsonRequest(req, res, {
    method: 'POST',
    targetPath: '/api/v1/base/update_profile',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: String(req.body?.email || '').trim(),
      alias: String(req.body?.alias || '').trim(),
      phone: String(req.body?.phone || '').trim(),
    }),
    successMapper: (payload) => ({
      success: true,
      user: unwrapEnvelope(payload),
    }),
    fallbackError: '更新资料失败',
  })
);

app.post('/api/auth/logout', (req, res) => {
  res.json({ success: true });
});

app.get('/api/create-workbench', requireToken, (req, res) =>
  proxyJsonRequest(req, res, {
    targetPath: '/api/create-workbench',
    successMapper: (payload) => ({
      success: true,
      workbench: unwrapEnvelope(payload),
    }),
    fallbackError: '读取创作配置失败',
  })
);

app.get('/api/prompt-templates', requireToken, (req, res) =>
  proxyJsonRequest(req, res, {
    targetPath: '/api/prompt-templates',
    successMapper: (payload) => ({
      success: true,
      items: unwrapEnvelope(payload)?.items || [],
    }),
    fallbackError: '读取提示词模板失败',
  })
);

app.get('/api/video-templates', requireToken, (req, res) =>
  proxyJsonRequest(req, res, {
    targetPath: '/api/video-templates',
    successMapper: (payload) => ({
      success: true,
      items: unwrapEnvelope(payload)?.items || [],
    }),
    fallbackError: '读取视频模板失败',
  })
);

app.post('/api/upload-images', requireToken, upload.array('images', 3), async (req, res) => {
  if (!req.files || !req.files.length) {
    return res.status(400).json({
      success: false,
      error: '请先选择图片。',
    });
  }

  const form = new FormData();
  req.files.forEach((file) => {
    form.append('images', file.buffer, {
      filename: file.originalname || 'image.jpg',
      contentType: file.mimetype || 'application/octet-stream',
    });
  });

  return proxyJsonRequest(req, res, {
    method: 'POST',
    targetPath: '/api/upload-images',
    headers: form.getHeaders(),
    body: form,
    successMapper: (payload) => ({
      success: true,
      files: normalizeUploadedFiles(payload),
    }),
    fallbackError: '上传图片失败',
  });
});

app.post('/api/upload-reference-video', requireToken, upload.single('video'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({
      success: false,
      error: '请先选择参考视频。',
    });
  }

  const form = new FormData();
  form.append('video', req.file.buffer, {
    filename: req.file.originalname || 'reference.mp4',
    contentType: req.file.mimetype || 'application/octet-stream',
  });

  return proxyJsonRequest(req, res, {
    method: 'POST',
    targetPath: '/api/upload-reference-video',
    headers: form.getHeaders(),
    body: form,
    successMapper: (payload) => {
      const data = unwrapEnvelope(payload) || {};
      return {
        success: true,
        file: {
          url: resolvePublicUrl(data.url || data.path || ''),
          name: String(data.name || 'reference.mp4'),
        },
      };
    },
    fallbackError: '上传参考视频失败',
  });
});

app.post('/api/correct-text', requireToken, (req, res) =>
  proxyJsonRequest(req, res, {
    method: 'POST',
    targetPath: '/api/correct-text',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text: String(req.body?.text || '').trim() }),
    successMapper: (payload) => {
      const data = unwrapEnvelope(payload) || {};
      return {
        success: true,
        text: String(data.text || data.result || data.content || '').trim(),
      };
    },
    fallbackError: 'AI 校验失败',
  })
);

app.post('/api/_unused/polish-text', requireToken, (req, res) =>
  proxyJsonRequest(req, res, {
    method: 'POST',
    targetPath: '/api/_unused/polish-text',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text: String(req.body?.text || '').trim() }),
    successMapper: (payload) => {
      const data = unwrapEnvelope(payload) || {};
      return {
        success: true,
        text: String(data.text || data.result || data.content || '').trim(),
      };
    },
    fallbackError: 'AI 校验失败',
  })
);

app.post('/api/generate-prompt', requireToken, (req, res) =>
  proxyJsonRequest(req, res, {
    method: 'POST',
    targetPath: '/api/generate-prompt',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      text: String(req.body?.text || '').trim(),
      ...(req.body?.promptTemplateKey
        ? { prompt_template_key: String(req.body.promptTemplateKey) }
        : {}),
    }),
    successMapper: (payload) => {
      const data = unwrapEnvelope(payload) || {};
      return {
        success: true,
        prompt: String(data.prompt || data.text || data.result || '').trim(),
      };
    },
    fallbackError: '提示词生成失败',
  })
);

app.post('/api/speech-to-text', requireToken, upload.single('audio'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({
      success: false,
      error: '请先选择音频文件。',
    });
  }

  const form = new FormData();
  form.append('audio', req.file.buffer, {
    filename: req.file.originalname || 'voice.wav',
    contentType: req.file.mimetype || 'application/octet-stream',
  });

  return proxyJsonRequest(req, res, {
    method: 'POST',
    targetPath: '/api/voice/transcribe',
    headers: form.getHeaders(),
    body: form,
    successMapper: (payload) => {
      const data = unwrapEnvelope(payload) || {};
      return {
        success: true,
        text: String(data.text || '').trim(),
      };
    },
    fallbackError: '语音识别失败',
  });
});

app.post('/api/generate-video', requireToken, (req, res) => {
  const mode = String(req.body?.mode || 'simple').trim().toLowerCase();
  const images = Array.isArray(req.body?.images)
    ? req.body.images.map((item) => String(item || '').trim()).filter(Boolean)
    : [];
  const duration = Number(req.body?.duration || 5) || 5;
  const inputText = String(req.body?.inputText || '').trim();
  const polishedText = String(req.body?.polishedText || '').trim();
  const prompt = String(req.body?.prompt || '').trim();
  const referenceLink = String(req.body?.referenceLink || '').trim();
  const referenceVideoPath = String(req.body?.referenceVideoPath || '').trim();

  let targetPath = '/api/tasks';
  let payload = {
    input_text: inputText || undefined,
    polished_text: polishedText || undefined,
    prompt,
    images,
    duration,
  };

  if (mode === 'starter') {
    targetPath = '/api/starter-tasks';
    payload = {
      input_text: inputText || undefined,
      prompt: prompt || undefined,
      images,
      duration,
      reference_link: referenceLink,
    };
  } else if (mode === 'custom') {
    targetPath = '/api/custom-tasks';
    payload = {
      input_text: inputText || undefined,
      prompt: prompt || undefined,
      images,
      duration,
      video_template_key: String(req.body?.videoTemplateKey || '').trim(),
      reference_link: referenceLink || undefined,
      reference_video_path: referenceVideoPath || undefined,
    };
  }

  if (req.body?.promptTemplateKey) {
    payload.prompt_template_key = String(req.body.promptTemplateKey).trim();
  }
  if (req.body?.videoTemplateKey && mode !== 'custom') {
    payload.video_template_key = String(req.body.videoTemplateKey).trim();
  }
  if (req.body?.supplementalText) {
    payload.supplemental_text = String(req.body.supplementalText).trim();
  }

  return proxyJsonRequest(req, res, {
    method: 'POST',
    targetPath,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
    successMapper: (responsePayload) => {
      const task = unwrapEnvelope(responsePayload) || {};
      return {
        success: true,
        record: normalizeTask(task),
      };
    },
    fallbackError: '视频生成失败',
  });
});

app.get('/api/video-status/:id', requireToken, (req, res) =>
  proxyJsonRequest(req, res, {
    targetPath: `/api/tasks/${encodeURIComponent(req.params.id)}`,
    successMapper: (payload) => {
      const task = unwrapEnvelope(payload) || {};
      return {
        success: true,
        record: normalizeTask(task),
      };
    },
    fallbackError: '获取任务状态失败',
  })
);

app.get('/api/history', requireToken, (req, res) => {
  const page = Math.max(Number(req.query.page || 1) || 1, 1);
  const limit = Math.max(Number(req.query.limit || 10) || 10, 1);
  const filter = String(req.query.filter || 'all');
  const query = new URLSearchParams({
    page: String(page),
    limit: String(limit),
    filter,
  });

  return proxyJsonRequest(req, res, {
    targetPath: `/api/tasks?${query.toString()}`,
    successMapper: (payload) => {
      const data = unwrapEnvelope(payload) || {};
      const records = Array.isArray(data.items)
        ? data.items.map((item) => normalizeTask(item))
        : [];
      const total = Number(data.total || records.length);
      return {
        success: true,
        records,
        total,
        page,
        totalPages: Math.max(Math.ceil(total / limit), 1),
      };
    },
    fallbackError: '加载记录失败',
  });
});

app.get('/api/history-summary', requireToken, (req, res) =>
  proxyJsonRequest(req, res, {
    targetPath: '/api/tasks/summary',
    successMapper: (payload) => ({
      success: true,
      summary: unwrapEnvelope(payload) || {},
    }),
    fallbackError: '读取历史统计失败',
  })
);

app.delete('/api/history', requireToken, (req, res) =>
  proxyJsonRequest(req, res, {
    method: 'DELETE',
    targetPath: '/api/tasks',
    successMapper: () => ({
      success: true,
    }),
    fallbackError: '清空记录失败',
  })
);

app.delete('/api/history/:id', requireToken, (req, res) =>
  proxyJsonRequest(req, res, {
    method: 'DELETE',
    targetPath: `/api/tasks/${encodeURIComponent(req.params.id)}`,
    successMapper: () => ({
      success: true,
    }),
    fallbackError: '删除记录失败',
  })
);

app.get('/api/app-release/latest', (req, res) => {
  const query = new URLSearchParams({
    platform: String(req.query.platform || 'android').trim() || 'android',
    channel: String(req.query.channel || 'lan').trim() || 'lan',
    current_version: String(req.query.currentVersion || '1.0.0').trim() || '1.0.0',
    current_build_number: String(req.query.currentBuildNumber || '1').trim() || '1',
  });

  return proxyJsonRequest(req, res, {
    targetPath: `/api/app/releases/latest?${query.toString()}`,
    auth: false,
    successMapper: (payload) => ({
      success: true,
      info: unwrapEnvelope(payload) || {},
    }),
    fallbackError: '检查版本失败',
  });
});

app.get('/api/download-video', requireToken, async (req, res) => {
  const rawUrl = String(req.query.url || '').trim();
  const targetUrl = resolvePublicUrl(rawUrl);
  if (!targetUrl) {
    return res.status(400).json({
      success: false,
      error: '缺少可下载的视频地址。',
    });
  }

  const filename = sanitizeDownloadFilename(
    String(req.query.filename || '').trim(),
    readDownloadFilename(targetUrl),
  );

  try {
    const response = await fetch(targetUrl, {
      headers: isBackendAssetUrl(targetUrl) ? buildTokenHeaders(req) : {},
    });
    if (!response.ok) {
      const result = await readResponsePayload(response);
      return res.status(response.status).json({
        success: false,
        error: readErrorMessage(result.payload, '下载视频失败'),
      });
    }

    const contentType = response.headers.get('content-type') || 'application/octet-stream';
    const contentLength = response.headers.get('content-length');
    res.setHeader('Content-Type', contentType);
    if (contentLength) {
      res.setHeader('Content-Length', contentLength);
    }
    res.setHeader('Content-Disposition', buildContentDisposition(filename));
    response.body.pipe(res);
    return undefined;
  } catch (error) {
    return res.status(502).json({
      success: false,
      error: error.message || '下载视频失败',
    });
  }
});

app.listen(PORT, () => {
  console.log(`\n拾光视频 Web 演示已启动`);
  console.log(`访问地址: http://localhost:${PORT}`);
  console.log(`后端服务: ${getBackendBaseUrl()}\n`);
});
