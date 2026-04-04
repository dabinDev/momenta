function addThemeColorCssVars() {
  const key = '__THEME_COLOR__'
  const defaultColor = '#F4511E'
  const themeColor = window.localStorage.getItem(key) || defaultColor
  const cssVars = `--primary-color: ${themeColor}`
  document.documentElement.style.cssText = cssVars
}

function initLoadingLogo(id) {
  const appEl = document.querySelector(id)
  if (!appEl) {
    return
  }
  const basePath = window.__APP_BASE__ || '/'
  const normalizedBase = basePath.endsWith('/') ? basePath : `${basePath}/`
  const img = document.createElement('img')
  img.src = `${normalizedBase}shiguang-icon.png`
  img.alt = '拾光视频'
  img.className = 'loading-logo__image'
  appEl.appendChild(img)
}

addThemeColorCssVars()
initLoadingLogo('#loadingLogo')
