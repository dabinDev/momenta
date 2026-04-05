<template>
  <main class="auth-page">
    <div class="auth-page__layout">
      <AuthHero />
      <section class="auth-form-card">
        <p class="eyebrow">账号登录</p>
        <h2>账号登录</h2>
        <p class="auth-form-card__copy">请输入与 App 共用的用户名和密码。</p>

        <form class="form-stack" @submit.prevent="submit">
          <label class="field">
            <span>用户名</span>
            <input v-model.trim="form.username" type="text" autocomplete="username" placeholder="请输入用户名" />
          </label>
          <label class="field">
            <span>密码</span>
            <input
              v-model.trim="form.password"
              type="password"
              autocomplete="current-password"
              placeholder="请输入密码"
            />
          </label>
          <button class="primary-btn" type="submit" :disabled="submitting">
            {{ submitting ? '登录中...' : '登录' }}
          </button>
        </form>

        <div class="auth-form-card__links">
          <button type="button" class="text-link" @click="router.push('/forgot-password')">忘记密码</button>
          <button type="button" class="text-link" @click="router.push('/register')">注册账号</button>
        </div>
      </section>
    </div>
  </main>
</template>

<script setup>
import { reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import AuthHero from '@/components/AuthHero.vue'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()
const toastStore = useToastStore()

const form = reactive({
  username: String(route.query.username || authStore.user?.username || ''),
  password: '',
})
const submitting = ref(false)

async function submit() {
  if (!form.username || !form.password) {
    toastStore.push('请输入账号和密码', 'warn')
    return
  }

  submitting.value = true
  try {
    await authStore.login({
      username: form.username,
      password: form.password,
    })
    toastStore.push('登录成功', 'success')
    router.replace(String(route.query.redirect || '/app/create'))
  } catch (error) {
    toastStore.push(error.message || '登录失败', 'danger')
  } finally {
    submitting.value = false
  }
}
</script>
