<script setup>
import { computed, ref } from 'vue'
import { NAvatar, NButton, NForm, NFormItem, NInput, NTag } from 'naive-ui'

import CommonPage from '@/components/page/CommonPage.vue'
import { useUserStore } from '@/store'
import api from '@/api'

const userStore = useUserStore()

const activePanel = ref('profile')
const isProfileLoading = ref(false)
const isPasswordLoading = ref(false)

const infoFormRef = ref(null)
const passwordFormRef = ref(null)

const infoForm = ref({
  avatar: userStore.avatar,
  username: userStore.name,
  alias: userStore.alias || '',
  email: userStore.email || '',
  phone: userStore.phone || '',
})

const passwordForm = ref({
  old_password: '',
  new_password: '',
  confirm_password: '',
})

const roleNames = computed(() =>
  (userStore.role || []).map(item => item.name).filter(Boolean)
)

const profileStats = computed(() => [
  {
    label: '账号状态',
    value: userStore.isActive ? '正常' : '已停用',
  },
  {
    label: '角色数量',
    value: roleNames.value.length || 1,
  },
  {
    label: '登录账号',
    value: infoForm.value.username || '--',
  },
])

const infoFormRules = {
  email: [
    {
      required: true,
      message: '请输入邮箱地址',
      trigger: ['input', 'blur', 'change'],
    },
  ],
}

const passwordFormRules = {
  old_password: [
    {
      required: true,
      message: '请输入当前密码',
      trigger: ['input', 'blur', 'change'],
    },
  ],
  new_password: [
    {
      required: true,
      message: '请输入新密码',
      trigger: ['input', 'blur', 'change'],
    },
  ],
  confirm_password: [
    {
      required: true,
      message: '请再次输入新密码',
      trigger: ['input', 'blur'],
    },
    {
      validator: validatePasswordStartWith,
      message: '两次输入的密码不一致',
      trigger: 'input',
    },
    {
      validator: validatePasswordSame,
      message: '两次输入的密码不一致',
      trigger: ['blur', 'password-input'],
    },
  ],
}

function syncInfoForm(data = {}) {
  infoForm.value = {
    avatar: data.avatar ?? infoForm.value.avatar,
    username: data.username ?? infoForm.value.username,
    alias: data.alias ?? '',
    email: data.email ?? '',
    phone: data.phone ?? '',
  }
}

async function updateProfile() {
  infoFormRef.value?.validate(async (err) => {
    if (err) return

    isProfileLoading.value = true
    try {
      const res = await api.updateCurrentProfile({
        email: infoForm.value.email,
        alias: infoForm.value.alias,
        phone: infoForm.value.phone,
      })
      userStore.setUserInfo(res.data)
      syncInfoForm(res.data)
      $message.success('资料已更新')
    } finally {
      isProfileLoading.value = false
    }
  })
}

async function updatePassword() {
  passwordFormRef.value?.validate(async (err) => {
    if (err) return

    isPasswordLoading.value = true
    try {
      const res = await api.updatePassword({
        old_password: passwordForm.value.old_password,
        new_password: passwordForm.value.new_password,
      })
      $message.success(res.msg)
      passwordForm.value = {
        old_password: '',
        new_password: '',
        confirm_password: '',
      }
    } finally {
      isPasswordLoading.value = false
    }
  })
}

function validatePasswordStartWith(rule, value) {
  return (
    !!passwordForm.value.new_password &&
    passwordForm.value.new_password.startsWith(value) &&
    passwordForm.value.new_password.length >= value.length
  )
}

function validatePasswordSame(rule, value) {
  return value === passwordForm.value.new_password
}
</script>

<template>
  <CommonPage :show-header="false">
    <div class="profile-page">
      <section class="profile-hero">
        <div class="profile-hero__main">
          <NAvatar
            :size="88"
            round
            :src="infoForm.avatar"
            class="profile-hero__avatar"
          >
            {{ (userStore.displayName || userStore.name || 'U').slice(0, 1) }}
          </NAvatar>
          <div class="profile-hero__copy">
            <p class="profile-hero__eyebrow">个人中心</p>
            <h1>{{ userStore.displayName || userStore.name || '未命名用户' }}</h1>
            <p>{{ infoForm.email || '未设置邮箱' }}</p>
            <div class="profile-hero__tags">
              <NTag type="success" round>{{ userStore.isActive ? '账号正常' : '账号停用' }}</NTag>
              <NTag type="warning" round>{{ userStore.isSuperUser ? '管理员' : '普通用户' }}</NTag>
              <NTag v-for="role in roleNames" :key="role" round>{{ role }}</NTag>
            </div>
          </div>
        </div>
        <div class="profile-hero__stats">
          <div
            v-for="item in profileStats"
            :key="item.label"
            class="profile-stat"
          >
            <span>{{ item.label }}</span>
            <strong>{{ item.value }}</strong>
          </div>
        </div>
      </section>

      <div class="profile-layout">
        <aside class="profile-sidebar">
          <section class="profile-sidebar__section">
            <p class="profile-sidebar__label">基础信息</p>
            <div class="profile-sidebar__item">
              <span>登录账号</span>
              <strong>{{ infoForm.username || '--' }}</strong>
            </div>
            <div class="profile-sidebar__item">
              <span>显示名称</span>
              <strong>{{ userStore.displayName || '未设置' }}</strong>
            </div>
            <div class="profile-sidebar__item">
              <span>手机号码</span>
              <strong>{{ infoForm.phone || '未设置' }}</strong>
            </div>
          </section>

          <section class="profile-sidebar__section">
            <p class="profile-sidebar__label">快捷操作</p>
            <NButton
              quaternary
              type="primary"
              block
              @click="activePanel = 'profile'"
            >
              编辑资料
            </NButton>
            <NButton
              quaternary
              type="warning"
              block
              @click="activePanel = 'password'"
            >
              修改密码
            </NButton>
          </section>
        </aside>

        <section class="profile-panel">
          <div class="profile-panel__switcher">
            <button
              type="button"
              class="profile-switcher__button"
              :class="{ 'is-active': activePanel === 'profile' }"
              @click="activePanel = 'profile'"
            >
              资料维护
            </button>
            <button
              type="button"
              class="profile-switcher__button"
              :class="{ 'is-active': activePanel === 'password' }"
              @click="activePanel = 'password'"
            >
              密码安全
            </button>
          </div>

          <div v-if="activePanel === 'profile'" class="profile-form">
            <div class="profile-panel__header">
              <div>
                <h2>更新个人资料</h2>
                <p>只保留常用字段，减少干扰。</p>
              </div>
            </div>

            <NForm
              ref="infoFormRef"
              label-placement="top"
              :model="infoForm"
              :rules="infoFormRules"
            >
              <div class="profile-form__grid">
                <NFormItem label="登录账号">
                  <NInput :value="infoForm.username" disabled />
                </NFormItem>
                <NFormItem label="显示名称" path="alias">
                  <NInput
                    v-model:value="infoForm.alias"
                    placeholder="请输入显示名称"
                  />
                </NFormItem>
                <NFormItem label="邮箱" path="email">
                  <NInput
                    v-model:value="infoForm.email"
                    placeholder="请输入邮箱地址"
                  />
                </NFormItem>
                <NFormItem label="手机号" path="phone">
                  <NInput
                    v-model:value="infoForm.phone"
                    placeholder="请输入手机号"
                  />
                </NFormItem>
              </div>
              <NButton type="primary" size="large" :loading="isProfileLoading" @click="updateProfile">
                保存资料
              </NButton>
            </NForm>
          </div>

          <div v-else class="profile-form">
            <div class="profile-panel__header">
              <div>
                <h2>修改登录密码</h2>
                <p>建议使用长度更长的新密码。</p>
              </div>
            </div>

            <NForm
              ref="passwordFormRef"
              label-placement="top"
              :model="passwordForm"
              :rules="passwordFormRules"
            >
              <div class="profile-form__grid profile-form__grid--single">
                <NFormItem label="当前密码" path="old_password">
                  <NInput
                    v-model:value="passwordForm.old_password"
                    type="password"
                    show-password-on="mousedown"
                    placeholder="请输入当前密码"
                  />
                </NFormItem>
                <NFormItem label="新密码" path="new_password">
                  <NInput
                    v-model:value="passwordForm.new_password"
                    :disabled="!passwordForm.old_password"
                    type="password"
                    show-password-on="mousedown"
                    placeholder="请输入新密码"
                  />
                </NFormItem>
                <NFormItem label="确认新密码" path="confirm_password">
                  <NInput
                    v-model:value="passwordForm.confirm_password"
                    :disabled="!passwordForm.new_password"
                    type="password"
                    show-password-on="mousedown"
                    placeholder="请再次输入新密码"
                  />
                </NFormItem>
              </div>
              <NButton type="primary" size="large" :loading="isPasswordLoading" @click="updatePassword">
                更新密码
              </NButton>
            </NForm>
          </div>
        </section>
      </div>
    </div>
  </CommonPage>
</template>

<style scoped>
.profile-page {
  display: grid;
  gap: 24px;
}

.profile-hero {
  display: grid;
  gap: 24px;
  padding: 28px;
  border-radius: 28px;
  background:
    radial-gradient(circle at top right, rgba(244, 186, 103, 0.26), transparent 34%),
    linear-gradient(135deg, #1f5f6d 0%, #3f7d71 52%, #d99743 100%);
  color: #fff;
}

.profile-hero__main {
  display: flex;
  align-items: center;
  gap: 20px;
}

.profile-hero__avatar {
  border: 3px solid rgba(255, 255, 255, 0.22);
  background: rgba(255, 255, 255, 0.16);
}

.profile-hero__copy {
  min-width: 0;
}

.profile-hero__eyebrow {
  margin: 0 0 6px;
  font-size: 13px;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  opacity: 0.76;
}

.profile-hero__copy h1 {
  margin: 0;
  font-size: 34px;
  line-height: 1.08;
  font-weight: 700;
}

.profile-hero__copy p {
  margin: 10px 0 0;
  font-size: 15px;
  opacity: 0.88;
}

.profile-hero__tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 14px;
}

.profile-hero__stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 14px;
}

.profile-stat {
  padding: 16px 18px;
  border-radius: 20px;
  background: rgba(8, 18, 24, 0.16);
  backdrop-filter: blur(8px);
}

.profile-stat span {
  display: block;
  font-size: 13px;
  opacity: 0.76;
}

.profile-stat strong {
  display: block;
  margin-top: 6px;
  font-size: 20px;
  font-weight: 700;
}

.profile-layout {
  display: grid;
  grid-template-columns: 280px minmax(0, 1fr);
  gap: 24px;
}

.profile-sidebar,
.profile-panel {
  border-radius: 24px;
  background: #fff;
  border: 1px solid rgba(28, 45, 56, 0.08);
}

.profile-sidebar {
  padding: 22px;
  display: grid;
  gap: 18px;
  align-content: start;
}

.profile-sidebar__section {
  display: grid;
  gap: 12px;
}

.profile-sidebar__label {
  margin: 0;
  font-size: 12px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: #6a7b84;
}

.profile-sidebar__item {
  display: grid;
  gap: 4px;
  padding-bottom: 12px;
  border-bottom: 1px solid rgba(28, 45, 56, 0.08);
}

.profile-sidebar__item:last-child {
  border-bottom: none;
  padding-bottom: 0;
}

.profile-sidebar__item span {
  font-size: 13px;
  color: #70808a;
}

.profile-sidebar__item strong {
  font-size: 16px;
  color: #16242b;
}

.profile-panel {
  padding: 22px;
}

.profile-panel__switcher {
  display: inline-grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
  padding: 6px;
  border-radius: 16px;
  background: #f2f5f6;
}

.profile-switcher__button {
  min-width: 132px;
  border: none;
  border-radius: 12px;
  background: transparent;
  padding: 11px 16px;
  font-size: 14px;
  font-weight: 600;
  color: #5a6b74;
  cursor: pointer;
  transition: all 0.22s ease;
}

.profile-switcher__button.is-active {
  background: #fff;
  color: #1f5f6d;
  box-shadow: 0 8px 22px rgba(31, 95, 109, 0.12);
}

.profile-form {
  margin-top: 22px;
}

.profile-panel__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 18px;
}

.profile-panel__header h2 {
  margin: 0;
  font-size: 24px;
  color: #15232a;
}

.profile-panel__header p {
  margin: 8px 0 0;
  font-size: 14px;
  color: #6d7d87;
}

.profile-form__grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px 18px;
  margin-bottom: 18px;
}

.profile-form__grid--single {
  grid-template-columns: 1fr;
  max-width: 560px;
}

@media (max-width: 960px) {
  .profile-layout {
    grid-template-columns: 1fr;
  }

  .profile-sidebar {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 720px) {
  .profile-hero__main {
    align-items: flex-start;
    flex-direction: column;
  }

  .profile-hero__stats,
  .profile-form__grid,
  .profile-sidebar {
    grid-template-columns: 1fr;
  }

  .profile-switcher__button {
    min-width: 0;
  }
}
</style>
