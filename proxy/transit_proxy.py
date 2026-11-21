#!/usr/bin/env python3
"""Response-shrinking proxy between the watch app and the Transitous API.

A Connect IQ app can only handle responses of a few kB, while Transitous
returns hundreds of kB per journey search. This server forwards the query and
keeps only the fields the watch displays. It returns codes, never UI text;
localization happens on the watch. The wire format is documented in
docs/API.md.

Run:  python3 proxy/transit_proxy.py      (listens on http://127.0.0.1:8787)

Environment:
  PORT               listening port (default 8787)
  HOST               bind address (default 127.0.0.1; use 0.0.0.0 when hosted)
  TRANSIT_PROXY_KEY  optional shared secret, sent by the watch as parameter k
  TRANSIT_PROXY_PRIVATE_KEY  optional second key for the developer's own build; it has
                     its own daily budget, so an exhausted public one does not block it
  UPSTASH_REDIS_REST_URL, UPSTASH_REDIS_REST_TOKEN (or KV_REST_API_URL, KV_REST_API_TOKEN)
                     counter of the daily /plan budget; without them there is no cap
  PLAN_DAILY_LIMIT, PRIVATE_PLAN_DAILY_LIMIT  the budgets (default 700 and 100)

No dependencies, Python 3.9+.
"""

from __future__ import annotations

import json
import math
import re
import unicodedata
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Optional
from zoneinfo import ZoneInfo

API = "https://api.transitous.org/api/v1"
# Transitous asks every client for its name, version and a contact.
VERSION = "0.9.0"
USER_AGENT = f"journey-planner-garmin/{VERSION} (+https://github.com/Radek2rady/journey-planner-garmin)"
TIMEZONE = ZoneInfo("Europe/Prague")
UPSTREAM_TIMEOUT_S = 25

MAX_STOPS = 8
MAX_CONNECTIONS = 5
MAX_DEPARTURES = 10
# Platforms of one stop are separate upstream stops; this radius joins them.
STOP_RADIUS_M = 200
NEARBY_RADIUS_M = 500  # how far /stops looks around a position without a name
WALK = "walk"

# Transitous (MOTIS) mode -> vehicle code understood by the watch app.
VEHICLES = {
    "BUS": "bus",
    "COACH": "bus",
    "TRAM": "tram",
    "SUBWAY": "metro",
    "METRO": "metro",
    "FERRY": "ferry",
    "FUNICULAR": "cable",
    "AERIAL_LIFT": "cable",
    "CABLE_CAR": "cable",
    "AIRPLANE": "air",
}

# Vehicle code -> upstream modes, for the vehicle filter of /plan.
MODES = {
    "bus": ["BUS", "COACH"],
    "tram": ["TRAM"],
    "metro": ["SUBWAY", "METRO"],
    "train": ["RAIL"],
    "ferry": ["FERRY"],
    "cable": ["FUNICULAR", "AERIAL_LIFT", "CABLE_CAR"],
    "air": ["AIRPLANE"],
}
MAX_TRANSFER_LIMIT = 5

# Seconds the CDN in front of the hosted proxy may keep a successful answer.
CACHE_STOPS_S = 24 * 3600
CACHE_DEPARTURES_S = 30
CACHE_PLAN_S = 60
COUNTER_TIMEOUT_S = 3
COUNTER_TTL_S = 2 * 24 * 3600

Json = dict[str, Any]


def vehicle_code(mode: str) -> str:
    if mode in VEHICLES:
        return VEHICLES[mode]
    if "RAIL" in mode or mode == "SUBURBAN":
        return "train"
    return "other"


def call_api(path: str, params: dict[str, str]) -> Any:
    url = API + path + "?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=UPSTREAM_TIMEOUT_S) as response:
        return json.load(response)


def parse_time(text: str) -> datetime:
    return datetime.fromisoformat(text.replace("Z", "+00:00"))


def local_hhmm(text: str) -> str:
    return parse_time(text).astimezone(TIMEZONE).strftime("%H:%M")


def stop_area(areas: list[Json]) -> str:
    """Human-readable location of a stop, e.g. "Vestec, okres Praha-západ"."""
    by_level = {area.get("adminLevel"): area["name"] for area in areas}
    # Municipality (8), else region (4, e.g. Praha); plus district (5),
    # except Prague boroughs, which only add noise.
    town = by_level.get(8) or by_level.get(4) or ""
    district = by_level.get(5, "")
    if district.startswith("obvod"):
        district = ""
    return ", ".join(part for part in dict.fromkeys([town, district]) if part)


def search_stops(query: str, lat: Optional[str], lon: Optional[str]) -> Json:
    params = {"text": query, "language": "cs", "type": "STOP"}
    if lat and lon:
        params["place"] = lat + "," + lon
        params["placeBias"] = "2"
    # Czech feeds first; foreign feeds carry duplicates of Czech stations.
    found = sorted(call_api("/geocode", params), key=lambda item: not item.get("id", "").startswith("cz-"))
    stops: list[Json] = []
    seen: set[tuple[str, str]] = set()
    for item in found:
        if item.get("type") != "STOP":
            continue
        area = stop_area(item.get("areas", []))
        key = (item["name"], area)
        if key in seen:
            continue
        seen.add(key)
        stops.append({"n": item["name"], "i": item["id"], "a": area})
        if len(stops) >= MAX_STOPS:
            break
    return {"s": stops}


def distance_m(lat1: float, lon1: float, lat2: float, lon2: float) -> int:
    """Distance in metres; flat-earth approximation, exact enough within a few km."""
    dy = (lat2 - lat1) * 111_320
    dx = (lon2 - lon1) * 111_320 * math.cos(math.radians(lat1))
    return round(math.hypot(dx, dy))


def name_words(name: str) -> frozenset[str]:
    """Words of a stop name without case, diacritics and punctuation; "hl.n." is spelled out."""
    plain = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode().lower()
    plain = re.sub(r"hl\.\s*n\.?", "hlavni nadrazi", plain)
    return frozenset(re.findall(r"[a-z0-9]+", plain))


def same_place(a: Json, b: Json) -> bool:
    """One stop named differently by two feeds: close together, one name within the other."""
    if distance_m(a["lat"], a["lon"], b["lat"], b["lon"]) > STOP_RADIUS_M:
        return False
    words_a, words_b = name_words(a["n"]), name_words(b["n"])
    return bool(words_a) and bool(words_b) and (words_a <= words_b or words_b <= words_a)


def nearby_stops(lat: str, lon: str) -> Json:
    """Stops within NEARBY_RADIUS_M of the position, nearest first, one per place.

    Platforms of one stop share its name and are merged; any of their ids works
    as `from`, because routing walks to the other platforms. Czech feeds name
    the same station differently ("Praha hl.n.", "Hlavní nádraží"); such
    variants are merged as well. Foreign feeds are used only where no Czech
    feed covers the place, as they duplicate it.
    """
    here_lat, here_lon = float(lat), float(lon)
    dlat = NEARBY_RADIUS_M / 111_320
    dlon = dlat / max(math.cos(math.radians(here_lat)), 0.01)
    found = call_api("/map/stops", {
        "min": "%.5f,%.5f" % (here_lat - dlat, here_lon - dlon),
        "max": "%.5f,%.5f" % (here_lat + dlat, here_lon + dlon),
    })
    if any(item.get("stopId", "").startswith("cz-") for item in found):
        found = [item for item in found if item.get("stopId", "").startswith("cz-")]
    nearest: dict[str, Json] = {}
    for item in found:
        name = item.get("name", "")
        if not name or "lat" not in item or "lon" not in item:
            continue
        metres = distance_m(here_lat, here_lon, item["lat"], item["lon"])
        if metres > NEARBY_RADIUS_M:
            continue
        if name not in nearest or metres < nearest[name]["m"]:
            nearest[name] = {"n": name, "i": item.get("parentId") or item["stopId"], "a": "", "m": metres,
                             "lat": item["lat"], "lon": item["lon"]}
    places: list[Json] = []
    for stop in sorted(nearest.values(), key=lambda stop: stop["m"]):
        if not any(same_place(stop, kept) for kept in places):
            places.append(stop)
    return {"s": [{key: stop[key] for key in ("n", "i", "a", "m")} for stop in places[:MAX_STOPS]]}


def place_name(place: Json) -> str:
    """Stop name, or "" for the synthetic journey endpoints."""
    name = place.get("name", "")
    return "" if name in ("START", "END") else name


def compact_leg(leg: Json) -> Optional[Json]:
    """One leg in wire format, or None for walks too short to mention."""
    if leg["mode"] == "WALK":
        minutes = round(leg.get("duration", 0) / 60)
        if minutes < 1:
            return None
        return {"k": WALK, "m": minutes, "t": place_name(leg["to"])}
    out: Json = {
        "k": vehicle_code(leg["mode"]),
        "r": leg.get("displayName") or leg.get("routeShortName") or "",
        "f": place_name(leg["from"]),
        "d": local_hhmm(leg["startTime"]),
        "t": place_name(leg["to"]),
        "a": local_hhmm(leg["endTime"]),
        "s": int(parse_time(leg["startTime"]).timestamp()),
    }
    # The station rather than the platform, so that a search from the
    # boarding stop finds rides from all its platforms.
    station = leg["from"].get("parentId") or leg["from"].get("stopId")
    if station:
        out["i"] = station
    headsign = leg.get("headsign")
    if headsign and headsign != out["t"]:
        out["h"] = headsign
    track = leg["from"].get("track")
    if track:
        out["p"] = str(track)
    if leg.get("realTime") and leg.get("scheduledStartTime"):
        delay = parse_time(leg["startTime"]) - parse_time(leg["scheduledStartTime"])
        delay_minutes = round(delay.total_seconds() / 60)
        if delay_minutes:
            out["z"] = delay_minutes
    if leg.get("cancelled"):
        out["x"] = 1
    return out


def compact_connection(itinerary: Json) -> Json:
    legs = [leg for leg in map(compact_leg, itinerary["legs"]) if leg]
    return {
        "d": local_hhmm(itinerary["startTime"]),
        "a": local_hhmm(itinerary["endTime"]),
        "s": int(parse_time(itinerary["startTime"]).timestamp()),
        "m": round(itinerary["duration"] / 60),
        "r": " > ".join(leg["r"] for leg in legs if leg["k"] != WALK),
        "l": legs,
    }


def transfer_count(itinerary: Json) -> int:
    rides = sum(1 for leg in itinerary["legs"] if leg["mode"] != "WALK")
    return max(rides - 1, 0)


def search_connections(origin: str, destination: str, cursor: Optional[str],
                       departure: Optional[int] = None, max_transfers: Optional[int] = None,
                       vehicles: Optional[list[str]] = None, arrive_by: bool = False) -> Json:
    """Connections departing at `departure` (Unix seconds) or now; `cursor` continues a search.

    With `arrive_by`, `departure` is the latest arrival instead, and the cursor
    returned leads to earlier connections rather than later ones.
    `max_transfers` and `vehicles` (vehicle codes) narrow the search and apply to
    continued searches as well.
    """
    params = {
        "fromPlace": origin,
        "toPlace": destination,
        "numItineraries": str(MAX_CONNECTIONS),
        "detailedTransfers": "false",
    }
    if cursor:
        params["pageCursor"] = cursor
    else:
        start = datetime.fromtimestamp(departure, timezone.utc) if departure else datetime.now(timezone.utc)
        params["time"] = start.strftime("%Y-%m-%dT%H:%M:%SZ")
    if max_transfers is not None:
        # Upstream counts one more than the number of changes: its limit N returns
        # at most N - 1 transfers. Ask for one more and enforce the limit below,
        # which stays correct if upstream changes its counting.
        params["maxTransfers"] = str(max_transfers + 1)
    if vehicles:
        params["transitModes"] = ",".join(mode for code in vehicles for mode in MODES[code])
    if arrive_by:
        params["arriveBy"] = "true"
    data = call_api("/plan", params)
    itineraries = [it for it in data.get("itineraries", [])
                   if max_transfers is None or transfer_count(it) <= max_transfers][:MAX_CONNECTIONS]
    cursor_key = "previousPageCursor" if arrive_by else "nextPageCursor"
    return {"c": [compact_connection(it) for it in itineraries], "n": data.get(cursor_key, "")}


def compact_departure(stop_time: Json) -> Optional[Json]:
    """One line of a departure board, or None for a vehicle that only arrives."""
    place = stop_time["place"]
    if not place.get("departure") or place.get("pickupType") == "NOT_ALLOWED":
        return None
    out: Json = {
        "k": vehicle_code(stop_time["mode"]),
        "r": stop_time.get("displayName") or stop_time.get("routeShortName") or "",
        "h": stop_time.get("headsign") or "",
        "d": local_hhmm(place["departure"]),
        "s": int(parse_time(place["departure"]).timestamp()),
    }
    track = place.get("track")
    if track:
        out["p"] = str(track)
    if stop_time.get("realTime") and place.get("scheduledDeparture"):
        delay = parse_time(place["departure"]) - parse_time(place["scheduledDeparture"])
        delay_minutes = round(delay.total_seconds() / 60)
        if delay_minutes:
            out["z"] = delay_minutes
    if stop_time.get("cancelled") or place.get("cancelled"):
        out["x"] = 1
    return out


def nearest_stop(lat: str, lon: str) -> Optional[Json]:
    found = call_api("/reverse-geocode", {"place": lat + "," + lon, "type": "STOP"})
    return next((item for item in found if item.get("type") == "STOP"), None)


def search_departures(stop: Optional[str], lat: Optional[str] = None, lon: Optional[str] = None,
                      cursor: Optional[str] = None) -> Json:
    """Next departures from the stop `stop`, or from the stop nearest to the position.

    `cursor` continues the board of `stop` with later departures.
    """
    name = None
    if not stop:
        nearest = nearest_stop(lat or "", lon or "")
        if nearest is None:
            return {"n": "", "i": "", "d": [], "c": ""}
        stop, name = nearest["id"], nearest["name"]
    params = {"stopId": stop, "n": str(MAX_DEPARTURES), "radius": str(STOP_RADIUS_M)}
    if cursor:
        params["pageCursor"] = cursor
    else:
        params["time"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    data = call_api("/stoptimes", params)
    departures = [line for line in map(compact_departure, data.get("stopTimes", [])) if line]
    return {
        "n": name or data.get("place", {}).get("name", ""),
        "i": stop,
        "d": departures[:MAX_DEPARTURES],
        "c": data.get("nextPageCursor", ""),
    }


def cache_seconds(path: str, status: int) -> int:
    """How long the CDN may cache an answer; errors are never cached."""
    if status != 200:
        return 0
    return {"/stops": CACHE_STOPS_S, "/departures": CACHE_DEPARTURES_S, "/plan": CACHE_PLAN_S}.get(path, 0)


def counter_settings() -> Optional[tuple[str, str]]:
    url = os.environ.get("UPSTASH_REDIS_REST_URL") or os.environ.get("KV_REST_API_URL")
    token = os.environ.get("UPSTASH_REDIS_REST_TOKEN") or os.environ.get("KV_REST_API_TOKEN")
    return (url.rstrip("/"), token) if url and token else None


def count_today(name: str) -> Optional[int]:
    """Adds one to today's counter `name`; None when no counter is set up or reachable."""
    settings = counter_settings()
    if settings is None:
        return None
    url, token = settings
    key = "%s:%s" % (name, datetime.now(TIMEZONE).strftime("%Y-%m-%d"))
    body = json.dumps([["INCR", key], ["EXPIRE", key, str(COUNTER_TTL_S)]]).encode()
    request = urllib.request.Request(url + "/pipeline", data=body, method="POST", headers={
        "Authorization": "Bearer " + token, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=COUNTER_TIMEOUT_S) as response:
            return int(json.load(response)[0]["result"])
    except Exception as error:  # noqa: BLE001 - a broken counter must not stop searches
        print("counter error:", type(error).__name__, file=sys.stderr)
        return None


def take_plan_budget(private: bool) -> bool:
    """Counts one /plan request against today's budget; False once it is used up.

    Without a reachable counter the request is allowed: Transitous has no hard limit,
    and a short outage of the counter must not make the app unusable.
    """
    if private:
        count, limit = count_today("plan-private"), int(os.environ.get("PRIVATE_PLAN_DAILY_LIMIT", "100"))
    else:
        count, limit = count_today("plan"), int(os.environ.get("PLAN_DAILY_LIMIT", "700"))
    return count is None or count <= limit


def is_coordinate(text: str, limit: float) -> bool:
    try:
        return abs(float(text)) <= limit
    except ValueError:
        return False


def handle(path: str, query: dict[str, str], key: str = "", private_key: str = "") -> tuple[int, Json]:
    """Route one request; returns (HTTP status, JSON body)."""
    private = bool(private_key) and query.get("k") == private_key
    if key and query.get("k") != key and not private:
        return 403, {"e": "bad_key"}
    try:
        if path == "/stops":
            text = query.get("q", "").strip()
            lat, lon = query.get("lat", ""), query.get("lon", "")
            if not text and is_coordinate(lat, 90) and is_coordinate(lon, 180):
                return 200, nearby_stops(lat, lon)
            if len(text) < 2:
                return 400, {"e": "bad_request"}
            return 200, search_stops(text, lat or None, lon or None)
        if path == "/plan":
            origin, destination = query.get("from", ""), query.get("to", "")
            if not origin or not destination:
                return 400, {"e": "bad_request"}
            departure = query.get("t", "")
            if departure and not (departure.isdigit() and len(departure) <= 10):
                return 400, {"e": "bad_request"}
            transfers = query.get("x", "")
            if transfers and not (transfers.isdigit() and int(transfers) <= MAX_TRANSFER_LIMIT):
                return 400, {"e": "bad_request"}
            vehicles = [code for code in query.get("v", "").split(",") if code]
            if any(code not in MODES for code in vehicles):
                return 400, {"e": "bad_request"}
            arrive_by = query.get("a", "")
            if arrive_by not in ("", "1") or (arrive_by and not departure and not query.get("c")):
                return 400, {"e": "bad_request"}
            if not take_plan_budget(private):
                return 429, {"e": "rate_limited"}
            return 200, search_connections(origin, destination, query.get("c"), int(departure) if departure else None,
                                           int(transfers) if transfers else None, vehicles, arrive_by == "1")
        if path == "/departures":
            stop, lat, lon = query.get("stop", ""), query.get("lat", ""), query.get("lon", "")
            if not stop and not (is_coordinate(lat, 90) and is_coordinate(lon, 180)):
                return 400, {"e": "bad_request"}
            return 200, search_departures(stop, lat, lon, query.get("c"))
        return 404, {"e": "not_found"}
    except urllib.error.HTTPError as error:
        return 502, {"e": "upstream_%d" % error.code}
    except Exception as error:  # noqa: BLE001 - the watch must always get JSON
        print("error:", repr(error), file=sys.stderr)
        return 502, {"e": "upstream"}


class Handler(BaseHTTPRequestHandler):
    key = os.environ.get("TRANSIT_PROXY_KEY", "")
    private_key = os.environ.get("TRANSIT_PROXY_PRIVATE_KEY", "")
    # Fixed endpoint for hosts that run one function per path (see proxy/api/);
    # None takes the endpoint from the request path.
    route: Optional[str] = None

    def do_GET(self) -> None:  # noqa: N802 - name required by BaseHTTPRequestHandler
        url = urllib.parse.urlparse(self.path)
        query = {name: values[0] for name, values in urllib.parse.parse_qs(url.query).items()}
        path = self.route or url.path
        status, body = handle(path, query, self.key, self.private_key)
        raw = json.dumps(body, ensure_ascii=False, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        seconds = cache_seconds(path, status)
        self.send_header("Cache-Control", "public, max-age=0, s-maxage=%d" % seconds if seconds else "no-store")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
        # Log the path only: query strings contain positions and search terms.
        status = args[1] if len(args) > 1 else ""
        print(self.command, urllib.parse.urlparse(self.path).path, status)


def main() -> None:
    host = os.environ.get("HOST", "127.0.0.1")
    port = int(os.environ.get("PORT", "8787"))
    server = ThreadingHTTPServer((host, port), Handler)
    print("Transit proxy listening on http://%s:%d" % (host, port))
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
