# CLAUDE.md — pilot

## What this is

A hello-world PWA whose only job is to prove the quiggleson.com sub-app architecture end to end:
subpath routing, installability, offline, and updates. It is the reference implementation later
sub-apps copy, so keep it small and keep it correct.

- **Live at:** https://www.quiggleson.com/pilot
- **Repo:** https://github.com/Quiggleson/pilot
- **Parent site:** the [portfolio repo](https://github.com/Quiggleson/portfolio) owns `quiggleson.com`
  and links to this app from its home page. Its `CLAUDE.md` holds the shared architecture.

## Agent workflow — read this first

This repo is edited by coding agents driven from Slack. The human is the gate.

- **Never push to `main`.** Work on a branch, commit, open a PR. `main` is protected with
  `enforce_admins`, so a push is rejected even with the owner's token.
- **Never deploy.** `npm run deploy`, `wrangler deploy`, and anything that publishes are the
  human's to run. An agent's job ends at the PR.
- **Never add `Co-Authored-By` lines** to commit messages.
- **Never remove checklist items** from a PR template; leave unchecked boxes in place.
- Branch names: `slack/<short-slug>` for Slack-driven work, `fix/<slug>` or `feat/<slug>` otherwise.
- PR body: lead with the verbatim Slack instruction that prompted the change, then what you did
  and anything you deliberately left out. The human reviews from Slack and may only read this body.
- If the instruction is ambiguous, implement the most conservative reading and say so in the PR
  body. Do not expand scope beyond the message.

## Mounting at a subpath

The app is served from `/pilot/`, not from a domain root. This is the single biggest source of
bugs in these repos.

`quiggleson.com` is a Cloudflare **Custom Domain** bound to the portfolio Worker, which makes that
Worker the origin for every path. This app attaches as **path routes**, which run before a Custom
Domain Worker, so it answers its own subpath before the portfolio Worker sees the request. The
four routes are in [wrangler.jsonc](wrangler.jsonc):

```
quiggleson.com/pilot        quiggleson.com/pilot/*
www.quiggleson.com/pilot    www.quiggleson.com/pilot/*
```

Two things that bite:

- **Both hostnames.** The apex and `www` are separate Custom Domains on the portfolio Worker.
  Register routes for both or `www` visitors land on the portfolio instead of this app.
- **Bare path and wildcard.** `/pilot/*` does not match `/pilot` with no trailing slash. Register
  both patterns. The bare one is what lets the Worker redirect `/pilot` → `/pilot/`.

Never widen a pattern. `quiggleson.com/*` would take over the whole site.

Consequences for the code:

- Every internal link, asset path, fetch URL, manifest field, and service worker path must carry
  the `/pilot` prefix. Root-absolute paths like `/icon.png` resolve to the portfolio, not here.
  The one deliberate exception is the `← quiggleson.com` link, which points at `/`.
- Vite needs **both** `base: '/pilot/'` and `build.outDir: 'dist/pilot'`. Workers Static Assets
  looks files up by the full request path and never strips the route prefix, so with plain
  `dist/` output every request 404s even though the build "works".
- In `index.html`, write root-absolute paths (`/favicon.svg`); Vite prefixes them with `base`.
  URLs built in TypeScript are not rewritten, so use relative paths or `import.meta.env.BASE_URL`.

## PWA requirements

Each app is an independently installable PWA. Its service worker must be scoped to the subpath so
the apps cannot interfere with each other or with the portfolio.

`vite-plugin-pwa` generates both the manifest and the service worker from
[vite.config.ts](vite.config.ts). Edit them there, never in `dist/`.

- **Manifest** at `/pilot/manifest.webmanifest`, injected into the document head at build time:
  - `"scope": "/pilot/"`, `"start_url": "/pilot/"`, `"id": "/pilot/"`
  - `"display": "standalone"`
  - `"name"`, `"short_name"`, `"theme_color"`, `"background_color"`
  - icons at 192x192 and 512x512, plus a 512x512 `"purpose": "maskable"`
- **Service worker** served from `/pilot/sw.js`. A worker's default scope is the directory it is
  served from, so serving it at the subpath confines it there. Never serve it from the domain
  root — it would hijack the whole site.
- Registered with an explicit `scope: '/pilot/'` (the plugin's `scope` option) via
  `registerSW()` in [src/main.ts](src/main.ts).
- The app shell is precached by Workbox, so the installed app opens offline.
- Workbox revisions each precached file by content hash, so changed assets reach installed clients
  on the next launch without a manual cache-name bump. `registerType: 'autoUpdate'` activates the
  new worker immediately.

## Commands

Node 24 (`nvm use`). Wrangler requires Node 22+ and fails outright on 20.

```
npm run dev        # vite dev server at http://localhost:5173/pilot/ (no service worker)
npm run build      # typecheck + production build into dist/pilot/
npm run typecheck  # tsc only
npm run preview    # build, then serve dist/ through a local Worker at http://localhost:8787/pilot/
npm run smoke      # route/manifest/SW checks; defaults to production, or pass an origin:
                   #   npm run smoke -- http://localhost:8787
npm run deploy     # HUMAN ONLY — publishes to quiggleson.com/pilot
```

There is no test suite. `npm run preview` + `npm run smoke -- http://localhost:8787` is the check
for any change that touches routing, paths, or the PWA config.

## Stack

- **Vite 8 + TypeScript 6, no UI framework.** The app is one screen; a framework would be the
  biggest thing in it.
- **vite-plugin-pwa** (Workbox `generateSW`). Vite emits hashed filenames, which a hand-written
  service worker cannot know to precache.
- **Cloudflare Worker, assets only** (no `main` script). Nothing here needs a server.

## Layout

```
index.html           document shell; head links are rewritten with the /pilot/ base
src/main.ts          the whole UI: status panel, install button, SW registration
src/style.css        styles; colors are CSS custom properties on :root, light + dark
src/env.d.ts         ambient types: __APP_VERSION__, virtual:pwa-register
public/              copied verbatim into dist/pilot/: favicon, apple-touch-icon, icons/
scripts/smoke.sh     HTTP checks against production or a local origin
scripts/make-icons.sh  regenerates the PNG icons (needs ImageMagick `convert`)
vite.config.ts       base, outDir, build version, manifest + service worker config
wrangler.jsonc       Worker name, assets directory, the four routes
```

## Conventions

- Match the create-vite idiom already here: no semicolons, single quotes, two-space indent.
- Colors live as custom properties in [src/style.css](src/style.css). The accent is the
  portfolio's `purple-com` (`#7D26CD`), so the app reads as part of the same site.
- `__APP_VERSION__` (short commit SHA + build time) is shown on screen. That is how a human
  confirms which build an installed client is running, so keep it visible.
- Match the surrounding code's idiom, naming, and comment density.
- Comments explain *why*, never restate *what*. Self-explanatory code gets no comment.

## Known gotchas

- **Node 20 breaks wrangler.** `.nvmrc` says 24; run `nvm use` before any npm script.
- **npm 11 warns that esbuild and workerd have unapproved install scripts.** Harmless: their
  platform binaries arrive as optional dependencies, and a fresh `npm ci` builds and serves fine
  without approving anything.
- **Cached 308 loop.** Before this app existed, the portfolio answered `/pilot/` with a permanent
  308 → `/pilot`. A browser that cached it loops against this app's `/pilot` → `/pilot/`
  redirect. Clear site data or use a private window.
- **`npm run dev` has no service worker** (vite-plugin-pwa only builds it for production). Use
  `npm run preview` to test anything offline or install related.
- The version SHA is the last commit, so an uncommitted local build shows the previous SHA.

## New repo checklist (human)

- [x] Repo created under `Quiggleson/`, PR-only: protect `main`, require a PR before merge, include admins.
- [x] `wrangler.jsonc` routes for all four patterns above.
- [ ] Cloudflare API token in repo secrets if deploys are automated on merge. (Not automated; deploys are manual.)
- [x] Manifest and service worker scoped to `/pilot/`.
- [ ] Verified installable from `https://www.quiggleson.com/pilot` on a phone.
- [ ] Linked from the portfolio home page preview list.
- [x] This file filled in, placeholders gone.
