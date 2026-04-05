<template>
  <main class="auth-page">
    <div class="auth-page__layout">
      <AuthHero />
      <section class="auth-form-card">
        <p class="eyebrow">找回密码</p>
        <h2>重置密码</h2>
        <p class="auth-form-card__copy">通过用户名和邮箱直接重置登录密码。</p>

        <form class="form-stack" @submit.prevent="submit">
          <label class="field">
            <span>用户名</span>
            <input v-model.trim="form.username" type="text" placeholder="请输入用户名" />
          </label>
          <label class="field">
            <span>邮箱</span>
            <input v-model.trim="form.email" type="email" placeholder="请输入注册邮箱" />
          </label>
          <label class="field">
            <span>新密码</span>
            <input v-model.trim="form.newPassword" type="password" placeholder="请输入新密码" />
          </label>
          <label class="field">
            <span>确认密码</span>
            <input v-model.trim="form.confirmPassword" type="password" placeholder="请再次输入新密码" />
          </label>
          <button class="primary-btn" type="submit" :disabled="submitting">
            {{ submitting ? '提交中...' : '重置密码' }}
          </button>
        </form>

        <div class="auth-form-card__links auth-form-card__links--single">
          <button type="button" class="text-link" @click="router.push('/login')">返回登录</button>
        </div>
      </section>
    </div>
  </main>
</template>

<script setup>
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'

import AuthHero from '@/components/AuthHero.vue'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'

const router = useRouter()
const authStore = useAuthStore()
const toastStore = useToastStore()

const form = reactive({
  username: '',
  email: '',
  newPassword: '',
  confirmPassword: '',
})

const submitting = ref(false)

async function submit() {
  if (!form.username || !form.email || !form.newPassword || !form.confirmPassword) {
    toastStore.push('请完整填写信息', 'warn')
    return
  }
  if (form.newPassword !== form.confirmPassword) {
    toastStore.push('两次输入的密码不一致', 'danger')
    return
  }

  submitting.value = true
  try {
    await authStore.submitForgotPassword({
      username: form.username,
      email: form.email,
      new_password: form.newPassword,
    })
    toastStore.push('密码已重置，请重新登录', 'success')
    router.replace({
      name: 'login',
      query: { username: form.username },
    })
  } catch (error) {
    toastStore.push(error.message || '重置密码失败', 'danger')
  } finally {
    submitting.value = false
  }
}
</script>
