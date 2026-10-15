import './style.css'
import { registerSW } from 'virtual:pwa-register'

// Chromium-only and missing from TypeScript's DOM lib.
interface BeforeInstallPromptEvent extends Event {
  prompt(): Promise<void>
}

document.querySelector<HTMLDivElement>('#app')!.innerHTML = `
<main>
  <h1>Hello from <code>/pilot</code></h1>
  <p>
    The first quiggleson.com sub-app. It lives in its own repo, is served by its own Cloudflare
    Worker, and installs as its own app.
  </p>

  <dl class="status">
    <dt>Network</dt>
    <dd id="network"></dd>
    <dt>Offline</dt>
    <dd id="offline" data-state="pending">Caching…</dd>
    <dt>Mode</dt>
    <dd id="mode"></dd>
    <dt>Version</dt>
    <dd><code>${__APP_VERSION__}</code></dd>
  </dl>

  <button id="install" type="button" hidden>Install app</button>
  <p id="ios-hint" class="hint" hidden>To install, tap Share, then <b>Add to Home Screen</b>.</p>

  <a class="home" href="/">← quiggleson.com</a>
</main>
`

const network = document.querySelector<HTMLElement>('#network')!
const offline = document.querySelector<HTMLElement>('#offline')!
const mode = document.querySelector<HTMLElement>('#mode')!
const install = document.querySelector<HTMLButtonElement>('#install')!
const iosHint = document.querySelector<HTMLElement>('#ios-hint')!

function renderNetwork() {
  network.textContent = navigator.onLine ? 'Online' : 'Offline'
  network.dataset.state = navigator.onLine ? 'ok' : 'warn'
}
renderNetwork()
window.addEventListener('online', renderNetwork)
window.addEventListener('offline', renderNetwork)

const standalone = matchMedia('(display-mode: standalone)').matches
mode.textContent = standalone ? 'Installed app' : 'Browser tab'

if ('serviceWorker' in navigator) {
  // `ready` resolves once a worker is active, and Workbox only activates after the precache has
  // finished, so this is the earliest point the app can honestly claim to work offline.
  navigator.serviceWorker.ready.then(() => {
    offline.textContent = 'Ready'
    offline.dataset.state = 'ok'
  })
  registerSW({ immediate: true })
} else {
  offline.textContent = 'Not supported'
  offline.dataset.state = 'warn'
}

let installPrompt: BeforeInstallPromptEvent | null = null

window.addEventListener('beforeinstallprompt', (event) => {
  event.preventDefault()
  installPrompt = event as BeforeInstallPromptEvent
  install.hidden = false
})

install.addEventListener('click', async () => {
  await installPrompt?.prompt()
  installPrompt = null
  install.hidden = true
})

window.addEventListener('appinstalled', () => {
  install.hidden = true
})

// iOS Safari never fires beforeinstallprompt; installing is a manual Share-sheet action.
iosHint.hidden = standalone || !/iphone|ipad|ipod/i.test(navigator.userAgent)
