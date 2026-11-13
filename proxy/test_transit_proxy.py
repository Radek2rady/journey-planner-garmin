"""Unit tests for the proxy. Run: python3 -m unittest discover -s proxy"""

import unittest
import urllib.error
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
        self.assertEqual(proxy.stop_area(areas), "Vestec, okres Praha-západ")

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

    def test_czech_feeds_first_and_duplicates_removed(self):
        result, _ = self.search(
            [
                geocode_item("Brno hl.n.", "at-1"),
                geocode_item("Brno hlavní nádraží", "cz-1", [(8, "Brno")]),
                geocode_item("Brno hlavní nádraží", "cz-2", [(8, "Brno")]),
                {"type": "ADDRESS", "name": "Brno", "id": "x"},
            ]
        )
        self.assertEqual([stop["i"] for stop in result["s"]], ["cz-1", "at-1"])
        self.assertEqual(result["s"][0], {"n": "Brno hlavní nádraží", "i": "cz-1", "a": "Brno"})

    def test_result_is_capped(self):
        items = [geocode_item("Stop %d" % i, "cz-%d" % i) for i in range(30)]
        result, _ = self.search(items)
        self.assertEqual(len(result["s"]), proxy.MAX_STOPS)

    def test_position_biases_the_search(self):
        _, call = self.search([], "49.98", "14.50")
        self.assertEqual(call.call_args[0][1]["place"], "49.98,14.50")


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
