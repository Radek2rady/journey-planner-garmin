# Tasks

Status of the work. Milestones are described in `PLAN.md`. Move items between sections as
part of the change that affects them.

## In progress (M2: On the wrist)

- [ ] Confirm on the watch: direction in the leg detail, saved connections without the
      phone, departure time

- [ ] Measure memory use on the device (peak during the connections response)
- [ ] Confirm on the watch: favourite trips, countdown, search again from a saved search,
      filters, departure board
- [ ] Confirm on the watch: short connection summary fits; full text of a leg line opens
      with START
- [ ] Confirm on the watch: change time and the "!" of a tight change, "If missed" search
      from a change (needs the proxy deployed with leg keys `i` and `s`)

- [ ] Confirm on the watch: *Nearby stops* in the origin chooser (needs the proxy
      deployed)

- [ ] Confirm on the watch: deleting saved searches and recent stops

- [ ] Confirm on the watch: the glance shows the first favourite and its next departure;
      check that it is redrawn often enough for the countdown

- [ ] Confirm on the watch: arrive-by search and *Earlier connections* (needs the proxy
      deployed)

- [ ] Confirm on the watch: the departure alert appears with the app closed (in the
      simulator: *Simulation > Background Events*); also while an activity runs

## To do

### Later (decided: not now)

- [ ] Download favourite trips over Wi-Fi before leaving (Wi-Fi bulk download: sync mode,
      `Communications.startSync`, only on Wi-Fi networks saved in the watch); for a dead
      phone. Unverified whether sync mode accepts our proxy requests on the fr955

### Comfort

- [ ] Name entry by letter groups (no holding of DOWN needed)

### Housekeeping

- [ ] Decide whether the project folder should be renamed from `Odjezdy` to `Transit`

## Done

- [x] Data source chosen and verified for the whole Czech Republic (Transitous)
- [x] Proxy with compact wire format, input validation, optional shared key
- [x] Proxy unit tests and smoke test against the live service
- [x] Watch app: layered structure (model, data, ui), strict type check, zero warnings
- [x] Origin by GPS or stop, destination by stop, recent stops, swap
- [x] Connection list, leg detail with platform, delay and cancellation, later connections
- [x] English and Czech strings in resources
- [x] Watch unit tests (35, passing in the simulator): parsing, storage round trips, recent
      stops, coordinates, API client, name entry, smoke tests of every screen
- [x] Own stop name entry (`StopNameEntry`) instead of the native `TextPicker`, which
      crashed the fr955 simulator on input ("Symbol Not Found Error: Failed invoking
      <symbol>", empty stack)
- [x] Full flow verified in the simulator: stop search, connections with a transfer
- [x] Hosted proxy prepared: Vercel entry points (`proxy/api/`), proxy tests (27)
- [x] Proxy address and key as build settings (`local.mk`, generated `BuildConfig`)
- [x] Proxy deployed to Vercel; release build sideloaded and working on the Forerunner 955
- [x] Name entry: holding UP keeps moving through the letters (4 per second); holding
      DOWN is reserved by the watch for music controls
- [x] Direction (headsign) of a ride in the leg detail; wire key `h`
- [x] Saved connections: results of the last 10 searches (one per trip) readable offline
- [x] Departure time selection: now, an hour of the next 24, or another day up to 10
      days ahead; quarter-hour steps; wire parameter `t`
- [x] Connection summary shortened to fit one menu line ("3h08, 674>538 +2"); a leg line
      opens in full on its own screen
- [x] Favourite trips: add the planned trip, one press sets it and searches, remove
- [x] Countdown to departure in the connection list ("in 7 min", "departed"), refreshed
      every 30 s; wire key `s`
- [x] Search again from a saved search; saved searches keep the stops, not just names
- [x] Filters: transfers (any, direct only, max 1, max 2) and vehicles (all, trains only,
      without trains), remembered across launches; wire parameters `x` and `v`
- [x] Departure board of the nearest or a recent stop, with countdown, delay, platform,
      later departures;
      endpoint `/departures`
- [x] App type changed from watch-app to widget, so it opens from the glance loop and
      not only from the activity list (which is blocked during an activity); own glance
      view, required for the glance list from API 4.0; services kept out of glance mode
- [x] Change time between rides in the leg detail; a change with under 3 min to spare
      after walking is marked "!" there and in the connection summary
- [x] "If missed": connections from the station of a change to the destination, leaving
      after the planned ride; wire leg keys `i` and `s`
- [x] Transit opens from the glance loop, also during an activity suspended with Resume
      Later (confirmed on the watch)
- [x] Errors in words by cause (phone, timeout, cancelled, too large, bad response, HTTPS,
      proxy key, bad request, data source); the number only for an unknown cause
- [x] Alert before the departure of a chosen connection: 5, 10 or 15 min, a notification
      from a background service (`Background`, `Notifications` permissions); one at a time
- [x] Arrive-by search: a switch in the time menu; the list then pages to earlier
      connections; "now" always departs; wire parameter `a`
- [x] Glance with the next departure of the first favourite trip, from its last saved
      search (no request from the glance); countdown under 2 hours
- [x] Delete saved searches and recent stops, one or all, from the end of their lists;
      the planned trip keeps its stops
- [x] Nearby stops by GPS in the origin chooser: stops within 500 m with distance, one
      per place (feed variants of one station merged); `/stops` without `q`
- [x] Git repository initialized and pushed to GitHub (by the user)
- [x] Makefile, README, CLAUDE.md, API contract, plan
