<template>
  <AppPage :show-footer="false">
    <div class="login-page">
      <div class="login-page__ambient login-page__ambient--left" />
      <div class="login-page__ambient login-page__ambient--right" />

      <div class="login-shell">
        <section class="login-poster">
          <div class="login-poster__brand">
            <div class="login-poster__logo">
              <icon-custom-logo text-42 color-primary />
            </div>
            <div>
              <p class="login-poster__eyebrow">Momenta Admin</p>
              <h1>{{ $t('app_name') }}</h1>
            </div>
          </div>

          <div class="login-poster__copy">
            <h2>统一管理用户、记录和应用配置。</h2>
            <p>保持清晰的工作流，把主要操作留在视线里，把多余噪音收起来。</p>
          </div>

          <div class="login-poster__badges">
            <span>用户管理</span>
            <span>历史记录</span>
            <span>账号安全</span>
          </div>

          <div class="login-poster__visual" :style="{ backgroundImage: `url(${bgImg})` }" />
        </section>

        <section class="login-panel">
          <div class="login-panel__head">
            <p class="login-panel__eyebrow">后台登录</p>
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
              show-password-on="click"
              placeholder="请输入密码"
              :maxlength="20"
              @keydown.enter="handleLogin"
            />

            <div class="login-panel__meta">
              <span>仅限已授权账号登录</span>
              <span>登录后进入左侧菜单工作区</span>
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
    console.error('login error', e)
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page {
  position: relative;
  display: flex;
  min-height: 100%;
  overflow: hidden;
  border-radius: 32px;
}

.login-page__ambient {
  position: absolute;
  border-radius: 999px;
  filter: blur(10px);
  pointer-events: none;
}

.login-page__ambient--left {
  top: 6%;
  left: -4%;
  width: 260px;
  height: 260px;
  background: var(--ambient-amber);
}

.login-page__ambient--right {
  right: -6%;
  bottom: 2%;
  width: 320px;
  height: 320px;
  background: var(--ambient-jade);
}

.login-shell {
  position: relative;
  z-index: 1;
  display: grid;
  width: 100%;
  max-width: 1180px;
  min-height: 100%;
  margin: 0 auto;
  grid-template-columns: minmax(0, 1.15fr) minmax(360px, 420px);
  gap: 24px;
}

.login-poster,
.login-panel {
  border: 1px solid var(--shell-border);
  border-radius: 32px;
  backdrop-filter: blur(18px);
}

.login-poster {
  display: grid;
  grid-template-rows: auto auto auto minmax(280px, 1fr);
  gap: 24px;
  padding: 28px;
  background: var(--login-poster-bg);
  box-shadow: var(--panel-shadow);
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
  border-radius: 22px;
  background: var(--sidebar-mark-bg);
  box-shadow: inset 0 0 0 1px var(--sidebar-mark-ring), var(--soft-shadow);
}

.login-poster__eyebrow,
.login-panel__eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
}

.login-poster__brand h1 {
  margin: 0;
  font-size: 28px;
  font-weight: 700;
  color: var(--app-text);
}

.login-poster__copy h2 {
  max-width: 520px;
  margin: 0;
  font-size: 42px;
  line-height: 1.08;
  font-weight: 700;
  color: var(--app-text);
}

.login-poster__copy p {
  max-width: 460px;
  margin: 14px 0 0;
  font-size: 16px;
  line-height: 1.7;
  color: var(--app-muted);
}

.login-poster__badges {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.login-poster__badges span {
  padding: 9px 14px;
  border: 1px solid var(--shell-border);
  border-radius: 999px;
  background: var(--surface-card-strong);
  font-size: 13px;
  font-weight: 700;
  color: var(--app-text);
}

.login-poster__visual {
  min-height: 280px;
  border-radius: 28px;
  background-position: center;
  background-size: cover;
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.18), var(--soft-shadow);
}

.login-panel {
  align-self: center;
  padding: 32px 30px;
  background: var(--login-panel-bg);
  box-shadow: var(--panel-shadow);
}

.login-panel__head h3 {
  margin: 0;
  font-size: 30px;
  font-weight: 700;
  color: var(--app-text);
}

.login-panel__head p:last-child {
  margin: 10px 0 0;
  font-size: 14px;
  line-height: 1.7;
  color: var(--app-muted);
}

.login-panel__eyebrow {
  color: var(--app-muted);
}

.login-panel__form {
  display: grid;
  gap: 14px;
  margin-top: 28px;
}

.login-field {
  --n-height: 56px;
  --n-padding-left: 18px;
  --n-padding-right: 18px;
  --n-border-radius: 18px;
  --n-color: var(--control-bg);
  --n-color-focus: var(--control-bg-focus);
  --n-text-color: var(--control-text);
  --n-caret-color: var(--primary-color);
  --n-placeholder-color: var(--control-muted);
  --n-border: 1px solid var(--shell-border);
  --n-border-hover: 1px solid rgba(47, 111, 103, 0.22);
  --n-border-focus: 1px solid var(--primary-color);
  --n-box-shadow-focus: 0 0 0 4px rgba(47, 111, 103, 0.14);
  --n-font-size: 16px;
}

.login-field :deep(.n-input__input-el),
.login-field :deep(.n-input__textarea-el) {
  caret-color: var(--primary-color);
  font-weight: 600;
}

.login-field :deep(.n-input__suffix) {
  color: var(--app-muted);
}

.login-panel__meta {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  font-size: 12px;
  color: var(--app-muted);
}

.login-panel__submit {
  height: 56px;
  margin-top: 6px;
  border-radius: 18px;
  font-size: 16px;
  font-weight: 700;
}

@media (max-width: 980px) {
  .login-shell {
    grid-template-columns: 1fr;
  }

  .login-poster {
    grid-template-rows: auto auto auto 220px;
  }

  .login-panel {
    max-width: 460px;
  }
}

@media (max-width: 720px) {
  .login-page {
    border-radius: 24px;
  }

  .login-poster,
  .login-panel {
    border-radius: 24px;
  }

  .login-poster {
    padding: 22px;
    gap: 20px;
  }

  .login-poster__copy h2 {
    font-size: 30px;
  }

  .login-panel {
    padding: 24px 20px;
  }

  .login-panel__head h3 {
    font-size: 26px;
  }

  .login-panel__meta {
    flex-direction: column;
    gap: 6px;
  }
}
</style>
