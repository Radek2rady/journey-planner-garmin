# Deployment

A real watch only talks to public `https://` addresses, so the proxy has to be hosted.
The reference setup is Vercel: free Hobby plan, HTTPS out of the box, runs the Python
proxy unchanged.

## Layout

| File | Purpose |
| --- | --- |
| `proxy/api/stops.py`, `proxy/api/plan.py` | One Vercel function per endpoint; both reuse `transit_proxy.Handler` |
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

Later pushes to the default branch deploy automatically.

## Build for the watch

Create `local.mk` in the project root (ignored by git):

```
PROXY_URL = https://<project>.vercel.app/api
PROXY_KEY = <the same value as TRANSIT_PROXY_KEY>
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
`make release`. The file is generated and ignored by git; the key never enters the
repository. A fresh checkout needs one `make build` before the VS Code extension can
build on its own.
