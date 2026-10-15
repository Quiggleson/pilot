# pilot

The first quiggleson.com sub-app: a hello-world PWA served at
**https://www.quiggleson.com/pilot**, from its own repo and its own Cloudflare Worker.

It exists to prove the sub-app setup end to end (subpath routing, install, offline, updates) and
to be the template later sub-apps copy. [CLAUDE.md](CLAUDE.md) has the details.

```sh
nvm use            # Node 24; wrangler needs 22+
npm install
npm run preview    # build + local Worker at http://localhost:8787/pilot/
```

Deploying (`npm run deploy`) is done by hand, from `main`, after a PR merges.
