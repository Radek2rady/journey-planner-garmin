"""Unit tests for the proxy. Run: python3 -m unittest discover -s proxy"""

import importlib
import io
import threading
import unittest
import urllib.error
import urllib.request
from unittest import mock

import transit_proxy as proxy


def transit_leg(**overrides):
    leg = {
        "mode": "BUS",
        "displayName": "331",
        "from": {"name": "Vestec,u Klimešů", "track": "B", "stopId": "cz-1P", "parentId": "cz-1"},
        "to": {"name": "Opatov"},
        "startTime": "2026-11-11T15:19:00Z",
        "endTime": "2026-11-11T15:33:00Z",
        "scheduledStartTime": "2026-11-11T15:18:00Z",
        "realTime": True,
    }
    leg.update(overrides)
    return leg


def walk_leg(seconds, to="Opatov"):
    return {"mode": "WALK", "duration": seconds, "to": {"name": to}}


def geocode_item(name, stop_id, areas=()):
    return {
        "type": "STOP",
        "name": name,
        "id": stop_id,
        "areas": [{"adminLevel": level, "name": area} for level, area in areas],
    }


class VehicleCodeTest(unittest.TestCase):
    def test_known_modes(self):
        self.assertEqual(proxy.vehicle_code("SUBWAY"), "metro")
        self.assertEqual(proxy.vehicle_code("COACH"), "bus")

    def test_every_rail_mode_is_a_train(self):
        for mode in ("REGIONAL_RAIL", "HIGHSPEED_RAIL", "NIGHT_RAIL", "SUBURBAN"):
            self.assertEqual(proxy.vehicle_code(mode), "train")

    def test_unknown_mode(self):
        self.assertEqual(proxy.vehicle_code("ODM"), "other")


class TimeTest(unittest.TestCase):
    def test_winter_time(self):
        self.assertEqual(proxy.local_hhmm("2026-11-11T15:19:00Z"), "16:19")

    def test_summer_time(self):
        self.assertEqual(proxy.local_hhmm("2026-07-01T15:19:00Z"), "17:19")


class StopAreaTest(unittest.TestCase):
    def test_town_and_district(self):
        areas = [{"adminLevel": 8, "name": "Vestec"}, {"adminLevel": 5, "name": "okres Praha-západ"}]
        self.assertEqual(proxy.stop_area(areas), "Vestec, Praha-západ")

    def test_district_alone_when_the_name_holds_the_town(self):
        near_prague = [{"adminLevel": 8, "name": "Mnichovice"}, {"adminLevel": 5, "name": "okres Praha-východ"}]
        near_benesov = [{"adminLevel": 8, "name": "Mnichovice"}, {"adminLevel": 5, "name": "okres Benešov"}]
        self.assertEqual(proxy.stop_area(near_prague, "Mnichovice"), "Praha-východ")
        self.assertEqual(proxy.stop_area(near_benesov, "Mnichovice,náves"), "Benešov")
        self.assertEqual(proxy.stop_area(near_prague, "Myšlín"), "Mnichovice, Praha-východ")

    def test_city_district_named_after_the_city_is_left_out(self):
        areas = [{"adminLevel": 8, "name": "Plzeň"}, {"adminLevel": 5, "name": "okres Plzeň-město"}]
        self.assertEqual(proxy.stop_area(areas, "Lhota"), "Plzeň")
        self.assertEqual(proxy.stop_area(areas, "Plzeň hl.n."), "Plzeň")

    def test_prague_uses_region_and_drops_borough(self):
        areas = [{"adminLevel": 4, "name": "Praha"}, {"adminLevel": 5, "name": "obvod Praha 2"}]
        self.assertEqual(proxy.stop_area(areas), "Praha")

    def test_no_areas(self):
        self.assertEqual(proxy.stop_area([]), "")


class CompactLegTest(unittest.TestCase):
    def test_transit_leg(self):
        self.assertEqual(
            proxy.compact_leg(transit_leg()),
            {"k": "bus", "r": "331", "f": "Vestec,u Klimešů", "d": "16:19", "t": "Opatov", "a": "16:33",
             "s": 1794410340, "i": "cz-1", "p": "B", "z": 1},
        )

    def test_boarding_stop_without_a_station_uses_the_stop(self):
        leg = proxy.compact_leg(transit_leg(**{"from": {"name": "Opatov", "stopId": "cz-2"}}))
        self.assertEqual(leg["i"], "cz-2")

    def test_boarding_stop_without_an_id_has_none(self):
        self.assertNotIn("i", proxy.compact_leg(transit_leg(**{"from": {"name": "Opatov"}})))

    def test_headsign_is_passed_on(self):
        self.assertEqual(proxy.compact_leg(transit_leg(headsign="Háje"))["h"], "Háje")

    def test_headsign_equal_to_the_alighting_stop_is_omitted(self):
        self.assertNotIn("h", proxy.compact_leg(transit_leg(headsign="Opatov")))

    def test_on_time_leg_has_no_delay(self):
        leg = proxy.compact_leg(transit_leg(scheduledStartTime="2026-11-11T15:19:00Z"))
        self.assertNotIn("z", leg)

    def test_scheduled_only_leg_has_no_delay(self):
        self.assertNotIn("z", proxy.compact_leg(transit_leg(realTime=False)))

    def test_cancelled_leg(self):
        self.assertEqual(proxy.compact_leg(transit_leg(cancelled=True))["x"], 1)

    def test_walk(self):
        self.assertEqual(proxy.compact_leg(walk_leg(200)), {"k": "walk", "m": 3, "t": "Opatov"})

    def test_short_walk_is_dropped(self):
        self.assertIsNone(proxy.compact_leg(walk_leg(20)))

    def test_synthetic_endpoint_has_no_name(self):
        self.assertEqual(proxy.compact_leg(walk_leg(200, to="END"))["t"], "")


class CompactConnectionTest(unittest.TestCase):
    def test_summary_lists_transit_lines_only(self):
        itinerary = {
            "startTime": "2026-11-11T15:16:00Z",
            "endTime": "2026-11-11T15:57:00Z",
            "duration": 2460,
            "legs": [walk_leg(180), transit_leg(), walk_leg(10), transit_leg(mode="SUBWAY", displayName="C")],
        }
        connection = proxy.compact_connection(itinerary)
        self.assertEqual(connection["d"], "16:16")
        self.assertEqual(connection["a"], "16:57")
        self.assertEqual(connection["s"], 1794410160)
        self.assertEqual(connection["m"], 41)
        self.assertEqual(connection["r"], "331 > C")
        self.assertEqual([leg["k"] for leg in connection["l"]], ["walk", "bus", "metro"])


class SearchStopsTest(unittest.TestCase):
    def search(self, items, lat=None, lon=None):
        with mock.patch.object(proxy, "call_api", return_value=items) as call:
            return proxy.search_stops("vestec", lat, lon), call

    def test_upstream_order_is_kept_and_duplicates_removed(self):
        result, _ = self.search(
            [
                geocode_item("Brno hl.n.", "at-1"),
                geocode_item("Brno hlavní nádraží", "cz-1", [(8, "Brno")]),
                geocode_item("Brno hlavní nádraží", "cz-2", [(8, "Brno")]),
                {"type": "ADDRESS", "name": "Brno", "id": "x"},
            ]
        )
        self.assertEqual([stop["i"] for stop in result["s"]], ["at-1", "cz-1"])
        self.assertEqual(result["s"][1], {"n": "Brno hlavní nádraží", "i": "cz-1", "a": "Brno"})

    def test_copies_of_one_place_merge_into_the_first_with_the_czech_id(self):
        def at(item, lat, lon):
            return dict(item, lat=lat, lon=lon)
        result, _ = self.search(
            [
                at(geocode_item("Brno hl.n.", "at-1", [(8, "Brno")]), 49.1906, 16.6127),
                at(geocode_item("Brno", "ee-1", [(8, "Brno")]), 49.1909, 16.6125),
                at(geocode_item("Brno-Židenice", "cz-2", [(8, "Brno")]), 49.2001, 16.6420),
                at(geocode_item("Brno hl. n.", "hu-1", [(8, "Brno")]), 49.1907, 16.6128),
                at(geocode_item("Brno hl.n.", "cz-1", [(8, "Brno")]), 49.1905, 16.6126),
            ]
        )
        self.assertEqual([stop["i"] for stop in result["s"]], ["cz-1", "cz-2"])
        self.assertEqual(result["s"][0]["n"], "Brno hl.n.")

    def test_main_station_of_the_searched_town_comes_first(self):
        items = [geocode_item(name, "cz-%d" % i) for i, name in
                 enumerate(["Praha-Libeň", "Praha-Kyje", "Praha hl.n.", "Kolín hl.n."])]
        with mock.patch.object(proxy, "call_api", return_value=items):
            result = proxy.search_stops("praha", None, None)
        self.assertEqual([stop["n"] for stop in result["s"]], ["Praha hl.n.", "Praha-Libeň", "Praha-Kyje", "Kolín hl.n."])
        with mock.patch.object(proxy, "call_api", return_value=items):
            result = proxy.search_stops("libeň", None, None)
        self.assertEqual(result["s"][0]["n"], "Praha-Libeň")

    def test_parts_of_one_station_named_with_or_without_the_town_merge(self):
        def at(name, stop_id, lat, lon, modes):
            return dict(geocode_item(name, stop_id, [(4, "Praha")]), lat=lat, lon=lon, modes=modes)
        result, _ = self.search(
            [
                at("Praha, hlavni nadrazi", "cz-1", 50.0830, 14.4350, ["BUS"]),
                at("Hlavní nádraží", "cz-2", 50.0841, 14.4360, ["SUBWAY", "TRAM"]),
                at("Praha,Hlavní nádraží", "cz-3", 50.0838, 14.4339, ["COACH", "REGIONAL_RAIL"]),
                at("Hlavní nádraží", "cz-4", 49.1906, 16.6127, ["TRAM"]),
            ]
        )
        self.assertEqual([stop["i"] for stop in result["s"]], ["cz-1", "cz-4"])
        self.assertEqual(result["s"][0]["v"], "train")

    def test_equal_names_merge_further_apart_than_similar_ones(self):
        def at(name, stop_id, lat, lon):
            return dict(geocode_item(name, stop_id, [(8, "Brno")]), lat=lat, lon=lon)
        result, _ = self.search(
            [
                at("Brno hl.n.", "at-1", 49.19037, 16.61234),
                at("Brno", "ee-1", 49.19000, 16.62000),
                at("BRNO", "eu-1", 49.19386, 16.61439),
                at("Brno hl. n.", "hu-1", 49.18917, 16.60972),
            ]
        )
        self.assertEqual([stop["i"] for stop in result["s"]], ["at-1", "ee-1"])

    def test_stop_says_what_stops_there(self):
        self.assertEqual(proxy.stop_kind(["BUS", "REGIONAL_RAIL"]), "train")
        self.assertEqual(proxy.stop_kind(["SUBWAY", "TRAM", "BUS"]), "metro")
        self.assertEqual(proxy.stop_kind(["COACH"]), "bus")
        self.assertIsNone(proxy.stop_kind([]))
        result, _ = self.search([dict(geocode_item("Mnichovice", "cz-1"), modes=["REGIONAL_RAIL"]),
                                 geocode_item("Mnichovice", "cz-2", [(5, "okres Benešov")])])
        self.assertEqual(result["s"][0]["v"], "train")
        self.assertNotIn("v", result["s"][1])

    def test_stops_without_any_service_are_left_out(self):
        result, _ = self.search([dict(geocode_item("Brno", "ee-1"), modes=[]),
                                 dict(geocode_item("Brno hl.n.", "cz-1"), modes=["REGIONAL_RAIL"]),
                                 geocode_item("Vestec", "cz-2")])
        self.assertEqual([stop["i"] for stop in result["s"]], ["cz-1", "cz-2"])

    def test_result_is_capped(self):
        items = [geocode_item("Stop %d" % i, "cz-%d" % i) for i in range(30)]
        result, _ = self.search(items)
        self.assertEqual(len(result["s"]), proxy.MAX_STOPS)

    def test_position_biases_the_search(self):
        _, call = self.search([], "49.98", "14.50")
        self.assertEqual(call.call_args[0][1]["place"], "49.98,14.50")


def map_stop(name, stop_id, lat, lon, parent=None):
    item = {"name": name, "stopId": stop_id, "lat": lat, "lon": lon}
    if parent:
        item["parentId"] = parent
    return item


class NearbyStopsTest(unittest.TestCase):
    HERE = ("50.08300", "14.43500")

    def nearby(self, items):
        with mock.patch.object(proxy, "call_api", return_value=items) as call:
            return proxy.nearby_stops(*self.HERE), call

    def test_nearest_first_one_per_name_with_distance(self):
        result, call = self.nearby([
            map_stop("Jindřišská", "cz-PID_U203Z1P", 50.0850, 14.4300),
            map_stop("Hlavní nádraží", "cz-PID_U142Z1P", 50.0835, 14.4341),
            map_stop("Hlavní nádraží", "cz-PID_U142Z102P", 50.0831, 14.4351, parent="cz-PID_U142S1"),
        ])
        self.assertEqual(call.call_args[0][0], "/map/stops")
        self.assertEqual([stop["n"] for stop in result["s"]], ["Hlavní nádraží", "Jindřišská"])
        self.assertEqual(result["s"][0]["i"], "cz-PID_U142S1")
        self.assertEqual(result["s"][0]["a"], "")
        self.assertLess(result["s"][0]["m"], 20)

    def test_foreign_duplicates_are_dropped_where_czech_feeds_exist(self):
        result, _ = self.nearby([
            map_stop("Praha hl.n.", "de-DELFI_1", 50.0831, 14.4351),
            map_stop("Praha hlavní nádraží", "cz-CZPTT_1:platform:1", 50.0831, 14.4351, parent="cz-CZPTT_1"),
        ])
        self.assertEqual([stop["i"] for stop in result["s"]], ["cz-CZPTT_1"])

    def test_one_station_named_differently_by_czech_feeds_is_merged(self):
        result, _ = self.nearby([
            map_stop("Praha,Hlavní nádraží", "cz-JDF-1", 50.0834, 14.4352),
            map_stop("Praha hl.n.", "cz-IDZK-1", 50.0831, 14.4359),
            map_stop("Hlavní nádraží", "cz-PID_U142S1", 50.0835, 14.4341),
            map_stop("Hlavní třída", "cz-other", 50.0835, 14.4345),
        ])
        self.assertEqual([stop["n"] for stop in result["s"]], ["Praha,Hlavní nádraží", "Hlavní třída"])

    def test_name_words_ignore_case_diacritics_and_abbreviation(self):
        self.assertEqual(proxy.name_words("Praha hl. n."), proxy.name_words("praha,Hlavní nádraží"))

    def test_foreign_stops_are_kept_where_no_czech_feed_exists(self):
        result, _ = self.nearby([map_stop("Bratislava hl.st.", "sk-1", 50.0831, 14.4351)])
        self.assertEqual([stop["i"] for stop in result["s"]], ["sk-1"])

    def test_stops_outside_the_radius_and_the_cap(self):
        far = map_stop("Far", "cz-far", 50.0900, 14.4350)
        many = [map_stop("Stop %d" % i, "cz-%d" % i, 50.0830 + i * 0.0001, 14.4350) for i in range(20)]
        result, _ = self.nearby([far] + many)
        self.assertNotIn("Far", [stop["n"] for stop in result["s"]])
        self.assertEqual(len(result["s"]), proxy.MAX_STOPS)

    def test_handle_routes_a_position_without_a_name(self):
        with mock.patch.object(proxy, "nearby_stops", return_value={"s": []}) as nearby:
            self.assertEqual(proxy.handle("/stops", {"lat": "50.083", "lon": "14.435"}), (200, {"s": []}))
        nearby.assert_called_once_with("50.083", "14.435")

    def test_handle_rejects_a_bad_position(self):
        self.assertEqual(proxy.handle("/stops", {"lat": "500", "lon": "14.435"})[0], 400)


class HandleTest(unittest.TestCase):
    def test_rejects_wrong_key(self):
        self.assertEqual(proxy.handle("/stops", {"q": "vestec", "k": "no"}, key="secret"), (403, {"e": "bad_key"}))

    def test_rejects_short_query(self):
        self.assertEqual(proxy.handle("/stops", {"q": "v"}), (400, {"e": "bad_request"}))

    def test_rejects_plan_without_destination(self):
        self.assertEqual(proxy.handle("/plan", {"from": "a"}), (400, {"e": "bad_request"}))

    def test_unknown_path(self):
        self.assertEqual(proxy.handle("/nope", {}), (404, {"e": "not_found"}))

    def test_upstream_http_error(self):
        error = urllib.error.HTTPError("http://x", 429, "Too Many Requests", None, None)
        with mock.patch.object(proxy, "call_api", side_effect=error):
            self.assertEqual(proxy.handle("/stops", {"q": "vestec"}), (502, {"e": "upstream_429"}))

    def test_upstream_failure(self):
        with mock.patch.object(proxy, "call_api", side_effect=TimeoutError()), mock.patch("sys.stderr"):
            self.assertEqual(proxy.handle("/stops", {"q": "vestec"}), (502, {"e": "upstream"}))

    def test_plan_passes_cursor_instead_of_time(self):
        with mock.patch.object(proxy, "call_api", return_value={"itineraries": []}) as call:
            status, body = proxy.handle("/plan", {"from": "a", "to": "b", "c": "next"})
        self.assertEqual((status, body), (200, {"c": [], "n": ""}))
        params = call.call_args[0][1]
        self.assertEqual(params["pageCursor"], "next")
        self.assertNotIn("time", params)


class UserAgentTest(unittest.TestCase):
    def test_upstream_request_names_app_version_and_contact(self):
        response = mock.MagicMock()
        response.__enter__.return_value = io.BytesIO(b"[]")
        with mock.patch("urllib.request.urlopen", return_value=response) as urlopen:
            proxy.call_api("/geocode", {"text": "vestec"})
        agent = urlopen.call_args[0][0].get_header("User-agent")
        self.assertIn("journey-planner-garmin/" + proxy.VERSION, agent)
        self.assertIn("https://github.com/", agent)


class ProtectionTest(unittest.TestCase):
    def test_successful_answers_are_cached_errors_are_not(self):
        self.assertEqual(proxy.cache_seconds("/stops", 200), 24 * 3600)
        self.assertEqual(proxy.cache_seconds("/departures", 200), 30)
        self.assertEqual(proxy.cache_seconds("/plan", 200), 60)
        self.assertEqual(proxy.cache_seconds("/plan", 429), 0)
        self.assertEqual(proxy.cache_seconds("/nope", 200), 0)

    def test_plan_is_refused_when_the_budget_is_used_up(self):
        with mock.patch.object(proxy, "take_plan_budget", return_value=False), \
                mock.patch.object(proxy, "call_api") as call:
            self.assertEqual(proxy.handle("/plan", {"from": "a", "to": "b"}), (429, {"e": "rate_limited"}))
        call.assert_not_called()

    def test_private_key_is_accepted_and_uses_its_own_budget(self):
        with mock.patch.object(proxy, "take_plan_budget", return_value=True) as budget, \
                mock.patch.object(proxy, "call_api", return_value={"itineraries": []}):
            status, _ = proxy.handle("/plan", {"from": "a", "to": "b", "k": "mine"}, key="public", private_key="mine")
            self.assertEqual(status, 200)
            budget.assert_called_with(True)
            proxy.handle("/plan", {"from": "a", "to": "b", "k": "public"}, key="public", private_key="mine")
            budget.assert_called_with(False)
        self.assertEqual(proxy.handle("/stops", {"q": "vestec", "k": "other"}, key="public", private_key="mine"),
                         (403, {"e": "bad_key"}))

    def test_keys_pasted_with_spaces_still_match(self):
        env = {"TRANSIT_PROXY_KEY": " public\n", "TRANSIT_PROXY_PRIVATE_KEY": "mine \n"}
        with mock.patch.dict("os.environ", env):
            module = importlib.reload(proxy)
            try:
                self.assertEqual((module.Handler.key, module.Handler.private_key), ("public", "mine"))
            finally:
                importlib.reload(proxy)

    def test_budget_counts_per_day_and_stops_at_the_limit(self):
        env = {"UPSTASH_REDIS_REST_URL": "https://counter.example/", "UPSTASH_REDIS_REST_TOKEN": "t",
               "PLAN_DAILY_LIMIT": "2"}
        for count, allowed in ((2, True), (3, False)):
            response = mock.MagicMock()
            response.__enter__.return_value = io.BytesIO(b'[{"result": %d}, {"result": 1}]' % count)
            with mock.patch.dict("os.environ", env), \
                    mock.patch("urllib.request.urlopen", return_value=response) as urlopen:
                self.assertEqual(proxy.take_plan_budget(False), allowed)
            request = urlopen.call_args[0][0]
            self.assertEqual(request.full_url, "https://counter.example/pipeline")
            self.assertEqual(request.get_header("Authorization"), "Bearer t")
            self.assertIn(b'"INCR", "plan:', request.data)

    def test_server_sends_the_cache_header(self):
        server = proxy.ThreadingHTTPServer(("127.0.0.1", 0), proxy.Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base = "http://127.0.0.1:%d" % server.server_address[1]
        try:
            with mock.patch.object(proxy, "handle", return_value=(200, {"c": [], "n": ""})), \
                    mock.patch("builtins.print"):
                with urllib.request.urlopen(base + "/plan?from=a&to=b") as response:
                    self.assertEqual(response.headers["Cache-Control"], "public, max-age=0, s-maxage=60")
            with mock.patch("builtins.print"), self.assertRaises(urllib.error.HTTPError) as refused:
                urllib.request.urlopen(base + "/stops?q=v")
            self.assertEqual(refused.exception.headers["Cache-Control"], "no-store")
        finally:
            server.shutdown()
            server.server_close()

    def test_without_a_working_counter_searches_go_on(self):
        with mock.patch.dict("os.environ", {}, clear=True):
            self.assertTrue(proxy.take_plan_budget(False))
        env = {"KV_REST_API_URL": "https://counter.example", "KV_REST_API_TOKEN": "t"}
        with mock.patch.dict("os.environ", env, clear=True), mock.patch("sys.stderr"), \
                mock.patch("urllib.request.urlopen", side_effect=TimeoutError()):
            self.assertTrue(proxy.take_plan_budget(True))


class DepartureTimeTest(unittest.TestCase):
    def test_plan_passes_the_requested_departure_time(self):
        with mock.patch.object(proxy, "call_api", return_value={"itineraries": []}) as call:
            status, _ = proxy.handle("/plan", {"from": "a", "to": "b", "t": "1794510000"})
        self.assertEqual(status, 200)
        self.assertEqual(call.call_args[0][1]["time"], "2026-11-12T19:00:00Z")

    def test_plan_without_time_starts_now(self):
        with mock.patch.object(proxy, "call_api", return_value={"itineraries": []}) as call:
            proxy.handle("/plan", {"from": "a", "to": "b"})
        self.assertRegex(call.call_args[0][1]["time"], r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$")

    def test_plan_rejects_a_malformed_time(self):
        for value in ("soon", "-5", "17:30", "99999999999"):
            self.assertEqual(proxy.handle("/plan", {"from": "a", "to": "b", "t": value}), (400, {"e": "bad_request"}))


class ArriveByTest(unittest.TestCase):
    UPSTREAM = {"itineraries": [], "previousPageCursor": "EARLIER|1", "nextPageCursor": "LATER|2"}

    def plan(self, query):
        with mock.patch.object(proxy, "call_api", return_value=self.UPSTREAM) as call:
            status, body = proxy.handle("/plan", dict({"from": "a", "to": "b"}, **query))
        return status, body, call

    def test_arrival_time_and_earlier_cursor(self):
        status, body, call = self.plan({"t": "1794510000", "a": "1"})
        self.assertEqual(status, 200)
        self.assertEqual(call.call_args[0][1]["arriveBy"], "true")
        self.assertEqual(call.call_args[0][1]["time"], "2026-11-12T19:00:00Z")
        self.assertEqual(body["n"], "EARLIER|1")

    def test_continued_arrive_by_search_keeps_going_earlier(self):
        status, body, call = self.plan({"c": "EARLIER|1", "a": "1"})
        self.assertEqual(status, 200)
        self.assertEqual(call.call_args[0][1]["pageCursor"], "EARLIER|1")
        self.assertEqual(body["n"], "EARLIER|1")

    def test_departure_search_returns_the_later_cursor(self):
        _, body, call = self.plan({"t": "1794510000"})
        self.assertNotIn("arriveBy", call.call_args[0][1])
        self.assertEqual(body["n"], "LATER|2")

    def test_arrive_by_needs_a_time_and_a_valid_flag(self):
        self.assertEqual(self.plan({"a": "1"})[0], 400)
        self.assertEqual(self.plan({"t": "1794510000", "a": "yes"})[0], 400)


class FiltersTest(unittest.TestCase):
    def plan(self, query, itineraries=()):
        with mock.patch.object(proxy, "call_api", return_value={"itineraries": list(itineraries)}) as call:
            status, body = proxy.handle("/plan", dict({"from": "a", "to": "b"}, **query))
        return status, body, call.call_args[0][1] if call.called else None

    def itinerary(self, rides):
        return {"startTime": "2026-11-11T15:16:00Z", "endTime": "2026-11-11T15:57:00Z", "duration": 2460,
                "legs": [walk_leg(180)] + [transit_leg() for _ in range(rides)]}

    def test_no_filters_by_default(self):
        _, _, params = self.plan({})
        self.assertNotIn("maxTransfers", params)
        self.assertNotIn("transitModes", params)

    def test_transfer_limit_is_enforced_on_the_result(self):
        status, body, params = self.plan({"x": "1"}, [self.itinerary(1), self.itinerary(3), self.itinerary(2)])
        self.assertEqual(status, 200)
        self.assertEqual(params["maxTransfers"], "2")
        self.assertEqual([len(c["l"]) for c in body["c"]], [2, 3])

    def test_direct_only(self):
        _, body, _ = self.plan({"x": "0"}, [self.itinerary(2), self.itinerary(1)])
        self.assertEqual(len(body["c"]), 1)

    def test_vehicle_codes_become_upstream_modes(self):
        _, _, params = self.plan({"v": "train"})
        self.assertEqual(params["transitModes"], "RAIL")
        _, _, params = self.plan({"v": "bus,tram,metro"})
        self.assertEqual(params["transitModes"], "BUS,COACH,TRAM,SUBWAY,METRO")

    def test_filters_are_kept_when_continuing_a_search(self):
        _, _, params = self.plan({"c": "next", "x": "0", "v": "train"})
        self.assertEqual(params["pageCursor"], "next")
        self.assertEqual(params["maxTransfers"], "1")
        self.assertEqual(params["transitModes"], "RAIL")

    def test_malformed_filters_are_rejected(self):
        for query in ({"x": "many"}, {"x": "9"}, {"x": "-1"}, {"v": "rocket"}, {"v": "bus,RAIL"}):
            self.assertEqual(self.plan(query)[:2], (400, {"e": "bad_request"}))

    def test_transfer_count_ignores_walks(self):
        self.assertEqual(proxy.transfer_count(self.itinerary(3)), 2)
        self.assertEqual(proxy.transfer_count({"legs": [walk_leg(600)]}), 0)


def stop_time(**overrides):
    item = {
        "place": {"name": "Vestec,BIOCEV", "departure": "2026-11-11T15:19:00Z",
                  "scheduledDeparture": "2026-11-11T15:18:00Z", "track": "A", "pickupType": "NORMAL"},
        "mode": "BUS", "realTime": True, "headsign": "Jesenice,Belnická", "displayName": "326",
    }
    item.update(overrides)
    return item


class DeparturesTest(unittest.TestCase):
    def test_compact_departure(self):
        self.assertEqual(proxy.compact_departure(stop_time()), {
            "k": "bus", "r": "326", "h": "Jesenice,Belnická", "d": "16:19", "s": 1794410340, "p": "A", "z": 1})

    def test_scheduled_departure_has_no_delay(self):
        self.assertNotIn("z", proxy.compact_departure(stop_time(realTime=False)))

    def test_cancelled_departure(self):
        self.assertEqual(proxy.compact_departure(stop_time(cancelled=True))["x"], 1)

    def test_arrival_only_is_dropped(self):
        self.assertIsNone(proxy.compact_departure(stop_time(place={"name": "X", "arrival": "2026-11-11T15:19:00Z"})))
        terminating = {"name": "X", "departure": "2026-11-11T15:19:00Z", "pickupType": "NOT_ALLOWED"}
        self.assertIsNone(proxy.compact_departure(stop_time(place=terminating)))

    def test_copies_of_one_departure_from_two_feeds_appear_once(self):
        lines = [
            {"k": "train", "r": "S7", "h": "Řevnice", "d": "22:46", "s": 100},
            {"k": "train", "r": "S7 (Os 9974)", "h": "Řevnice", "d": "22:46", "s": 100, "p": "9"},
            {"k": "train", "r": "S7", "h": "Beroun", "d": "22:46", "s": 100},
            {"k": "tram", "r": "9", "h": "Řevnice", "d": "22:46", "s": 100},
            {"k": "train", "r": "S7", "h": "Řevnice", "d": "23:16", "s": 1900},
        ]
        result = proxy.without_copies(lines)
        self.assertEqual([(line["r"], line["h"], line["s"]) for line in result],
                         [("S7 (Os 9974)", "Řevnice", 100), ("S7", "Beroun", 100), ("9", "Řevnice", 100), ("S7", "Řevnice", 1900)])

    def test_board_of_a_stop(self):
        upstream = {"place": {"name": "Vestec,BIOCEV"}, "stopTimes": [stop_time(), stop_time(displayName="331")]}
        with mock.patch.object(proxy, "call_api", return_value=upstream) as call:
            status, body = proxy.handle("/departures", {"stop": "cz-1"})
        self.assertEqual(status, 200)
        self.assertEqual(body["n"], "Vestec,BIOCEV")
        self.assertEqual([line["r"] for line in body["d"]], ["326", "331"])
        self.assertEqual(body["i"], "cz-1")
        self.assertEqual(call.call_args[0][1]["stopId"], "cz-1")
        self.assertIn("time", call.call_args[0][1])

    def test_later_departures_use_the_cursor_instead_of_time(self):
        upstream = {"place": {"name": "Vestec"}, "stopTimes": [stop_time()], "nextPageCursor": "LATER|2"}
        with mock.patch.object(proxy, "call_api", return_value=upstream) as call:
            status, body = proxy.handle("/departures", {"stop": "cz-1", "c": "LATER|1"})
        self.assertEqual((status, body["c"]), (200, "LATER|2"))
        params = call.call_args[0][1]
        self.assertEqual(params["pageCursor"], "LATER|1")
        self.assertNotIn("time", params)

    def test_board_of_the_nearest_stop(self):
        def upstream(path, params):
            if path == "/reverse-geocode":
                self.assertEqual(params["place"], "49.98,14.49")
                return [{"type": "ADDRESS", "name": "x"}, {"type": "STOP", "id": "cz-9", "name": "Vestec"}]
            self.assertEqual(params["stopId"], "cz-9")
            return {"place": {"name": "center"}, "stopTimes": [stop_time()]}

        with mock.patch.object(proxy, "call_api", side_effect=upstream):
            status, body = proxy.handle("/departures", {"lat": "49.98", "lon": "14.49"})
        self.assertEqual((status, body["n"], body["i"], len(body["d"])), (200, "Vestec", "cz-9", 1))

    def test_no_stop_nearby(self):
        with mock.patch.object(proxy, "call_api", return_value=[]):
            self.assertEqual(proxy.handle("/departures", {"lat": "49.98", "lon": "14.49"}), (200, {"n": "", "i": "", "d": [], "c": ""}))

    def test_rejects_missing_or_malformed_place(self):
        for query in ({}, {"lat": "49.98"}, {"lat": "north", "lon": "14"}, {"lat": "95", "lon": "14"}):
            self.assertEqual(proxy.handle("/departures", query), (400, {"e": "bad_request"}))


class HostedEntryPointsTest(unittest.TestCase):
    """The per-path functions in proxy/api/ used by the hosted deployment."""

    def test_each_function_serves_its_own_endpoint(self):
        import importlib.util
        import os

        for name in ("stops", "plan", "departures"):
            path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "api", name + ".py")
            spec = importlib.util.spec_from_file_location("hosted_" + name, path)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            self.assertEqual(module.handler.route, "/" + name)


if __name__ == "__main__":
    unittest.main()
