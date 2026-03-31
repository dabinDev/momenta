<template>
  <AppPage :show-footer="false">
    <div class="login-page" :style="{ backgroundImage: `url(${bgImg})` }">
      <div class="login-page__overlay" />

      <section class="login-hero">
        <div class="login-hero__brand">
          <div class="login-hero__logo">
            <icon-custom-logo text-42 color-primary />
          </div>
          <div>
            <p class="login-hero__eyebrow">Momenta Admin</p>
            <h1>{{ $t('app_name') }}</h1>
          </div>
        </div>

        <div class="login-hero__copy">
          <h2>用户、记录与配置在同一后台完成管理</h2>
          <p>保持简洁的工作流，让账号管理、审计日志和应用配置都能快速处理。</p>
        </div>

        <div class="login-hero__points">
          <div class="login-point">
            <span>用户体系</span>
            <strong>登录、改密、找回</strong>
          </div>
          <div class="login-point">
            <span>业务记录</span>
            <strong>历史与审计统一查看</strong>
          </div>
          <div class="login-point">
            <span>配置同步</span>
            <strong>App 与后台接口联动</strong>
          </div>
        </div>
      </section>

      <section class="login-panel">
        <p class="login-panel__eyebrow">后台登录</p>
        <h3>欢迎回来</h3>
        <p>请输入账号和密码。</p>

        <div class="login-panel__form">
          <n-input
            v-model:value="loginInfo.username"
            autofocus
            class="login-panel__input"
            placeholder="请输入用户名"
            :maxlength="20"
          />
          <n-input
            v-model:value="loginInfo.password"
            class="login-panel__input"
            type="password"
            show-password-on="mousedown"
            placeholder="请输入密码"
            :maxlength="20"
            @keypress.enter="handleLogin"
          />
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
    console.error('login error', e.error)
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-page {
  position: relative;
  display: grid;
  grid-template-columns: minmax(0, 1.15fr) minmax(360px, 420px);
  gap: 28px;
  min-height: calc(100vh - 30px);
  padding: 28px;
  border-radius: 32px;
  overflow: hidden;
  background-position: center;
  background-repeat: no-repeat;
  background-size: cover;
}

.login-page__overlay {
  position: absolute;
  inset: 0;
  background:
    linear-gradient(110deg, rgba(22, 39, 34, 0.68) 0%, rgba(22, 39, 34, 0.48) 40%, rgba(247, 250, 248, 0.88) 100%);
}

.login-hero,
.login-panel {
  position: relative;
  z-index: 1;
}

.login-hero {
  display: grid;
  align-content: space-between;
  gap: 28px;
  padding: 20px 16px 20px 8px;
  color: #fff;
}

.login-hero__brand {
  display: flex;
  align-items: center;
  gap: 14px;
}

.login-hero__logo {
  display: grid;
  place-items: center;
  width: 60px;
  height: 60px;
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.14);
  backdrop-filter: blur(10px);
}

.login-hero__eyebrow,
.login-panel__eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
}

.login-hero__brand h1 {
  margin: 0;
  font-size: 22px;
  font-weight: 700;
}

.login-hero__copy h2 {
  max-width: 540px;
  margin: 0;
  font-size: 42px;
  line-height: 1.08;
  font-weight: 700;
}

.login-hero__copy p {
  max-width: 520px;
  margin: 14px 0 0;
  font-size: 16px;
  line-height: 1.7;
  opacity: 0.9;
}

.login-hero__points {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 14px;
}

.login-point {
  padding: 16px 18px;
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.12);
  backdrop-filter: blur(10px);
}

.login-point span {
  display: block;
  font-size: 12px;
  opacity: 0.78;
}

.login-point strong {
  display: block;
  margin-top: 6px;
  font-size: 18px;
  line-height: 1.35;
}

.login-panel {
  align-self: center;
  padding: 30px 28px;
  border-radius: 28px;
  background: rgba(255, 255, 255, 0.88);
  backdrop-filter: blur(16px);
  box-shadow: 0 24px 70px rgba(34, 49, 41, 0.14);
}

.login-panel__eyebrow {
  color: #6f7a72;
}

.login-panel h3 {
  margin: 0;
  font-size: 30px;
  color: #223129;
}

.login-panel p {
  margin: 10px 0 0;
  font-size: 14px;
  color: #6a756e;
}

.login-panel__form {
  display: grid;
  gap: 14px;
  margin-top: 24px;
}

.login-panel__input {
  height: 52px;
}

.login-panel__submit {
  height: 52px;
  border-radius: 16px;
  font-size: 16px;
  font-weight: 700;
}

@media (max-width: 980px) {
  .login-page {
    grid-template-columns: 1fr;
    min-height: auto;
  }

  .login-hero {
    padding-right: 0;
  }

  .login-hero__copy h2 {
    font-size: 34px;
  }

  .login-panel {
    max-width: 480px;
  }
}

@media (max-width: 640px) {
  .login-page {
    padding: 18px;
    border-radius: 24px;
  }

  .login-hero__points {
    grid-template-columns: 1fr;
  }

  .login-hero__copy h2 {
    font-size: 28px;
  }

  .login-panel {
    padding: 24px 20px;
  }
}
</style>
