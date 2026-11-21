# Proxy API

Wire format between the watch app (`source/data/TransitApi.mc`, parsers in `source/model/`)
and the proxy (`proxy/transit_proxy.py`). Keys are one letter on purpose: every byte
travels over Bluetooth and is parsed in a few hundred kB of memory.

All responses are JSON objects. When `TRANSIT_PROXY_KEY` is set, every request must carry
it as `k`.

## GET /stops

| Parameter | Required | Meaning |
| --- | --- | --- |
| `q` | no | Stop name, at least 2 characters; diacritics optional |
| `lat`, `lon` | no | Position in degrees, three decimals (about 100 m); with `q` nearby stops rank higher, without `q` the stops around the position are returned |

Either `q` or a valid `lat` and `lon` is required.

```json
{"s": [{"n": "Vestec,u Klimešů", "i": "cz-PID_U1207Z1", "a": "Vestec, okres Praha-západ"}]}
```

| Key | Meaning |
| --- | --- |
| `s` | Stops, best match first, at most 8 |
| `n` | Name |
| `i` | Id, opaque; pass it back as `from` / `to` |
| `a` | Municipality and district; may be empty (always empty without `q`) |
| `m` | Distance from `lat`/`lon` in metres (from the rounded position, so up to ~60 m off); only without `q`. Stops within 500 m, nearest first, one per place |

## GET /plan

| Parameter | Required | Meaning |
| --- | --- | --- |
| `from` | yes | Stop id, or `lat,lon` in degrees (three decimals) |
| `to` | yes | Stop id |
| `t` | no | Departure time, Unix seconds; the search starts then instead of now |
| `c` | no | Cursor from a previous response; returns the following connections. Overrides `t` |
| `x` | no | Maximum number of transfers, `0` to `5`; `0` means direct connections only |
| `v` | no | Allowed vehicles: comma-separated vehicle codes (`bus`, `tram`, `metro`, `train`, `ferry`, `cable`, `air`) |
| `a` | no | `1`: `t` is the latest arrival ("arrive by") instead of the departure, and `n` leads to earlier connections. Needs `t` or `c`; repeat it with `c` |

`x` and `v` must be repeated together with `c`.

Without `t` and `c` the search starts at the current time.

```json
{
  "c": [{
    "d": "16:16", "a": "16:57", "s": 1794410160, "m": 41, "r": "331 > C",
    "l": [
      {"k": "walk", "m": 3, "t": "Vestec,u Klimešů"},
      {"k": "bus", "r": "331", "f": "Vestec,u Klimešů", "d": "16:19",
       "t": "Opatov", "a": "16:33", "p": "B", "z": 1}
    ]
  }],
  "n": "LATER|1762878000"
}
```

Connection:

| Key | Meaning |
| --- | --- |
| `c` | Connections in departure order, at most 5 |
| `n` | Cursor for later connections; empty when there are none |
| `d`, `a` | Departure and arrival, local time `HH:MM` (Europe/Prague) |
| `s` | Departure as Unix seconds, for counting down to it |
| `m` | Total duration in minutes |
| `r` | Lines in travel order |
| `l` | Legs |

Leg:

| Key | Present | Meaning |
| --- | --- | --- |
| `k` | always | `walk`, or a vehicle: `bus`, `tram`, `metro`, `train`, `ferry`, `cable`, `air`, `other` |
| `t` | always | Destination stop of the leg; empty when it is the journey's end point |
| `m` | walk | Walking time in minutes; walks under one minute are omitted |
| `r` | ride | Line or train name |
| `f` | ride | Boarding stop |
| `d`, `a` | ride | Departure and arrival, `HH:MM`, including the delay |
| `s` | ride | Departure as Unix seconds, including the delay |
| `i` | optional | Station id of the boarding stop (the parent station, not the platform); usable as `from` of `/plan` to search on from a change |
| `h` | optional | Direction (headsign); omitted when unknown or equal to `t` |
| `p` | optional | Platform or stand |
| `z` | optional | Delay in minutes (negative = early); only when real-time data says so |
| `x` | optional | `1` when the ride is cancelled |

## GET /departures

Departure board of one stop: what leaves next, in all directions.

| Parameter | Required | Meaning |
| --- | --- | --- |
| `stop` | one of | Stop id |
| `lat`, `lon` | one of | Position in degrees (three decimals); the nearest stop is used |
| `c` | no | Cursor from a previous response; returns later departures. Needs `stop` |

```json
{"n": "Vestec,BIOCEV", "i": "cz-PID_U4178Z1", "d": [
  {"k": "bus", "r": "326", "h": "Jesenice,Belnická", "d": "16:19", "s": 1794410340, "p": "A", "z": 1}
], "c": "LATER|1794559020"}
```

| Key | Present | Meaning |
| --- | --- | --- |
| `n` | always | Name of the stop; empty when no stop is near the position |
| `i` | always | Id of the stop; pass it as `stop` together with `c` |
| `d` | always | Departures in time order, at most 10 |
| `c` | always | Cursor for later departures; empty when there are none |
| `k` | always | Vehicle code |
| `r` | always | Line or train name |
| `h` | always | Direction (headsign); may be empty |
| `d` | always | Departure, local time `HH:MM`, including the delay |
| `s` | always | Departure as Unix seconds |
| `p` | optional | Platform or stand |
| `z` | optional | Delay in minutes; only when real-time data says so |
| `x` | optional | `1` when the departure is cancelled |

## Errors

Non-200 responses carry `{"e": "<code>"}`:

| Status | Code | Meaning |
| --- | --- | --- |
| 400 | `bad_request` | Missing, too short or malformed parameter |
| 403 | `bad_key` | Wrong or missing `k` |
| 404 | `not_found` | Unknown path |
| 502 | `upstream`, `upstream_<status>` | Transitous failed or timed out |
