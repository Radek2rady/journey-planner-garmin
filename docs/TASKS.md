# Tasks

Status of the work. Milestones are described in `PLAN.md`. Move items between sections as
part of the change that affects them.

## In progress: watch test before 1.0.1

Run on the fr955 with `make release` (sideloaded) while Garmin reviews 1.0.0. Tick what
works; anything that does not becomes a fix in 1.0.1.

Search and results
- [ ] Origin by *My location*: the location question appears once, before the first use;
      until then the origin reads "Moje poloha (nepovolena)"
- [ ] *Nearby stops* in the origin chooser, with distances
- [ ] Stop search by name: "Vlak, Praha-východ" / "Bus, Benešov" under the stops (1.0.1)
- [ ] Connection list: label with the travel time fits one line ("23 min" under an hour)
- [ ] Countdown to departure in the list, *Later connections*, arrive-by search and
      *Earlier connections*, filters (transfers, vehicles), departure time
- [ ] Connection detail: direction, platform, change time and the "!" of a tight change;
      a leg line opens in full with START; *If missed* from a change
- [ ] Departure board of the nearest stop and of a recent stop, *Later departures*

Kept on the watch
- [ ] Favourite trips: add, search with one press, remove
- [ ] Saved connections readable without the phone; *Search again*; deleting saved
      searches and recent stops
- [ ] Glance: the first favourite and its next departure; redrawn often enough for the
      countdown

Background and edges
- [ ] Departure alert with the app closed, also while an activity runs
- [ ] Search over Wi-Fi with the phone's Bluetooth off (does sync mode reach the proxy,
      how long does it take?)
- [ ] *About*: text fits in both languages; *Privacy policy* opens on the phone
- [ ] Launcher icon readable in the fr955's MIP colours
- [ ] Memory: peak during the connections response (simulator *View > Memory* with the
      fr955, or the watch's crash log if it runs out)

## To do

### M5: Connect IQ Store

- [ ] Wait for Garmin's review of 1.0.0 (submitted 2026-11-22) and of the new beta; then
      install 1.0.0 from the store, remove the beta and the sideloaded `.prg` from the
      watch, tag `v1.0.0` and attach `bin/Transit-store.iq` to a GitHub release
- [ ] 1.0.1: version in `manifest.xml`, `make store` and `make beta`, upload both
- [ ] Protect `main` on GitHub: changes only through pull requests with passing
      *Proxy tests* (by the user)
- [ ] Watch the proxy's daily `/plan` count on Vercel; tell Transitous on Matrix before it
      gets near 720 a day
- [ ] Vercel WAF limit per IP only if abuse shows up (one rule on Hobby; mobile carriers
      share IPs)
- [ ] Look into building the watch app in CI (SDK and device files without a sign-in)

### Comfort

- [x] Next app version: travel time under an hour without "0h" ("08:11-08:34 23 min")
- [x] Next app version: the stop list says what stops there ("Vlak, Praha-východ" /
      "Bus, Benešov"); `v` in `/stops` from Transitous' modes (train > metro > tram > bus),
      kept with the recent stops
- [x] Stop search merges parts of one station named with or without the town ("Praha,
      hlavni nadrazi", "Hlavní nádraží", "Praha,Hlavní nádraží"; within 300 m), the merged
      entry says the most important vehicle; stops where nothing runs are left out
- [ ] Name entry by letter groups (no holding of DOWN needed)

### Housekeeping

- [ ] Decide whether the project folder should be renamed from `Odjezdy` (code name Transit, app name Spojení CZ)

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
- [x] Search over Wi-Fi without the phone (sync mode, Wi-Fi networks saved in the watch):
      the planned trip; results go to the saved searches
- [x] Travel time in the connection label ("15:50-20:21 4h31"), from the first ride
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
- [x] App version in `manifest.xml`, passed to the app through `BuildConfig`; About item
      at the end of the main menu with the version and the data sources (Transitous,
      OpenStreetMap)
- [x] Proxy `User-Agent` with its version and the repository URL as contact
- [x] Location only after consent: no GPS and no position in any request until the user
      says yes to a one-time question, asked on the first action that needs the position
      (My location, Nearby stops, nearest departure board, search or Wi-Fi search from
      the current position); the answer is remembered
- [x] App name "Spojení CZ" in both languages (store name); code name stays Transit
- [x] MIT `LICENSE`; README credits Transitous and OpenStreetMap
- [x] Branch and pull request workflow; GitHub Actions runs the proxy tests on Python 3.9
      and 3.12 for each pull request and push to `main`
- [x] Makefile, README, CLAUDE.md, API contract, plan
- [x] 55 watches with API 5.2+ in the manifest (Forerunner 165-970, fenix 7/8/9/E, epix 2,
      enduro 3/4, MARQ 2/3, Venu 3/4/X1, vivoactive 5/6, Instinct 3 and Crossover AMOLED);
      left out: Venu 2 and Venu Sq 2 (API 5.0), Instinct with the small semi-octagon
      screen, bike computers; debug builds per device (`bin/Transit-<device>.prg`), so
      `make run DEVICE=...` always runs the right one
- [x] Texts that would run off the screen are shortened with "..." (`TextFit`): the glance
      title and detail, the name being typed (its end stays visible); the glance hint falls back
      to a short variant ("Connections" / "Spojení") before shortening
- [x] Czech texts never use "spoj/spoje": "Uložená spojení", "Dřívější/Pozdější
      spojení", "Spojení, odjezdy", unknown vehicle "Linka"
- [x] Privacy policy in `PRIVACY.md` (English and Czech), approved by the user on
      2026-11-21; contact through GitHub issues, no e-mail for now; public once the
      repository is public
- [x] Position sent with three decimals (about 100 m) instead of five (about 1 m); requests
      stay GET, so that the planned CDN cache works, and the privacy policy says Vercel
      keeps request logs for about an hour (user's decision)
- [x] Proxy protection: CDN cache (`s-maxage`: stops 1 day, departures 30 s, connections
      60 s), daily `/plan` budget in Upstash Redis (700 public, 100 for the developer's
      private key; allowed when the counter is down), `429 rate_limited`, the watch says
      "Busy, try later" / "Zkus to později" also for a bare 429
- [x] `make release` ends with the full path, time and size of the watch build, so that a
      simulator build (`localhost`, times out on the watch) is not copied by mistake
- [x] Repository public; Vercel set up with the private key and Upstash; cache (HIT on a
      repeated request) and the `/plan` counter checked on 2026-11-21; the watch build
      with the private key works on the fr955
- [x] About is a small menu: the app (version, data sources) and *Privacy policy*, which
      the phone opens (`Communications.openWebPage`, `Config.PRIVACY_URL`)
- [x] Store packages: `make beta` (own app id, private key) and `make store` (public
      key); built from a copy in `bin/pkg`; all 67 device builds without warnings
- [x] Stop search by name keeps Transitous' order (it ranked Brno hl.n. first, from the
      Austrian feed, and our Czech-first sort pushed it down), merges copies of one station
      (equal names within 1 km, similar within 200 m; Czech id preferred) and puts the
      searched town's main station first
- [x] Store texts in Czech and English approved by the user (informal Czech, keywords
      without third-party marks); kept locally in `store/listing.md`
- [x] Name entry: the typed name on up to two lines in the largest font that fits (its end
      stays visible when even that is too long); smaller letters (current one medium,
      neighbours tiny), as the user chose after the fr255s check; names up to 24 letters
      instead of 16 ("USTI NAD ORLICI MESTO" then finds the right station first)
- [x] Departure board shows a train found in two feeds once ("S7 (Os 9974)" and "S7" at
      the same time and direction), keeping the copy with platform or delay
- [x] Store screenshots in Czech from the fr965 simulator, approved by the user: glance,
      home, connection list, connection detail, full leg text (`store/screens/cz-1..5.jpg`,
      local only); public contact e-mail entered by the user
- [x] The proxy trims spaces and line breaks around its keys from the host's settings
- [x] Version 1.0.0 for the first public release (app in `manifest.xml`, proxy `VERSION`)
- [x] Screens checked in the simulator on 2026-11-21: fr255s (218 px), fenix7s (240 px),
      fr265 (416 px AMOLED), fr965 (454 px AMOLED), venux1 (rectangle), fr955 on the watch;
      glance, home, menus, name entry, stop and connection lists, detail, About all fit
- [x] Developer key backed up outside this computer (by the user, 2026-11-21)
- [x] Stop search tells towns of one name apart: the area under a stop is the district
      when the name holds the town ("Mnichovice" / "Praha-východ" vs "Benešov"),
      without "okres"; before, the district was cut off on the watch (proxy only)
- [x] The beta also waits for Garmin's review after its first upload
- [x] Privacy policy URL in the store listing; beta uploaded again with the new
      `BETA_APP_ID` (2026-11-22)
- [x] Public version 1.0.0 submitted to the store (`make store`, 2026-11-22)
- [x] Beta 0.9.0 uploaded to the store with *Beta App* checked (2026-11-21): working
      description, cover `store/cover-500.png`, three simulator screenshots in
      `store/screens/` (local only, ignored by git), privacy policy and source code links
- [x] Launcher icon chosen by the user (option C: bus and train on a navy circle) in every
      size the devices expect (`resources-icon-<size>`); lights left out at 38 and 40 px
