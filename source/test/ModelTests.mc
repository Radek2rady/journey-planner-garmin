import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Test;

// Unit tests; run with `make test-watch` (needs the simulator).

(:test)
function stopSurvivesDictionaryRoundTrip(logger as Logger) as Boolean {
    var stop = Stop.fromDictionary(new Stop("cz-1", "Vestec,u Klimešů", "Vestec").toDictionary() as Dictionary);
    Test.assertEqual(stop.id, "cz-1");
    Test.assertEqual(stop.name, "Vestec,u Klimešů");
    Test.assertEqual(stop.area, "Vestec");
    Test.assert(stop.vehicle == null);

    var station = new Stop("cz-2", "Mnichovice", "Praha-východ");
    station.vehicle = "train";
    Test.assertEqual(Stop.fromDictionary(station.toDictionary() as Dictionary).vehicle as String, "train");
    return true;
}

(:test)
function nearbyStopKeepsItsDistanceOnlyInMemory(logger as Logger) as Boolean {
    var stop = Stop.fromDictionary({ "i" => "cz-1", "n" => "Opatov", "a" => "", "m" => 120 });
    Test.assertEqual(stop.distance as Number, 120);
    Test.assertEqual(Texts.stopDetail(stop) as String, "120 m");
    Test.assert(Stop.fromDictionary(stop.toDictionary() as Dictionary).distance == null);
    Test.assertEqual(Texts.stopDetail(new Stop("cz-1", "Opatov", "Praha")) as String, "Praha");
    Test.assert(Texts.stopDetail(new Stop("cz-1", "Opatov", "")) == null);

    var station = new Stop("cz-2", "Mnichovice", "Praha-východ");
    station.vehicle = "train";
    Test.assertEqual(Texts.stopDetail(station) as String, Texts.vehicle("train") + ", Praha-východ");
    station.area = "";
    Test.assertEqual(Texts.stopDetail(station) as String, Texts.vehicle("train"));
    return true;
}

(:test)
function stopWithoutAreaGetsEmptyArea(logger as Logger) as Boolean {
    var stop = Stop.fromDictionary({ "i" => "cz-1", "n" => "Opatov" });
    Test.assertEqual(stop.area, "");
    return true;
}

(:test)
function connectionsPageIsParsed(logger as Logger) as Boolean {
    var page = ConnectionsPage.fromDictionary({
        "c" => [{
            "d" => "16:16", "a" => "16:57", "m" => 41, "r" => "331 > C",
            "l" => [
                { "k" => "walk", "m" => 3, "t" => "Vestec,u Klimešů" },
                { "k" => "bus", "r" => "331", "f" => "Vestec,u Klimešů", "d" => "16:19", "t" => "Opatov", "a" => "16:33", "p" => "B", "z" => 1 },
                { "k" => "metro", "r" => "C", "f" => "Opatov", "d" => "16:36", "t" => "Hlavní nádraží", "a" => "16:53", "h" => "Letňany", "x" => 1 }
            ]
        }],
        "n" => ""
    });
    Test.assert(page.nextCursor == null);
    Test.assertEqual(page.connections.size(), 1);

    var connection = page.connections[0];
    Test.assertEqual(connection.durationMinutes, 41);
    Test.assertEqual(connection.legs.size(), 3);

    var walk = connection.legs[0];
    Test.assert(walk.isWalk());
    Test.assertEqual(walk.walkMinutes, 3);

    var bus = connection.legs[1];
    Test.assert(!bus.isWalk());
    Test.assertEqual(bus.line, "331");
    Test.assertEqual(bus.platform as String, "B");
    Test.assertEqual(bus.delayMinutes, 1);
    Test.assert(!bus.cancelled);
    Test.assert(bus.headsign == null);

    var metro = connection.legs[2];
    Test.assert(metro.platform == null);
    Test.assertEqual(metro.headsign as String, "Letňany");
    Test.assertEqual(metro.delayMinutes, 0);
    Test.assert(metro.cancelled);
    return true;
}

(:test)
function nonEmptyCursorIsKept(logger as Logger) as Boolean {
    var page = ConnectionsPage.fromDictionary({ "c" => [], "n" => "LATER|1" });
    Test.assertEqual(page.nextCursor as String, "LATER|1");
    return true;
}

(:test)
function recentStopsMoveToFrontWithoutDuplicates(logger as Logger) as Boolean {
    var a = new Stop("a", "A", "");
    var b = new Stop("b", "B", "");
    var c = new Stop("c", "C", "");
    var result = TripStore.withRecent([a, b, c] as Array<Stop>, new Stop("b", "B", ""), 8);
    Test.assertEqual(result.size(), 3);
    Test.assertEqual(result[0].id, "b");
    Test.assertEqual(result[1].id, "a");
    Test.assertEqual(result[2].id, "c");
    return true;
}

(:test)
function recentStopsAreCapped(logger as Logger) as Boolean {
    var a = new Stop("a", "A", "");
    var b = new Stop("b", "B", "");
    var result = TripStore.withRecent([a, b] as Array<Stop>, new Stop("c", "C", ""), 2);
    Test.assertEqual(result.size(), 2);
    Test.assertEqual(result[0].id, "c");
    Test.assertEqual(result[1].id, "a");
    return true;
}

(:test)
function invalidPositionsAreRejected(logger as Logger) as Boolean {
    Test.assert(LocationProvider.isValid(49.98d, 14.50d));
    Test.assert(!LocationProvider.isValid(0.0d, 0.0d));
    Test.assert(!LocationProvider.isValid(180.0d, 180.0d));
    return true;
}

(:test)
function locationIsUsedOnlyAfterConsent(logger as Logger) as Boolean {
    var stored = Storage.getValue("locationAllowed");
    Storage.deleteValue("locationAllowed");
    var location = new LocationProvider();
    Test.assert(!location.allowed);
    Test.assert(location.getCoordinates() == null);
    location.start();
    location.allow();
    Test.assert(location.allowed);
    Test.assert(new LocationProvider().allowed);
    location.stop();
    if (stored != null) {
        Storage.setValue("locationAllowed", stored as Storage.ValueType);
    } else {
        Storage.deleteValue("locationAllowed");
    }
    return true;
}

(:test)
function onlyACurrentFixCountsAsTheWatchPosition(logger as Logger) as Boolean {
    Test.assert(LocationProvider.isFresh(Position.QUALITY_GOOD, 5));
    Test.assert(LocationProvider.isFresh(Position.QUALITY_POOR, null));
    Test.assert(!LocationProvider.isFresh(Position.QUALITY_LAST_KNOWN, 5));
    Test.assert(!LocationProvider.isFresh(Position.QUALITY_NOT_AVAILABLE, null));
    Test.assert(!LocationProvider.isFresh(Position.QUALITY_GOOD, LocationProvider.MAX_AGE_S + 1));
    return true;
}

(:test)
function coordinatesAreFormattedForTheApi(logger as Logger) as Boolean {
    Test.assertEqual(TransitApi.formatCoordinates([49.9806d, 14.505d]), "49.981,14.505");
    Test.assertEqual(TransitApi.formatCoordinates([50.08712d, 14.42041d]), "50.087,14.420");
    return true;
}

(:test)
function connectionsPageSurvivesDictionaryRoundTrip(logger as Logger) as Boolean {
    var original = sampleConnectionsPage();
    var copy = ConnectionsPage.fromDictionary(original.toDictionary());
    Test.assertEqual(copy.nextCursor as String, "LATER|1");

    var connection = copy.connections[0];
    Test.assertEqual(connection.departure, "16:16");
    Test.assertEqual(connection.lines, "331 > C");
    Test.assertEqual(connection.legs.size(), 3);
    Test.assertEqual(connection.legs[0].walkMinutes, 3);

    var bus = connection.legs[1];
    Test.assertEqual(bus.from, "Vestec,u Klimešů");
    Test.assertEqual(bus.arrival, "16:33");
    Test.assertEqual(bus.platform as String, "B");
    Test.assertEqual(bus.headsign as String, "Háje");
    Test.assertEqual(bus.delayMinutes, 1);
    Test.assert(!bus.cancelled);
    return true;
}

//! Bus, a 2 min walk and metro leaving 2 min after the bus arrives: a
//! change with no time to spare.
function sampleTransferConnection() as Connection {
    return Connection.fromDictionary({
        "d" => "16:19", "a" => "16:50", "s" => 1794410340, "m" => 31, "r" => "331 > C",
        "l" => [
            { "k" => "bus", "r" => "331", "f" => "Vestec", "d" => "16:19", "t" => "Opatov", "a" => "16:33", "i" => "cz-1", "s" => 1794410340 },
            { "k" => "walk", "m" => 2, "t" => "Opatov" },
            { "k" => "metro", "r" => "C", "f" => "Opatov", "d" => "16:35", "t" => "Muzeum", "a" => "16:50", "i" => "cz-2", "s" => 1794411300 }
        ]
    });
}

(:test)
function transfersBetweenRidesAreFound(logger as Logger) as Boolean {
    var connection = sampleTransferConnection();
    var transfers = connection.transfers();
    Test.assertEqual(transfers.size(), 1);
    Test.assertEqual(transfers[0].minutes, 2);
    Test.assertEqual(transfers[0].walkMinutes, 2);
    Test.assertEqual(transfers[0].spareMinutes(), 0);
    Test.assert(transfers[0].isTight());
    Test.assertEqual(transfers[0].ride.line, "C");
    Test.assertEqual(transfers[0].ride.fromId as String, "cz-2");
    Test.assertEqual(transfers[0].ride.departureTime, 1794411300);
    Test.assert(connection.hasTightTransfer());
    Test.assert(!new Transfer(8, 2, transfers[0].ride).isTight());

    var restored = Connection.fromDictionary(connection.toDictionary());
    Test.assertEqual(restored.legs[2].fromId as String, "cz-2");
    Test.assertEqual(restored.legs[2].departureTime, 1794411300);
    return true;
}

(:test)
function minutesBetweenClockTimesCrossMidnight(logger as Logger) as Boolean {
    Test.assertEqual(Leg.minutesBetween("16:33", "16:35"), 2);
    Test.assertEqual(Leg.minutesBetween("23:58", "00:03"), 5);
    Test.assertEqual(Leg.minutesBetween("16:33", "16:33"), 0);
    return true;
}

function sampleTrip(originId as String?, destinationId as String) as Trip {
    var origin = originId != null ? new Stop(originId, "Stop " + originId, "") : null;
    return new Trip(origin, new Stop(destinationId, "Stop " + destinationId, "Praha"));
}

(:test)
function tripsAreComparedByStopIds(logger as Logger) as Boolean {
    Test.assert(sampleTrip("a", "b").isSame(sampleTrip("a", "b")));
    Test.assert(!sampleTrip("a", "b").isSame(sampleTrip("a", "c")));
    Test.assert(!sampleTrip("a", "b").isSame(sampleTrip("x", "b")));
    // "Current location" is an origin of its own.
    Test.assert(sampleTrip(null, "b").isSame(sampleTrip(null, "b")));
    Test.assert(!sampleTrip(null, "b").isSame(sampleTrip("a", "b")));
    Test.assert(!sampleTrip("a", "b").isSame(sampleTrip(null, "b")));
    return true;
}

(:test)
function tripSurvivesDictionaryRoundTrip(logger as Logger) as Boolean {
    var withOrigin = Trip.fromDictionary(sampleTrip("a", "b").toDictionary());
    Test.assert(withOrigin.isSame(sampleTrip("a", "b")));
    Test.assertEqual(withOrigin.destination.area, "Praha");

    var fromLocation = Trip.fromDictionary(sampleTrip(null, "b").toDictionary());
    Test.assert(fromLocation.origin == null);
    return true;
}

(:test)
function savedSearchSurvivesDictionaryRoundTrip(logger as Logger) as Boolean {
    var original = new SavedSearch(sampleTrip("a", "b"), 1794500000, sampleConnectionsPage());
    var copy = SavedSearch.fromDictionary(original.toDictionary());
    Test.assert(copy.trip.isSame(original.trip));
    Test.assertEqual(copy.savedAt, 1794500000);
    Test.assertEqual(copy.page.connections.size(), 1);
    Test.assertEqual(copy.page.connections[0].departureTime, 1794410160);
    return true;
}

(:test)
function savedSearchesKeepOnePerTripAndAreCapped(logger as Logger) as Boolean {
    var page = sampleConnectionsPage();
    var list = [] as Array<SavedSearch>;
    list = SavedSearches.withSaved(list, new SavedSearch(sampleTrip("a", "b"), 1, page), 3);
    list = SavedSearches.withSaved(list, new SavedSearch(sampleTrip("a", "c"), 2, page), 3);
    list = SavedSearches.withSaved(list, new SavedSearch(sampleTrip("a", "b"), 3, page), 3);
    Test.assertEqual(list.size(), 2);
    Test.assertEqual(list[0].savedAt, 3);
    Test.assertEqual(list[1].trip.destination.id, "c");

    list = SavedSearches.withSaved(list, new SavedSearch(sampleTrip("d", "e"), 4, page), 3);
    list = SavedSearches.withSaved(list, new SavedSearch(sampleTrip("f", "g"), 5, page), 3);
    Test.assertEqual(list.size(), 3);
    Test.assertEqual(list[2].savedAt, 3);
    return true;
}

(:test)
function favouritesKeepOneCopyAndAreCapped(logger as Logger) as Boolean {
    var list = [] as Array<Trip>;
    list = Favourites.withTrip(list, sampleTrip("a", "b"), 2);
    list = Favourites.withTrip(list, sampleTrip(null, "b"), 2);
    list = Favourites.withTrip(list, sampleTrip("a", "b"), 2);
    Test.assertEqual(list.size(), 2);
    Test.assert(list[0].isSame(sampleTrip("a", "b")));

    list = Favourites.withTrip(list, sampleTrip("x", "y"), 2);
    Test.assertEqual(list.size(), 2);
    Test.assert(list[1].isSame(sampleTrip("a", "b")));
    return true;
}

(:test)
function searchFiltersCycleAndSurviveStorage(logger as Logger) as Boolean {
    var filters = new SearchFilters();
    Test.assert(!filters.isActive());

    filters.cycleTransfers();
    Test.assertEqual(filters.maxTransfers as Number, 0);
    filters.cycleTransfers();
    filters.cycleTransfers();
    Test.assertEqual(filters.maxTransfers as Number, 2);
    filters.cycleTransfers();
    Test.assert(filters.maxTransfers == null);

    filters.cycleVehicles();
    Test.assertEqual(filters.vehicles, SearchFilters.TRAINS_ONLY);
    Test.assert(filters.isActive());
    filters.cycleVehicles();
    Test.assertEqual(filters.vehicles, SearchFilters.NO_TRAINS);

    filters.cycleTransfers();
    var copy = SearchFilters.fromDictionary(filters.toDictionary());
    Test.assertEqual(copy.maxTransfers as Number, 0);
    Test.assertEqual(copy.vehicles, SearchFilters.NO_TRAINS);

    filters.cycleVehicles();
    Test.assertEqual(filters.vehicles, SearchFilters.ALL_VEHICLES);
    Test.assert(SearchFilters.fromDictionary(new SearchFilters().toDictionary()).maxTransfers == null);
    return true;
}
