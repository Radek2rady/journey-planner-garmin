# Proxy API

Wire format between the watch app (`source/data/TransitApi.mc`, parsers in `source/model/`)
and the proxy (`proxy/transit_proxy.py`). Keys are one letter on purpose: every byte
travels over Bluetooth and is parsed in a few hundred kB of memory.

All responses are JSON objects. When `TRANSIT_PROXY_KEY` is set, every request must carry
it as `k`.

## GET /stops

| Parameter | Required | Meaning |
| --- | --- | --- |
| `q` | yes | Stop name, at least 2 characters; diacritics optional |
| `lat`, `lon` | no | Position in degrees; nearby stops rank higher |

```json
{"s": [{"n": "Vestec,u Klimešů", "i": "cz-PID_U1207Z1", "a": "Vestec, okres Praha-západ"}]}
```

| Key | Meaning |
| --- | --- |
| `s` | Stops, best match first, at most 8 |
| `n` | Name |
| `i` | Id, opaque; pass it back as `from` / `to` |
| `a` | Municipality and district; may be empty |

## GET /plan

| Parameter | Required | Meaning |
| --- | --- | --- |
| `from` | yes | Stop id, or `lat,lon` in degrees |
| `to` | yes | Stop id |
| `c` | no | Cursor from a previous response; returns the following connections |

Without `c` the search starts at the current time.

```json
{
  "c": [{
    "d": "16:16", "a": "16:57", "m": 41, "r": "331 > C",
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
| `p` | optional | Platform or stand |
| `z` | optional | Delay in minutes (negative = early); only when real-time data says so |
| `x` | optional | `1` when the ride is cancelled |

## Errors

Non-200 responses carry `{"e": "<code>"}`:

| Status | Code | Meaning |
| --- | --- | --- |
| 400 | `bad_request` | Missing or too short parameter |
| 403 | `bad_key` | Wrong or missing `k` |
| 404 | `not_found` | Unknown path |
| 502 | `upstream`, `upstream_<status>` | Transitous failed or timed out |
