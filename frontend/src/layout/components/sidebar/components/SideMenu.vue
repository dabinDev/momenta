<template>
  <n-menu
    ref="menu"
    class="side-menu"
    accordion
    :indent="18"
    :collapsed-icon-size="20"
    :collapsed-width="74"
    :options="menuOptions"
    :value="activeKey"
    @update:value="handleMenuSelect"
  />
</template>

<script setup>
import { usePermissionStore, useAppStore } from '@/store'
import { renderCustomIcon, renderIcon, isExternal } from '@/utils'

const router = useRouter()
const curRoute = useRoute()
const permissionStore = usePermissionStore()
const appStore = useAppStore()

const activeKey = computed(() => curRoute.meta?.activeMenu || curRoute.name)

const menuOptions = computed(() => {
  return permissionStore.menus.map((item) => getMenuItem(item)).sort((a, b) => a.order - b.order)
})

const menu = ref(null)
watch(curRoute, async () => {
  await nextTick()
  menu.value?.showOption()
})

function resolvePath(basePath, path) {
  if (isExternal(path)) return path
  return (
    '/' +
    [basePath, path]
      .filter((path) => !!path && path !== '/')
      .map((path) => path.replace(/(^\/)|(\/$)/g, ''))
      .join('/')
  )
}

function getMenuItem(route, basePath = '') {
  let menuItem = {
    label: (route.meta && route.meta.title) || route.name,
    key: route.name,
    path: resolvePath(basePath, route.path),
    icon: getIcon(route.meta),
    order: route.meta?.order || 0,
  }

  const visibleChildren = route.children
    ? route.children.filter((item) => item.name && !item.isHidden)
    : []

  if (!visibleChildren.length) return menuItem

  if (visibleChildren.length === 1) {
    const singleRoute = visibleChildren[0]
    menuItem = {
      ...menuItem,
      label: singleRoute.meta?.title || singleRoute.name,
      key: singleRoute.name,
      path: resolvePath(menuItem.path, singleRoute.path),
      icon: getIcon(singleRoute.meta),
    }
    const visibleItems = singleRoute.children
      ? singleRoute.children.filter((item) => item.name && !item.isHidden)
      : []

    if (visibleItems.length === 1) {
      menuItem = getMenuItem(visibleItems[0], menuItem.path)
    } else if (visibleItems.length > 1) {
      menuItem.children = visibleItems
        .map((item) => getMenuItem(item, menuItem.path))
        .sort((a, b) => a.order - b.order)
    }
  } else {
    menuItem.children = visibleChildren
      .map((item) => getMenuItem(item, menuItem.path))
      .sort((a, b) => a.order - b.order)
  }
  return menuItem
}

function getIcon(meta) {
  if (meta?.customIcon) return renderCustomIcon(meta.customIcon, { size: 18 })
  if (meta?.icon) return renderIcon(meta.icon, { size: 18 })
  return null
}

function handleMenuSelect(key, item) {
  if (isExternal(item.path)) {
    window.open(item.path)
  } else if (item.path === curRoute.path) {
    appStore.reloadPage()
  } else {
    router.push(item.path)
  }
}
</script>

<style lang="scss">
.side-menu {
  padding: 6px 10px 16px;

  .n-menu-item-content,
  .n-submenu-children .n-menu-item-content {
    margin: 4px 0;
    border-radius: 16px;
    transition: transform 0.2s ease, color 0.2s ease;

    &::before {
      left: 6px;
      right: 6px;
      border-radius: 14px;
      background: transparent;
    }

    &:hover {
      transform: translateX(2px);
    }

    &:hover::before {
      background: var(--menu-hover-bg);
    }
  }

  .n-menu-item-content--selected::before,
  .n-menu-item-content--child-active::before {
    background: var(--menu-active-bg);
    box-shadow: inset 3px 0 0 var(--primary-color);
  }

  .n-menu-item-content-header {
    font-size: 14px;
    font-weight: 700;
    color: var(--app-text);
  }

  .n-menu-item-content__icon,
  .n-submenu .n-menu-item-content__icon {
    color: var(--app-muted);
  }

  .n-menu-item-content--selected {
    .n-menu-item-content-header,
    .n-menu-item-content__icon {
      color: var(--primary-color);
    }
  }

  .n-menu-item-content-arrow {
    color: var(--app-muted);
  }
}
</style>
