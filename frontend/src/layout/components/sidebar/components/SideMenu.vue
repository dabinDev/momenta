<template>
  <n-menu
    ref="menu"
    class="side-menu"
    accordion
    :indent="18"
    :collapsed-icon-size="20"
    :collapsed-width="76"
    :options="menuOptions"
    :value="activeKey"
    :expanded-keys="expandedKeys"
    :render-label="renderMenuLabel"
    @update:value="handleMenuSelect"
    @update:expanded-keys="handleExpandedKeysUpdate"
  />
</template>

<script setup>
import { h } from 'vue'

import { usePermissionStore, useAppStore } from '@/store'
import { renderCustomIcon, renderIcon, isExternal } from '@/utils'

const router = useRouter()
const curRoute = useRoute()
const permissionStore = usePermissionStore()
const appStore = useAppStore()

const activeKey = computed(() => curRoute.meta?.activeMenu || curRoute.path)

const menuOptions = computed(() => {
  return permissionStore.menus.map(item => getMenuItem(item)).sort((a, b) => a.order - b.order)
})

const expandedKeys = ref([])
const menu = ref(null)

watch(
  () => [curRoute.path, menuOptions.value],
  async () => {
    expandedKeys.value = findExpandedKeys(menuOptions.value, activeKey.value)
    await nextTick()
    menu.value?.showOption()
  },
  { deep: true, immediate: true },
)

function resolvePath(basePath, path) {
  if (isExternal(path)) return path
  return (
    '/' +
    [basePath, path]
      .filter(value => !!value && value !== '/')
      .map(value => value.replace(/(^\/)|(\/$)/g, ''))
      .join('/')
  )
}

function getMenuItem(route, basePath = '') {
  const currentPath = resolvePath(basePath, route.path)
  const menuItem = {
    label: (route.meta && route.meta.title) || route.name,
    key: currentPath,
    path: currentPath,
    icon: getIcon(route.meta),
    order: route.meta?.order || 0,
  }

  const visibleChildren = route.children ? route.children.filter(item => item.name && !item.isHidden) : []
  if (!visibleChildren.length) {
    return menuItem
  }

  menuItem.children = visibleChildren
    .map(item => getMenuItem(item, currentPath))
    .sort((a, b) => a.order - b.order)
  menuItem.path = route.redirect || menuItem.children[0]?.path || currentPath

  return menuItem
}

function getIcon(meta) {
  if (meta?.customIcon) return renderCustomIcon(meta.customIcon, { size: 18 })
  if (meta?.icon) return renderIcon(meta.icon, { size: 18 })
  return null
}

function findExpandedKeys(options, targetPath, parents = []) {
  for (const option of options) {
    const nextParents = option.children?.length ? [...parents, option.key] : parents
    if (option.key === targetPath) {
      return parents
    }
    if (option.children?.length) {
      const matched = findExpandedKeys(option.children, targetPath, nextParents)
      if (matched.length) {
        return matched
      }
    }
  }
  return []
}

function navigateTo(path) {
  if (!path) {
    return
  }
  if (isExternal(path)) {
    window.open(path)
    return
  }
  if (path === curRoute.path) {
    appStore.reloadPage()
    return
  }
  router.push(path)
}

function renderMenuLabel(option) {
  if (!option?.children?.length || !option.path || isExternal(option.path)) {
    return option.label
  }

  return h(
    'span',
    {
      class: 'side-menu__label',
      onClick: () => navigateTo(option.path),
    },
    option.label,
  )
}

function handleMenuSelect(_, item) {
  navigateTo(item.path)
}

function handleExpandedKeysUpdate(keys) {
  expandedKeys.value = keys
}
</script>

<style lang="scss">
.side-menu {
  padding: 4px 12px 20px;

  .n-menu-item-content,
  .n-submenu-children .n-menu-item-content {
    margin: 4px 0;
    border-radius: 14px;
    transition: transform 0.2s ease, color 0.2s ease, box-shadow 0.2s ease;

    &::before {
      left: 6px;
      right: 6px;
      border-radius: 12px;
      background: transparent;
    }

    &:hover::before {
      background: linear-gradient(90deg, rgba(255, 105, 0, 0.08), rgba(255, 198, 112, 0.08));
    }

    &:hover {
      transform: translateX(2px);
    }
  }

  .n-menu-item-content--selected::before,
  .n-menu-item-content--child-active::before {
    background: var(--menu-active-bg);
    box-shadow: inset 2px 0 0 var(--brand-primary);
  }

  .n-menu-item-content-header,
  .side-menu__label {
    font-size: 14px;
    font-weight: 700;
    color: var(--app-text);
  }

  .side-menu__label {
    display: inline-flex;
    width: 100%;
    cursor: pointer;
  }

  .n-menu-item-content__icon,
  .n-submenu .n-menu-item-content__icon {
    color: var(--app-muted);
  }

  .n-menu-item-content--selected,
  .n-menu-item-content--child-active {
    .n-menu-item-content-header,
    .side-menu__label,
    .n-menu-item-content__icon {
      color: var(--brand-primary);
    }
  }

  .n-menu-item-content-arrow {
    color: var(--app-muted);
  }
}
</style>
