<template>
  <AppPage :show-footer="false">
    <div class="login-page">
      <div class="login-page__glow login-page__glow--top" />
      <div class="login-page__glow login-page__glow--bottom" />

      <div class="login-shell">
        <section class="login-poster">
          <div class="login-poster__media" :style="{ backgroundImage: `url(${bgImg})` }" />
          <div class="login-poster__overlay" />

          <div class="login-poster__content">
            <div class="login-poster__brand">
              <div class="login-poster__logo">
                <img :src="brandLogo" alt="拾光视频" class="login-poster__logo-image" />
              </div>
              <div>
                <p class="login-poster__eyebrow">拾光视频后台</p>
                <h1>{{ $t('app_name') }}</h1>
              </div>
            </div>

            <div class="login-poster__headline">
              <span class="login-poster__badge">统一运营后台</span>
              <h2>用户、任务、语音与版本发布集中管理</h2>
              <p>左侧切换模块，右侧聚焦数据和操作，让后台更清晰、更稳定。</p>
            </div>

            <div class="login-poster__highlights">
              <article class="login-poster__highlight">
                <span>用户体系</span>
                <strong>账号、密码、资料与权限</strong>
              </article>
              <article class="login-poster__highlight">
                <span>业务联动</span>
                <strong>App、Backend、Admin 一体化</strong>
              </article>
              <article class="login-poster__highlight">
                <span>发布管理</span>
                <strong>语音、任务、版本统一追踪</strong>
              </article>
            </div>
          </div>
        </section>

        <section class="login-panel">
          <div class="login-panel__head">
            <p class="login-panel__eyebrow">安全登录</p>
            <h3>欢迎回来</h3>
            <p>输入账号和密码后继续操作。</p>
          </div>

          <div class="login-panel__form">
            <n-input
              v-model:value="loginInfo.username"
              autofocus
              class="login-field"
              placeholder="请输入用户名"
              :maxlength="20"
            />
            <n-input
              v-model:value="loginInfo.password"
              class="login-field"
              type="password"
              show-password-on="mousedown"
              placeholder="请输入密码"
              :maxlength="20"
              @keydown.enter="handleLogin"
            />

            <div class="login-panel__tips">
              <div class="login-panel__tip">
                <span>登录范围</span>
                <strong>仅限已授权账号</strong>
              </div>
              <div class="login-panel__tip">
                <span>进入方式</span>
                <strong>登录后从左侧菜单进入模块</strong>
              </div>
            </div>

            <n-button
              class="login-panel__submit"
              type="primary"
              :loading="loading"
              @click="handleLogin"
            >
              {{ $t('views.login.text_login') }}
            </n-button>
          </div>
        </section>
      </div>
    </div>
  </AppPage>
</template>

<script setup>
import { lStorage, setToken } from '@/utils'
import bgImg from '@/assets/images/login_bg.webp'
import api from '@/api'
import { addDynamicRoutes } from '@/router'
import { useI18n } from 'vue-i18n'

const router = useRouter()
const { query } = useRoute()
const { t } = useI18n({ useScope: 'global' })
const brandLogo = `${import.meta.env.BASE_URL}shiguang-icon.png`

const loginInfo = ref({
  username: '',
  password: '',
})

const loading = ref(false)

initLoginInfo()

function initLoginInfo() {
  const localLoginInfo = lStorage.get('loginInfo')
  if (localLoginInfo) {
    loginInfo.value.username = localLoginInfo.username || ''
    loginInfo.value.password = localLoginInfo.password || ''
  }
}

async function handleLogin() {
  const { username, password } = loginInfo.value
  if (!username || !password) {
    $message.warning(t('views.login.message_input_username_password'))
    return
  }
  try {
    loading.value = true
    $message.loading(t('views.login.message_verifying'))
    const res = await api.login({ username, password: password.toString() })
    lStorage.set('loginInfo', loginInfo.value)
    $message.success(t('views.login.message_login_success'))
    setToken(res.data.access_token)
    await addDynamicRoutes()
    if (query.redirect) {
      const path = query.redirect
      Reflect.deleteProperty(query, 'redirect')
      router.push({ path, query })
    } else {
      router.push('/')
    }
  } catch (e) {
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page {
  position: relative;
  min-height: 100%;
  overflow: hidden;
  border-radius: 20px;
}

.login-page__glow {
  position: absolute;
  border-radius: 999px;
  pointer-events: none;
}

.login-page__glow--top {
  top: 2%;
  left: -8%;
  width: 320px;
  height: 320px;
  background: rgba(255, 141, 58, 0.24);
  filter: blur(24px);
  opacity: 0.55;
}

.login-page__glow--bottom {
  right: -8%;
  bottom: -4%;
  width: 380px;
  height: 380px;
  background: rgba(255, 205, 135, 0.26);
  filter: blur(28px);
  opacity: 0.48;
}

.login-shell {
  position: relative;
  z-index: 1;
  display: grid;
  width: 100%;
  max-width: 1280px;
  min-height: 100%;
  margin: 0 auto;
  grid-template-columns: minmax(0, 1.22fr) minmax(360px, 430px);
  gap: 24px;
}

.login-poster,
.login-panel {
  position: relative;
  overflow: hidden;
  border: 1px solid var(--shell-border);
  border-radius: 20px;
  box-shadow: var(--panel-shadow);
}

.login-poster {
  display: flex;
  align-items: flex-end;
  min-height: 680px;
  background: #2a1408;
}

.login-poster__media,
.login-poster__overlay {
  position: absolute;
  inset: 0;
}

.login-poster__media {
  background-position: center;
  background-size: cover;
  transform: scale(1.04);
  animation: login-poster-float 20s ease-in-out infinite alternate;
}

.login-poster__overlay {
  background:
    linear-gradient(180deg, rgba(30, 15, 7, 0.18), rgba(30, 15, 7, 0.58)),
    linear-gradient(135deg, rgba(255, 106, 0, 0.64), rgba(255, 147, 51, 0.24) 52%, rgba(69, 25, 7, 0.28));
}

.login-poster__content {
  position: relative;
  z-index: 1;
  display: grid;
  gap: 24px;
  width: 100%;
  padding: 30px;
  color: #ffffff;
}

.login-poster__brand {
  display: flex;
  align-items: center;
  gap: 16px;
}

.login-poster__logo {
  display: grid;
  width: 64px;
  height: 64px;
  place-items: center;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.14);
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.18);
  backdrop-filter: blur(14px);
}

.login-poster__logo-image {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.login-poster__eyebrow,
.login-panel__eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.18em;
  text-transform: uppercase;
}

.login-poster__brand h1 {
  margin: 0;
  font-size: 30px;
  font-weight: 800;
  color: #ffffff;
}

.login-poster__headline {
  max-width: 580px;
}

.login-poster__badge {
  display: inline-flex;
  align-items: center;
  padding: 8px 14px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.16);
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.18);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.08em;
}

.login-poster__headline h2 {
  margin: 18px 0 0;
  font-size: 42px;
  line-height: 1.1;
  font-weight: 800;
}

.login-poster__headline p {
  margin: 16px 0 0;
  font-size: 16px;
  line-height: 1.72;
  color: rgba(255, 255, 255, 0.88);
}

.login-poster__highlights {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
}

.login-poster__highlight {
  padding: 14px 16px;
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.1);
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.12);
  backdrop-filter: blur(16px);
}

.login-poster__highlight span {
  display: block;
  font-size: 12px;
  color: rgba(255, 255, 255, 0.76);
}

.login-poster__highlight strong {
  display: block;
  margin-top: 8px;
  font-size: 15px;
  line-height: 1.5;
  color: #ffffff;
}

.login-panel {
  align-self: center;
  padding: 28px;
  background: rgba(255, 251, 248, 0.72);
  backdrop-filter: blur(24px);
}

.login-panel__head h3 {
  margin: 0;
  font-size: 28px;
  font-weight: 800;
  color: var(--app-text);
}

.login-panel__head p:last-child {
  margin: 12px 0 0;
  font-size: 14px;
  line-height: 1.7;
  color: var(--app-muted);
}

.login-panel__eyebrow {
  color: var(--brand-primary);
}

.login-panel__form {
  display: grid;
  gap: 16px;
  margin-top: 24px;
}

.login-field {
  --n-height: 58px;
  --n-padding-left: 18px;
  --n-padding-right: 18px;
  --n-border-radius: 14px;
  --n-color: var(--control-bg);
  --n-color-focus: var(--control-bg-focus);
  --n-text-color: var(--control-text);
  --n-caret-color: var(--brand-primary);
  --n-placeholder-color: var(--control-muted);
  --n-border: 1px solid var(--shell-border);
  --n-border-hover: 1px solid rgba(255, 105, 0, 0.28);
  --n-border-focus: 1px solid var(--brand-primary);
  --n-box-shadow-focus: 0 0 0 4px rgba(255, 105, 0, 0.14);
  --n-font-size: 16px;
}

.login-field :deep(.n-input__input-el) {
  caret-color: var(--brand-primary);
  font-weight: 600;
}

.login-panel__tips {
  display: grid;
  gap: 12px;
  margin-top: 4px;
}

.login-panel__tip {
  display: grid;
  gap: 4px;
  padding: 12px 14px;
  border: 1px solid rgba(255, 105, 0, 0.08);
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.5);
}

.login-panel__tip span {
  font-size: 12px;
  color: var(--app-muted);
}

.login-panel__tip strong {
  color: var(--app-text);
}

.login-panel__submit {
  height: 58px;
  margin-top: 4px;
  border-radius: 14px;
  font-size: 16px;
  font-weight: 800;
}

@keyframes login-poster-float {
  from {
    transform: scale(1.02) translate3d(0, 0, 0);
  }

  to {
    transform: scale(1.08) translate3d(-10px, -12px, 0);
  }
}

@media (max-width: 1080px) {
  .login-shell {
    grid-template-columns: 1fr;
  }

  .login-poster {
    min-height: 540px;
  }

  .login-panel {
    max-width: 500px;
  }
}

@media (max-width: 720px) {
  .login-page,
  .login-poster,
  .login-panel {
    border-radius: 16px;
  }

  .login-poster__content,
  .login-panel {
    padding: 18px;
  }

  .login-poster__headline h2 {
    font-size: 34px;
  }

  .login-poster__highlights {
    grid-template-columns: 1fr;
  }
}
</style>
