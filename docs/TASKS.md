# Tasks

Status of the work. Milestones are described in `PLAN.md`. Move items between sections as
part of the change that affects them.

## In progress (M2: On the wrist)

- [ ] Confirm on the watch: direction in the leg detail, saved connections without the
      phone, departure time

- [ ] Measure memory use on the device (peak during the connections response)
- [ ] Check text fit on the 260x260 round display: long stop names, leg detail lines

## To do

### M3: Faster daily use

- [ ] Favourite trips
- [ ] Departure board of the nearest stop
- [ ] Countdown to departure

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
- [x] Watch unit tests (22, passing in the simulator): parsing, storage round trips, recent
      stops, coordinates, API client, name entry, smoke tests of every screen
- [x] Own stop name entry (`StopNameEntry`) instead of the native `TextPicker`, which
      crashed the fr955 simulator on input ("Symbol Not Found Error: Failed invoking
      <symbol>", empty stack)
- [x] Full flow verified in the simulator: stop search, connections with a transfer
- [x] Hosted proxy prepared: Vercel entry points (`proxy/api/`), proxy tests (27)
- [x] Proxy address and key as build settings (`local.mk`, generated `BuildConfig`)
- [x] Proxy deployed to Vercel; release build sideloaded and working on the Forerunner 955
- [x] Name entry: holding UP/DOWN keeps moving through the letters (4 per second)
- [x] Direction (headsign) of a ride in the leg detail; wire key `h`
- [x] Saved connections: results of the last 10 searches (one per trip) readable offline
- [x] Departure time selection: now, an hour of the next 24, or another day up to 10
      days ahead; quarter-hour steps; wire parameter `t`
- [x] Git repository initialized and pushed to GitHub (by the user)
- [x] Makefile, README, CLAUDE.md, API contract, plan
