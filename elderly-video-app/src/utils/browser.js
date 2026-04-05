export function isWeChatBrowser() {
  return /micromessenger/i.test(window.navigator.userAgent)
}

export function resolveApkDownloadUrl(latestRelease) {
  return String(
    latestRelease?.download_url ||
      latestRelease?.downloadUrl ||
      import.meta.env.VITE_APK_DOWNLOAD_URL ||
      ''
  ).trim()
}
