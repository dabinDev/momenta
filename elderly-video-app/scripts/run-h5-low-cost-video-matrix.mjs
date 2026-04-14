import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

import { chromium } from 'playwright';

const ADMIN_USERNAME = process.env.MOMENTA_ADMIN_USER || 'admin';
const ADMIN_PASSWORD = process.env.MOMENTA_ADMIN_PASSWORD || '123456';
const API_BASE_URL = process.env.MOMENTA_API_BASE_URL || 'http://127.0.0.1:10099';
const H5_BASE_URL = process.env.MOMENTA_H5_BASE_URL || 'http://127.0.0.1:3000';
const IMAGE_PATH =
  process.env.MOMENTA_TEST_IMAGE ||
  path.resolve(process.cwd(), '../.codex-test/fixtures/image-1.png');
const DEFAULT_VIDEO_MODEL =
  process.env.MOMENTA_DEFAULT_VIDEO_MODEL || 'veo_3_1-fast-components-4K';
const ONLY_MODELS = String(process.env.MOMENTA_ONLY_MODELS || '')
  .split(',')
  .map((item) => item.trim())
  .filter(Boolean);
const SUBMIT_TIMEOUT_MS = Number(process.env.MOMENTA_SUBMIT_TIMEOUT_MS || 90000);
const POLL_TIMEOUT_MS = Number(process.env.MOMENTA_POLL_TIMEOUT_MS || 20 * 60 * 1000);
const POLL_INTERVAL_MS = Number(process.env.MOMENTA_POLL_INTERVAL_MS || 15000);

const LOW_COST_MODELS = [
  {
    model: 'doubao-seedance-1-0-lite-i2v-250428',
    label: 'Doubao Seedance Lite I2V',
    expectedFamily: 'volc_video',
    expectsImageInput: true,
  },
  {
    model: 'gen4_turbo',
    label: 'Runway Gen4 Turbo',
    expectedFamily: 'runway_video',
    expectsImageInput: true,
  },
  {
    model: 'MiniMax-Hailuo-02',
    label: 'MiniMax Hailuo 02',
    expectedFamily: 'minimax_video',
    expectsImageInput: false,
  },
  {
    model: 'minimax/video-01-live',
    label: 'Replicate minimax/video-01-live',
    expectedFamily: 'replicate_video',
    expectsImageInput: true,
  },
];

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function httpJson(url, options = {}) {
  const response = await fetch(url, options);
  const text = await response.text();
  let body = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  return { response, body };
}

async function loginAdmin() {
  const { response, body } = await httpJson(`${API_BASE_URL}/api/v1/base/access_token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: ADMIN_USERNAME, password: ADMIN_PASSWORD }),
  });
  if (!response.ok || !body?.data?.access_token) {
    throw new Error(`admin login failed: ${response.status} ${JSON.stringify(body)}`);
  }
  return body.data.access_token;
}

async function getGlobalConfig(token) {
  const { response, body } = await httpJson(`${API_BASE_URL}/api/v1/app_config/global`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!response.ok || !body?.data) {
    throw new Error(`get global config failed: ${response.status} ${JSON.stringify(body)}`);
  }
  return body.data;
}

async function updateGlobalVideoModel(token, nextModel) {
  const current = await getGlobalConfig(token);
  const payload = {
    provider_base_url: current.provider_base_url || '',
    provider_api_key: current.provider_api_key || '',
    llm_base_url: current.llm_base_url || '',
    llm_api_key: current.llm_api_key || '',
    llm_model: current.llm_model || '',
    video_base_url: current.video_base_url || '',
    video_api_key: current.video_api_key || '',
    video_model: nextModel,
    speech_base_url: current.speech_base_url || '',
    speech_api_key: current.speech_api_key || '',
    speech_model: current.speech_model || '',
    image_base_url: current.image_base_url || '',
    image_api_key: current.image_api_key || '',
    image_model: current.image_model || '',
    points_enabled: Boolean(current.points_enabled),
    recharge_enabled: Boolean(current.recharge_enabled),
    video_generation_cost: Number(current.video_generation_cost || 0),
    wechat_pay_enabled: Boolean(current.wechat_pay_enabled),
    alipay_pay_enabled: Boolean(current.alipay_pay_enabled),
  };
  const { response, body } = await httpJson(`${API_BASE_URL}/api/v1/app_config/global`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });
  if (!response.ok || !body?.data?.video_model) {
    throw new Error(`update global model failed: ${response.status} ${JSON.stringify(body)}`);
  }
  if (body.data.video_model !== nextModel) {
    throw new Error(`global model mismatch after update: wanted ${nextModel}, got ${body.data.video_model}`);
  }
  return body.data;
}

async function getTask(token, taskId) {
  const { response, body } = await httpJson(`${API_BASE_URL}/api/tasks/${taskId}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!response.ok || !body?.data) {
    throw new Error(`get task ${taskId} failed: ${response.status} ${JSON.stringify(body)}`);
  }
  return body.data;
}

async function loginH5(page) {
  await page.goto(`${H5_BASE_URL}/login`, {
    waitUntil: 'domcontentloaded',
    timeout: 60000,
  });
  await page.locator('input').nth(0).fill(ADMIN_USERNAME);
  await page.locator('input').nth(1).fill(ADMIN_PASSWORD);
  await page.locator('button').first().click();
  await page.waitForURL((url) => !/\/login\b/.test(url.toString()), { timeout: 20000 });
  await page.waitForSelector('textarea', { timeout: 20000 });
}

async function submitOneModel(page, token, entry, index) {
  const marker = `LOWCOST_${String(index + 1).padStart(2, '0')}_${Date.now()}`;
  entry.marker = marker;
  entry.submit_started_at = new Date().toISOString();

  await updateGlobalVideoModel(token, entry.model);
  entry.global_model_after_switch = (await getGlobalConfig(token)).video_model;

  await page.goto(`${H5_BASE_URL}/`, {
    waitUntil: 'domcontentloaded',
    timeout: 60000,
  });
  await page.waitForSelector('textarea', { timeout: 20000 });

  const inputText = `H5 smoke ${marker}`;
  const promptText = `A warm elderly portrait comes alive as a short natural motion video. Marker ${marker}. Model ${entry.model}.`;
  const fileInput = page.locator('input[type="file"]').first();
  const uploadResponsePromise = page.waitForResponse(
    (response) =>
      response.url().includes('/api/upload-images') &&
      response.request().method() === 'POST',
    { timeout: 60000 },
  );
  await fileInput.setInputFiles(IMAGE_PATH);
  const uploadResponse = await uploadResponsePromise;
  entry.upload_http_status = uploadResponse.status();
  if (uploadResponse.status() >= 400) {
    let uploadPayload = null;
    try {
      uploadPayload = await uploadResponse.json();
    } catch {
      uploadPayload = await uploadResponse.text();
    }
    entry.submit_ok = false;
    entry.submit_error = `image upload failed: ${uploadResponse.status()} ${JSON.stringify(uploadPayload)}`;
    entry.submit_finished_at = new Date().toISOString();
    return entry;
  }
  await page.waitForSelector('.upload-grid img', { timeout: 20000 });
  await page.locator('textarea').nth(0).fill(inputText);
  await page.locator('textarea').nth(1).fill(promptText);

  const createResponsePromise = page.waitForResponse(
    (response) =>
      response.url().includes('/api/tasks') &&
      response.request().method() === 'POST',
    { timeout: SUBMIT_TIMEOUT_MS },
  );

  await page.locator('button.primary-btn').click();

  let createResponse;
  try {
    createResponse = await createResponsePromise;
  } catch (error) {
    entry.submit_ok = false;
    entry.submit_error = `no task response within ${SUBMIT_TIMEOUT_MS}ms: ${error.message}`;
    entry.submit_finished_at = new Date().toISOString();
    return entry;
  }

  entry.submit_http_status = createResponse.status();
  let createPayload = null;
  try {
    createPayload = await createResponse.json();
  } catch {
    createPayload = await createResponse.text();
  }
  entry.submit_payload = createPayload;
  entry.submit_finished_at = new Date().toISOString();

  if (createResponse.status() >= 400 || !createPayload?.data?.id) {
    entry.submit_ok = false;
    entry.submit_error = createPayload?.msg || createPayload?.detail || `HTTP ${createResponse.status()}`;
    return entry;
  }

  entry.submit_ok = true;
  entry.task_id = String(createPayload.data.id);
  entry.task_snapshot = await getTask(token, entry.task_id);
  entry.provider = entry.task_snapshot.provider || '';
  entry.provider_model = entry.task_snapshot.provider_payload?.model || '';
  entry.initial_status = entry.task_snapshot.status || '';
  return entry;
}

async function pollTasks(token, entries) {
  const pending = entries.filter((item) => item.task_id);
  const startedAt = Date.now();

  while (pending.some((item) => !item.terminal_status)) {
    for (const item of pending) {
      if (item.terminal_status) {
        continue;
      }

      const task = await getTask(token, item.task_id);
      item.last_task = task;
      item.last_status = task.status || '';
      item.last_progress = Number(task.progress || 0);
      item.last_video_url = task.video_url || task.remote_video_url || '';
      item.last_provider_video_url = task.provider_payload?.provider_video_url || '';
      item.last_error_message = task.error_message || task.provider_payload?.error_message || '';
      item.last_provider_model = task.provider_payload?.model || item.provider_model || '';
      item.provider = task.provider || item.provider || '';

      if (['completed', 'failed'].includes(item.last_status)) {
        item.terminal_status = item.last_status;
        item.terminal_at = new Date().toISOString();
      }
    }

    if (pending.every((item) => item.terminal_status)) {
      break;
    }
    if (Date.now() - startedAt >= POLL_TIMEOUT_MS) {
      for (const item of pending.filter((it) => !it.terminal_status)) {
        item.terminal_status = 'timeout';
        item.terminal_at = new Date().toISOString();
      }
      break;
    }

    await sleep(POLL_INTERVAL_MS);
  }
}

async function main() {
  if (!fs.existsSync(IMAGE_PATH)) {
    throw new Error(`test image not found: ${IMAGE_PATH}`);
  }

  const token = await loginAdmin();
  const originalConfig = await getGlobalConfig(token);
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({
    viewport: { width: 1440, height: 1100 },
  });

  const report = {
    started_at: new Date().toISOString(),
    api_base_url: API_BASE_URL,
    h5_base_url: H5_BASE_URL,
    image_path: IMAGE_PATH,
    original_video_model: originalConfig.video_model,
    poll_timeout_ms: POLL_TIMEOUT_MS,
    poll_interval_ms: POLL_INTERVAL_MS,
    models: LOW_COST_MODELS.filter((item) => {
      if (!ONLY_MODELS.length) {
        return true;
      }
      return ONLY_MODELS.includes(item.model);
    }).map((item) => ({ ...item })),
  };

  try {
    await loginH5(page);
    for (const [index, entry] of report.models.entries()) {
      await submitOneModel(page, token, entry, index);
      if (entry.task_id) {
        await pollTasks(token, [entry]);
      }
    }
  } finally {
    try {
      await updateGlobalVideoModel(token, DEFAULT_VIDEO_MODEL);
    } catch (error) {
      report.restore_error = error.message;
    }
    await browser.close();
  }

  report.restored_video_model = (await getGlobalConfig(token)).video_model;
  report.finished_at = new Date().toISOString();
  report.summary = report.models.map((item) => ({
    model: item.model,
    provider: item.provider || '',
    provider_model: item.last_provider_model || item.provider_model || '',
    submit_ok: Boolean(item.submit_ok),
    submit_http_status: item.submit_http_status || null,
    task_id: item.task_id || '',
    terminal_status: item.terminal_status || '',
    last_status: item.last_status || '',
    last_progress: item.last_progress ?? null,
    has_video_url: Boolean(item.last_video_url),
    last_error_message: item.last_error_message || '',
    expected_family: item.expectedFamily,
    expects_image_input: item.expectsImageInput,
    marker: item.marker || '',
  }));

  console.log(JSON.stringify(report, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
