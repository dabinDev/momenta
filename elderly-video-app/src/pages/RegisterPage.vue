<template>
  <main class="auth-page auth-page--register">
    <div class="auth-page__layout">
      <AuthHero />
      <section class="auth-form-card">
        <p class="eyebrow">受邀注册</p>
        <h2>注册账号</h2>
        <p class="auth-form-card__copy">只保留必要字段。邀请码必填，注册成功后会自动带回登录页。</p>

        <form class="form-stack" @submit.prevent="submit">
          <label class="field">
            <span>用户名</span>
            <input
              v-model.trim="form.username"
              type="text"
              maxlength="20"
              placeholder="请输入用户名"
            />
            <small>用户名最多 20 个字符。</small>
          </label>
          <label class="field">
            <span>邮箱</span>
            <input v-model.trim="form.email" type="email" placeholder="请输入邮箱" />
          </label>
          <label class="field field--accent">
            <span>邀请码</span>
            <input v-model.trim="form.inviteCode" type="text" placeholder="请输入邀请码" />
            <small>邀请码由后台统一生成，没有邀请码无法注册。</small>
          </label>
          <label class="field">
            <span>密码</span>
            <input v-model.trim="form.password" type="password" placeholder="请输入密码" />
          </label>
          <label class="field">
            <span>确认密码</span>
            <input v-model.trim="form.confirmPassword" type="password" placeholder="请再次输入密码" />
          </label>
          <button class="primary-btn" type="submit" :disabled="submitting">
            {{ submitting ? '注册中...' : '注册账号' }}
          </button>
        </form>

        <div class="auth-form-card__links auth-form-card__links--single">
          <button type="button" class="text-link" @click="router.push({ name: 'login', query: { username: form.username } })">
            返回登录
          </button>
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

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const toastStore = useToastStore()
const USERNAME_MAX_LENGTH = 20

const form = reactive({
  username: '',
  email: '',
  inviteCode: String(route.query.inviteCode || ''),
  password: '',
  confirmPassword: '',
})

const submitting = ref(false)

async function submit() {
  if (!form.username || !form.email || !form.inviteCode || !form.password || !form.confirmPassword) {
    toastStore.push('请把注册信息填写完整', 'warn')
    return
  }
  if (form.username.length > USERNAME_MAX_LENGTH) {
    toastStore.push(`用户名最多 ${USERNAME_MAX_LENGTH} 个字符`, 'warn')
    return
  }
  if (form.password !== form.confirmPassword) {
    toastStore.push('两次输入的密码不一致', 'danger')
    return
  }

  submitting.value = true
  try {
    await authStore.register({
      username: form.username,
      email: form.email,
      password: form.password,
      invite_code: form.inviteCode,
    })
    toastStore.push('注册成功，请使用新账号登录', 'success')
    router.replace({
      name: 'login',
      query: { username: form.username },
    })
  } catch (error) {
    toastStore.push(error.message || '注册失败', 'danger')
  } finally {
    submitting.value = false
  }
}
</script>
