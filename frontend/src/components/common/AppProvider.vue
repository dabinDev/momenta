<template>
  <n-config-provider
    wh-full
    :locale="zhCN"
    :date-locale="dateZhCN"
    :theme="appStore.isDark ? darkTheme : undefined"
    :theme-overrides="themeOverrides"
  >
    <n-loading-bar-provider>
      <n-dialog-provider>
        <n-notification-provider>
          <n-message-provider>
            <slot></slot>
            <NaiveProviderContent />
          </n-message-provider>
        </n-notification-provider>
      </n-dialog-provider>
    </n-loading-bar-provider>
  </n-config-provider>
</template>

<script setup>
import { computed, defineComponent, h, watchEffect } from 'vue'
import {
  zhCN,
  dateZhCN,
  darkTheme,
  useLoadingBar,
  useDialog,
  useMessage,
  useNotification,
} from 'naive-ui'
import { kebabCase } from 'lodash-es'
import { setupMessage, setupDialog } from '@/utils'
import { darkThemeOverrides, lightThemeOverrides } from '~/settings'
import { useAppStore } from '@/store'

const appStore = useAppStore()

const themeOverrides = computed(() => (appStore.isDark ? darkThemeOverrides : lightThemeOverrides))

function setupCssVar() {
  const common = themeOverrides.value.common || {}
  for (const key in common) {
    document.documentElement.style.setProperty(`--${kebabCase(key)}`, common[key] || '')
    if (key === 'primaryColor') {
      window.localStorage.setItem('__THEME_COLOR__', common[key] || '')
    }
  }

  const mode = appStore.isDark ? 'dark' : 'light'
  document.documentElement.dataset.theme = mode
  document.body.dataset.theme = mode
  document.documentElement.classList.toggle('dark', appStore.isDark)
  document.body.classList.toggle('dark', appStore.isDark)
}

function setupNaiveTools() {
  window.$loadingBar = useLoadingBar()
  window.$notification = useNotification()
  window.$message = setupMessage(useMessage())
  window.$dialog = setupDialog(useDialog())
}

const NaiveProviderContent = defineComponent({
  setup() {
    watchEffect(() => {
      setupCssVar()
    })
    setupNaiveTools()
  },
  render() {
    return h('div')
  },
})
</script>
