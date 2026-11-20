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
| Branch and pull request per change, squash merge, CI on proxy tests | `main` deploys the production proxy; a pull request gets a Vercel preview to try first. Watch build and tests stay local: they need the Connect IQ SDK, the device files and the simulator. |

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

### M5: Connect IQ Store

Publish the app for free, mainly to go through the whole release process. Constraints
found on 2026-11-20:

- Transitous allows only open-source, non-commercial apps that are light on its
  resources (heavy use: over 720 `/plan` requests a day; then contact the project on
  Matrix first). Every request needs a `User-Agent` with app name, version and contact.
  Attribution: a visible link to transitous.org/sources and the OpenStreetMap notice.
- Czech feeds: CZPTT trains and JDF buses CC0 (Oběhy), PID CC BY, IDS JMK and PMDP own
  open-data terms. Fine for a free app with attribution.
- Garmin: free developer account; a privacy policy is required because positions and
  search terms leave the watch; location only after the user opts in; the listing names
  all dependencies (phone, internet, third-party service); no Garmin or third-party
  marks in the name.
- Store name: "Spojení CZ" in both languages ("Transit" clashes with an existing app).
  Czech departure-board apps exist in the store (Odjezdy, Mobi, LiveBus, PID, ...); none
  plans A-to-B connections with changes across trains, buses and city transport, so the
  listing stresses connections and names "jízdní řád", "vlak", "MHD" in the description.

Exit criteria: the app is approved and listed in the store.

## Risks

| Risk | Mitigation |
| --- | --- |
| Transitous is a volunteer service without guarantees | The proxy contract isolates the app; the source can be swapped without touching the watch code. |
| Request needs the phone nearby | Inherent to the platform (no LTE on fr955); results of the last searches are kept on the watch. Saved delays are those known at search time. |
| Typing stop names is slow | Recents now, favourites in M3. |
