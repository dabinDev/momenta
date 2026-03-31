<template>
  <n-menu
    ref="menu"
    class="side-menu"
    accordion
    :indent="18"
    :collapsed-icon-size="22"
    :collapsed-width="72"
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
  return permissionStore.menus.map(item => getMenuItem(item)).sort((a, b) => a.order - b.order)
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
      .filter(path => !!path && path !== '/')
      .map(path => path.replace(/(^\/)|(\/$)/g, ''))
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
    ? route.children.filter(item => item.name && !item.isHidden)
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
      ? singleRoute.children.filter(item => item.name && !item.isHidden)
      : []

    if (visibleItems.length === 1) {
      menuItem = getMenuItem(visibleItems[0], menuItem.path)
    } else if (visibleItems.length > 1) {
      menuItem.children = visibleItems
        .map(item => getMenuItem(item, menuItem.path))
        .sort((a, b) => a.order - b.order)
    }
  } else {
    menuItem.children = visibleChildren
      .map(item => getMenuItem(item, menuItem.path))
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
  padding: 8px 10px 18px;

  .n-menu-item-content,
  .n-submenu-children .n-menu-item-content {
    margin: 3px 0;
    border-radius: 14px;
    transition: background-color 0.2s ease, transform 0.2s ease;

    &::before {
      left: 4px;
      right: 4px;
      border-radius: 12px;
    }

    &:hover::before {
      background: rgba(220, 235, 225, 0.55);
    }
  }

  .n-menu-item-content--selected::before,
  .n-menu-item-content--child-active::before {
    background: linear-gradient(135deg, rgba(235, 245, 239, 0.95), rgba(255, 247, 232, 0.95));
    box-shadow: inset 3px 0 0 var(--primary-color);
  }

  .n-menu-item-content-header {
    font-weight: 600;
  }
}
</style>
