<template>
  <section class="auth-hero">
    <BrandMark :size="84" :radius="24" />
    <div class="auth-hero__copy">
      <p class="eyebrow">拾光视频</p>
      <h1>更适合长辈使用的 AI 视频创作工具</h1>
      <p>
        保持和 App 一致的暖色层次、轻玻璃结构与三段式主导航，把登录、创作、记录、设置统一到同一套后端服务。
      </p>
    </div>
    <div class="auth-hero__pills">
      <span>语音输入</span>
      <span>一键生成</span>
      <span>邀请注册</span>
    </div>
  </section>
</template>

<script setup>
import BrandMark from '@/components/BrandMark.vue'
</script>
