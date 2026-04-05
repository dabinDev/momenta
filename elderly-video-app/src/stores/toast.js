import { ref } from 'vue'
import { defineStore } from 'pinia'

let toastSeed = 0

export const useToastStore = defineStore('toast', () => {
  const items = ref([])

  function push(message, tone = 'default', timeout = 2600) {
    const id = `${Date.now()}-${toastSeed += 1}`
    items.value.push({ id, message, tone })
    window.setTimeout(() => remove(id), timeout)
  }

  function remove(id) {
    items.value = items.value.filter((item) => item.id !== id)
  }

  return {
    items,
    push,
    remove,
  }
})
