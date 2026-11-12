import Toybox.Lang;
import Toybox.Test;

// Unit tests; run with `make test-watch` (needs the simulator).

(:test)
function stopSurvivesDictionaryRoundTrip(logger as Logger) as Boolean {
    var stop = Stop.fromDictionary(new Stop("cz-1", "Vestec,u Klimešů", "Vestec").toDictionary() as Dictionary);
    Test.assertEqual(stop.id, "cz-1");
    Test.assertEqual(stop.name, "Vestec,u Klimešů");
    Test.assertEqual(stop.area, "Vestec");
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
function coordinatesAreFormattedForTheApi(logger as Logger) as Boolean {
    Test.assertEqual(TransitApi.formatCoordinates([49.9806d, 14.505d]), "49.98060,14.50500");
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

(:test)
function savedSearchSurvivesDictionaryRoundTrip(logger as Logger) as Boolean {
    var original = new SavedSearch("Vestec", "Opatov", 1794500000, sampleConnectionsPage());
    var copy = SavedSearch.fromDictionary(original.toDictionary());
    Test.assert(copy.isSameTrip(original));
    Test.assertEqual(copy.savedAt, 1794500000);
    Test.assertEqual(copy.page.connections.size(), 1);
    return true;
}

(:test)
function savedSearchesKeepOnePerTripAndAreCapped(logger as Logger) as Boolean {
    var page = sampleConnectionsPage();
    var list = [] as Array<SavedSearch>;
    list = SavedSearches.withSaved(list, new SavedSearch("A", "B", 1, page), 3);
    list = SavedSearches.withSaved(list, new SavedSearch("A", "C", 2, page), 3);
    list = SavedSearches.withSaved(list, new SavedSearch("A", "B", 3, page), 3);
    Test.assertEqual(list.size(), 2);
    Test.assertEqual(list[0].savedAt, 3);
    Test.assertEqual(list[1].destination, "C");

    list = SavedSearches.withSaved(list, new SavedSearch("D", "E", 4, page), 3);
    list = SavedSearches.withSaved(list, new SavedSearch("F", "G", 5, page), 3);
    Test.assertEqual(list.size(), 3);
    Test.assertEqual(list[2].savedAt, 3);
    return true;
}
