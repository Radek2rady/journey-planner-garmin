# Tasks

Status of the work. Milestones are described in `PLAN.md`. Move items between sections as
part of the change that affects them.

## In progress (M2: On the wrist)

- [ ] Deploy the proxy to Vercel (`docs/DEPLOY.md`); needs a GitHub repository and a
      Vercel account
- [ ] Create `local.mk`, `make release`, sideload, test on the Forerunner 955
- [ ] Measure memory use on the device (peak during the connections response)
- [ ] Check text fit on the 260x260 round display: long stop names, leg detail lines

## To do

### M3: Faster daily use

- [ ] Favourite trips
- [ ] Departure board of the nearest stop
- [ ] Departure time selection
- [ ] Countdown to departure

### Housekeeping

- [ ] Show the direction (headsign) of a ride in the leg detail
- [ ] Decide whether the project folder should be renamed from `Odjezdy` to `Transit`

## Done

- [x] Data source chosen and verified for the whole Czech Republic (Transitous)
- [x] Proxy with compact wire format, input validation, optional shared key
- [x] Proxy unit tests and smoke test against the live service
- [x] Watch app: layered structure (model, data, ui), strict type check, zero warnings
- [x] Origin by GPS or stop, destination by stop, recent stops, swap
- [x] Connection list, leg detail with platform, delay and cancellation, later connections
- [x] English and Czech strings in resources
- [x] Watch unit tests (16, passing in the simulator): parsing, recent stops, coordinates,
      API client, name entry, smoke tests of every screen
- [x] Own stop name entry (`StopNameEntry`) instead of the native `TextPicker`, which
      crashed the fr955 simulator on input ("Symbol Not Found Error: Failed invoking
      <symbol>", empty stack)
- [x] Full flow verified in the simulator: stop search, connections with a transfer
- [x] Hosted proxy prepared: Vercel entry points (`proxy/api/`), proxy tests (27)
- [x] Proxy address and key as build settings (`local.mk`, generated `BuildConfig`)
- [x] Git repository initialized and pushed to GitHub (by the user)
- [x] Makefile, README, CLAUDE.md, API contract, plan
