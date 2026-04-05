<template>
  <RouterView />
  <AppToastStack />
</template>

<script setup>
import { RouterView } from 'vue-router'

import AppToastStack from '@/components/AppToastStack.vue'
</script>
