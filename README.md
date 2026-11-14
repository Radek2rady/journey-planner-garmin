# Transit

Public transport journey planner for the Garmin Forerunner 955. Choose where from (your GPS
position or a stop) and where to; the watch lists the next connections anywhere in the
Czech Republic, including transfers, platforms and delays.

Timetable data comes from [Transitous](https://transitous.org), a free community-run
routing service.

## Requirements

- Connect IQ SDK 9.x with the `fr955` device (Connect IQ SDK Manager)
- A developer key (`Monkey C: Generate a Developer Key` in VS Code)
- Java, Python 3.9+, `make`

## Quick start

Three terminals:

```
make proxy        # 1. response-shrinking proxy
make simulator    # 2. Connect IQ simulator
make run          # 3. build and start the app
```

In the simulator, uncheck **Settings > Use Device HTTPS Requirements** (the local proxy
speaks plain HTTP) and set a position with **Settings > Set Position**.

## Using the app

| Screen | Action |
| --- | --- |
| Glance (watch face, UP/DOWN) | Destination of the first favourite trip and its next departure from the last search; START opens the app |
| Home | START or tap opens the menu |
| Menu > From | *My location*, *Nearby stops* (pick one, with distance), *Enter name*, or a recent stop; *Delete recent stops* at the end |
| Menu > To | *Enter name* or a recent stop; *Delete recent stops* at the end |
| Enter name | UP/DOWN or swipe choose a letter (hold UP to move fast), START or tap types it, BACK erases; *Search* (one step above A) finishes |
| Menu > Favourite trips | Choose a trip to search it at once; *Add current trip*; *Remove a trip* |
| Menu > Departure | *Arrive by* switches the time to the latest arrival; *Now*, an hour of the next 24 hours, or *Another day* (up to 10 days ahead); then the minutes. By arrival, the list offers *Earlier connections* |
| Menu > Filters | Transfers and vehicles; each press moves to the next choice |
| Menu > Search over Wi-Fi | Without the phone, on a Wi-Fi network saved in the watch (no sign-in page): searches the planned trip; the watch closes the app, the result lands in *Saved connections* |
| Menu > Departure board | What leaves next from the nearest stop or a recent one; *Later departures* continues |
| Menu > Saved connections | Results of the last 10 searches, readable without the phone; *Search again* refreshes them; *Delete searches* at the end (one, or *Delete all*) |
| Menu > Find connections | Lists connections: "15:50-20:21 4h31" with the travel time from the first ride (without the walk to it), "!" = tight change; select one to see its legs, select a leg line to read it in full |
| Connection detail > *Alert before departure* | Each press: 5, 10, 15 minutes before, off; the watch shows a notification then, also with the app closed. One alert at a time |
| Connection detail > *Change N min* | Shows the time for the change; select it to see what else goes from that station (*If missed*) |

## On the watch

Host the proxy, put its address into `local.mk`, run `make release` and copy
`bin/Transit-release.prg` to `GARMIN/APPS`. Step by step: [docs/DEPLOY.md](docs/DEPLOY.md).

## Documentation

- [CLAUDE.md](CLAUDE.md): architecture, conventions, definition of done
- [docs/API.md](docs/API.md): wire format between the watch and the proxy
- [docs/DEPLOY.md](docs/DEPLOY.md): hosting the proxy, building for the watch
- [docs/PLAN.md](docs/PLAN.md): roadmap
- [docs/TASKS.md](docs/TASKS.md): done and to do
