export const APP_TAB_RESELECT_EVENT = 'shiguang-app-tab-reselect'

export function emitTabReselect(tab) {
  window.dispatchEvent(
    new CustomEvent(APP_TAB_RESELECT_EVENT, {
      detail: { tab },
    })
  )
}
