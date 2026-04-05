<template>
  <Teleport to="body">
    <Transition name="sheet-fade">
      <div
        v-if="modelValue"
        class="sheet-backdrop"
        @click.self="$emit('update:modelValue', false)"
      >
        <Transition :name="transitionName">
          <section
            v-if="modelValue"
            class="app-sheet"
            :data-size="size"
            :data-position="position"
          >
            <header class="app-sheet__header">
              <div>
                <p v-if="eyebrow" class="eyebrow">{{ eyebrow }}</p>
                <h3>{{ title }}</h3>
                <p v-if="subtitle" class="sheet-subtitle">{{ subtitle }}</p>
              </div>
              <button class="sheet-close" type="button" @click="$emit('update:modelValue', false)">
                ×
              </button>
            </header>
            <div class="app-sheet__body">
              <slot />
            </div>
          </section>
        </Transition>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false,
  },
  title: {
    type: String,
    default: '',
  },
  subtitle: {
    type: String,
    default: '',
  },
  eyebrow: {
    type: String,
    default: '',
  },
  size: {
    type: String,
    default: 'md',
  },
  position: {
    type: String,
    default: 'bottom',
  },
})

defineEmits(['update:modelValue'])

const transitionName = computed(() =>
  props.position === 'side' ? 'sheet-side' : 'sheet-up'
)
</script>
