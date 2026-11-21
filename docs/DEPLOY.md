# Deployment

A real watch only talks to public `https://` addresses, so the proxy has to be hosted.
The reference setup is Vercel: free Hobby plan, HTTPS out of the box, runs the Python
proxy unchanged.

## Layout

| File | Purpose |
| --- | --- |
| `proxy/api/stops.py`, `plan.py`, `departures.py` | One Vercel function per endpoint; all reuse `transit_proxy.Handler` |
| `proxy/vercel.json` | Region (`fra1`, Frankfurt) and a 30 s time limit |
| `proxy/requirements.txt` | `tzdata` for `zoneinfo` |

Hosted paths carry an `/api` prefix: `https://<project>.vercel.app/api/stops`. The watch
appends `/stops` and `/plan` to `PROXY_URL`, so `PROXY_URL` ends with `/api`.

## Deploy the proxy

1. Push the repository to GitHub (a private repository is fine).
2. On vercel.com: *Add New > Project*, import the repository, set **Root Directory** to
   `proxy`, framework preset *Other*.
3. *Settings > Environment Variables*: add `TRANSIT_PROXY_KEY` with a long random value
   (`python3 -c "import secrets; print(secrets.token_urlsafe(24))"`), then redeploy.
4. Check: `https://<project>.vercel.app/api/stops?q=praha&k=<key>` returns stops; without
   `k` it returns `{"e":"bad_key"}`.
5. Your own key: add `TRANSIT_PROXY_PRIVATE_KEY` (another random value). Use it in your
   own `local.mk`; the store build gets `TRANSIT_PROXY_KEY`. Each key has its own daily
   budget, so strangers using up the public one do not block your watch.
6. Daily budget: *Storage* (or *Marketplace*) > *Upstash for Redis* > create a free
   database and connect it to the project. It adds `KV_REST_API_URL` and
   `KV_REST_API_TOKEN` (or `UPSTASH_REDIS_REST_URL` / `_TOKEN`); redeploy. Optional
   `PLAN_DAILY_LIMIT` and `PRIVATE_PLAN_DAILY_LIMIT` change the defaults 700 and 100.
   Without the database the proxy works, but with no cap.

Later pushes to the default branch deploy automatically.

## Build for the watch

Create `local.mk` in the project root (ignored by git):

```
PROXY_URL = https://<project>.vercel.app/api
PROXY_KEY = <TRANSIT_PROXY_PRIVATE_KEY for your own watch>
```

Then:

```
make release
```

Copy `bin/Transit-release.prg` to `GARMIN/APPS` on the watch (USB; on macOS through an
MTP tool such as OpenMTP). The phone with Garmin Connect must be connected to the watch
when searching.

## How the settings reach the app

The Makefile writes `source/BuildConfig.mc` before every build: the local proxy for
`make build` / `make run` / `make test-watch`, the values from `local.mk` for
`make release`, and always the app version from `manifest.xml`. The file is generated
and ignored by git; the key never enters the
repository. A fresh checkout needs one `make build` before the VS Code extension can
build on its own.
