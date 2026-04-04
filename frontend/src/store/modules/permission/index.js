import { defineStore } from 'pinia'
import { basicRoutes, vueModules } from '@/router/routes'
import Layout from '@/layout/index.vue'
import api from '@/api'

function normalizePath(path = '') {
  const value = String(path || '').trim()
  if (!value) {
    return '/'
  }
  return value.startsWith('/') ? value : `/${value}`
}

function joinRoutePath(basePath = '/', childPath = '') {
  const base = normalizePath(basePath)
  const child = String(childPath || '').trim()
  if (!child) {
    return base
  }
  if (child.startsWith('/')) {
    return child
  }
  return `${base.replace(/\/+$/, '')}/${child.replace(/^\/+/, '')}`
}

function buildRouteName(fullPath = '/') {
  const normalized = normalizePath(fullPath)
  const slug = normalized
    .replace(/^\/+/, '')
    .replace(/[^\w]+/g, '_')
    .replace(/^_+|_+$/g, '')
  return `route_${slug || 'root'}`
}

function buildRoutes(routes = []) {
  return routes.map((item) => {
    const parentPath = normalizePath(item.path)
    const route = {
      name: buildRouteName(parentPath),
      path: parentPath,
      component: shallowRef(Layout),
      isHidden: item.is_hidden,
      redirect: item.redirect || undefined,
      meta: {
        title: item.name,
        icon: item.icon,
        order: item.order,
        keepAlive: item.keepalive,
      },
      children: [],
    }

    if (item.children && item.children.length > 0) {
      route.children = item.children.map((child) => {
        const fullPath = joinRoutePath(parentPath, child.path)
        return {
          name: buildRouteName(fullPath),
          path: child.path,
          component: vueModules[`/src/views${child.component}/index.vue`],
          isHidden: child.is_hidden,
          meta: {
            title: child.name,
            icon: child.icon,
            order: child.order,
            keepAlive: child.keepalive,
            activeMenu: fullPath,
          },
        }
      })
    } else {
      route.children.push({
        name: buildRouteName(`${parentPath}/index`),
        path: '',
        component: vueModules[`/src/views${item.component}/index.vue`],
        isHidden: true,
        meta: {
          title: item.name,
          icon: item.icon,
          order: item.order,
          keepAlive: item.keepalive,
          activeMenu: parentPath,
        },
      })
    }

    return route
  })
}

export const usePermissionStore = defineStore('permission', {
  state() {
    return {
      accessRoutes: [],
      accessApis: [],
    }
  },
  getters: {
    routes() {
      return basicRoutes.concat(this.accessRoutes)
    },
    menus() {
      return this.routes.filter((route) => route.path && route.name && !route.isHidden)
    },
    apis() {
      return this.accessApis
    },
  },
  actions: {
    async generateRoutes() {
      const res = await api.getUserMenu()
      this.accessRoutes = buildRoutes(res.data || [])
      return this.accessRoutes
    },
    async getAccessApis() {
      const res = await api.getUserApi()
      this.accessApis = res.data
      return this.accessApis
    },
    resetPermission() {
      this.$reset()
    },
  },
})
