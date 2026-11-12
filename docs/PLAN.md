# Plan

Goal: find a public transport connection anywhere in the Czech Republic from the wrist in
under 30 seconds, without taking out the phone.

## Decisions

| Decision | Reason |
| --- | --- |
| Data from Transitous (MOTIS) | The only free source covering trains, buses and city transport of the whole country with real-time delays. IDOS has no public API; Golemio covers Prague and Central Bohemia only. |
| Own proxy | Transitous responses (~170 kB) exceed what a watch can receive; the proxy cuts them to ~2 kB. It also hides the upstream API behind a stable contract. |
| Native `Menu2` for all lists | Scrolling, touch and buttons work out of the box and look like the rest of the watch. |
| Own letter-by-letter name entry instead of `TextPicker` | The native picker crashed the simulator on input; an own view behaves the same with buttons and touch and is covered by tests. |
| Proxy hosted on Vercel (free plan) | No own server; HTTPS included; runs the stdlib Python proxy unchanged, so there is one implementation and one test suite. |
| Proxy address and key are build settings (`local.mk`) | Keeps the key out of the repository and lets debug builds use the local proxy. |
| Stops entered by name once, then picked from recents | Typing on a watch is slow; most trips repeat. |

## Milestones

### M1: Working prototype in the simulator (current)

Origin by GPS or stop name, destination by stop name, list of connections, leg detail,
later connections, recent stops, English and Czech UI.

Exit criteria: full flow verified in the simulator; all tests green.

### M2: On the wrist

- Proxy hosted at a public HTTPS address, protected by `TRANSIT_PROXY_KEY`
- Release build sideloaded to the Forerunner 955
- Verified on the device: GPS fix time, text input, request latency over Bluetooth,
  memory headroom, readability of long stop names

### M3: Faster daily use

- Saved connections: results of the last searches readable without the phone (done)
- Search for a chosen departure time, not only "now" (done)
- Favourite trips: one press sets the trip and searches (done)
- Departure board of the nearest or a recent stop (done)
- Countdown to departure in the connection list (done)

### M4: Resilience

- Glance view with the next departure of the favourite trip
- More devices than fr955

## Risks

| Risk | Mitigation |
| --- | --- |
| Transitous is a volunteer service without guarantees | The proxy contract isolates the app; the source can be swapped without touching the watch code. |
| Request needs the phone nearby | Inherent to the platform (no LTE on fr955); results of the last searches are kept on the watch. Saved delays are those known at search time. |
| Typing stop names is slow | Recents now, favourites in M3. |
