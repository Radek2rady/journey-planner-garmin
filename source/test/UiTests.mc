import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;
import Toybox.Time;
import Toybox.WatchUi;

// Smoke tests of the screens: every menu can be built and reacts to a
// selection without crashing. Run with `make test-watch`.

//! Puts back the planned trip a test has replaced, so that the tests leave
//! the stored state of the simulator as they found it.
function restorePlannedTrip(origin as Stop?, destination as Stop?) as Void {
    var trip = getServices().trip;
    trip.origin = origin;
    trip.destination = destination;
    if (destination != null) {
        trip.setTrip(new Trip(origin, destination));
    }
}

function sampleConnectionsPage() as ConnectionsPage {
    return ConnectionsPage.fromDictionary({
        "c" => [{
            "d" => "16:16", "a" => "16:57", "s" => 1794410160, "m" => 41, "r" => "331 > C",
            "l" => [
                { "k" => "walk", "m" => 3, "t" => "Vestec,u Klimešů" },
                { "k" => "bus", "r" => "331", "f" => "Vestec,u Klimešů", "d" => "16:19", "t" => "Opatov", "a" => "16:33", "h" => "Háje", "p" => "B", "z" => 1 },
                { "k" => "walk", "m" => 4, "t" => "" }
            ]
        }],
        "n" => "LATER|1"
    });
}

(:test)
function textsDescribeALeg(logger as Logger) as Boolean {
    var connection = sampleConnectionsPage().connections[0];
    Test.assertEqual(Texts.connectionTimes(connection), "16:16 - 16:57");

    Test.assertEqual(Texts.shortLine("S21 (Os 15648)"), "S21");
    Test.assertEqual(Texts.shortLine("Os 20872"), "Os");
    Test.assertEqual(Texts.shortLine("331"), "331");

    Test.assertEqual(Texts.joinLines(["331", "C"] as Array<String>, 12), "331>C");
    Test.assertEqual(Texts.joinLines(["674", "538", "S21", "S2"] as Array<String>, 14), "674>538>S21>S2");
    Test.assertEqual(Texts.joinLines(["674", "538", "S21", "S2"] as Array<String>, 12), "674>538 +2");
    Test.assertEqual(Texts.joinLines(["Os", "R", "S2"] as Array<String>, 4), "Os +2");
    Test.assertEqual(Texts.joinLines(["LongLineName"] as Array<String>, 3), "LongLineName");
    Test.assertEqual(Texts.joinLines([] as Array<String>, 5), "");
    logger.debug(Texts.duration(41) + " / " + Texts.duration(188) + " / " + Texts.duration(60));
    // The sample connection leaves at 1794410160.
    Test.assertEqual(Texts.connectionSummary(connection, 1794410160 - 3 * 3600), "41 min, 331");
    Test.assert(Texts.countdown(1794410160, 1794410160 - 120 * 60) == null);
    Test.assert(Texts.countdown(0, 1794410160) == null);
    logger.debug(Texts.connectionSummary(connection, 1794410160 - 7 * 60 - 30));
    logger.debug(Texts.connectionSummary(connection, 1794410160 - 59));
    logger.debug(Texts.connectionSummary(connection, 1794410160 + 1));
    logger.debug(Texts.countdown(1794410160, 1794410160 - 90 * 60) as String);
    logger.debug(Texts.walk(connection.legs[0]));
    logger.debug(Texts.boardingDetails(connection.legs[1]));
    logger.debug(Texts.placeOrDestination(connection.legs[2].to));
    logger.debug(Texts.error(new ApiError(502, "upstream")));
    logger.debug(Texts.error(new ApiError(-104, null)));
    logger.debug(Texts.vehicle("train") + " " + Texts.vehicle("unknown"));
    return true;
}

(:test)
function glanceDrawsWithoutTheServices(logger as Logger) as Boolean {
    var bitmap = Graphics.createBufferedBitmap({ :width => 180, :height => 60 }).get() as BufferedBitmap;
    var glance = new TransitGlance();
    glance.onUpdate(bitmap.getDc());
    var views = getApp().getGlanceView();
    return views != null && views[0] instanceof TransitGlance;
}

(:test)
function mainMenuOpensAndHandlesItems(logger as Logger) as Boolean {
    MainMenu.push();
    var item = new WatchUi.MenuItem("x", null, :swap, null);
    var delegate = new MainMenuDelegate(item, item, item, item, item);
    delegate.refresh();
    delegate.onSelect(item);
    delegate.onSelect(new WatchUi.MenuItem("x", null, :search, null));
    delegate.onConnections(null, new ApiError(-104, null));
    delegate.onConnections(sampleConnectionsPage(), null);
    return true;
}

(:test)
function stopChooserOpensAndHandlesItems(logger as Logger) as Boolean {
    var item = new WatchUi.MenuItem("x", null, :name, null);
    var main = new MainMenuDelegate(item, item, item, item, item);
    StopChooser.push(StopChooser.ORIGIN, main.method(:refresh));
    StopChooser.push(StopChooser.DESTINATION, main.method(:refresh));

    var stops = [new Stop("cz-1", "Opatov", "Praha")] as Array<Stop>;
    var chooser = new StopChooserDelegate(StopChooser.DESTINATION, stops, main.method(:refresh));
    chooser.onSelect(item);
    chooser.searchByName("v");
    chooser.onStops(null, new ApiError(502, "upstream"));
    chooser.onStops([] as Array<Stop>, null);
    chooser.onStops(stops, null);
    chooser.onSelect(new WatchUi.MenuItem("x", null, 0, null));

    var results = new StopResultsDelegate(StopChooser.ORIGIN, stops, main.method(:refresh));
    results.onSelect(new WatchUi.MenuItem("x", null, 0, null));
    return true;
}

(:test)
function connectionListAndDetailOpen(logger as Logger) as Boolean {
    var page = sampleConnectionsPage();
    ConnectionList.push(page, null, null);
    var plannedOrigin = getServices().trip.origin;
    var plannedDestination = getServices().trip.destination;
    var listItem = new WatchUi.MenuItem("x", null, 0, null);
    var delegate = new ConnectionListDelegate(page, [listItem] as Array<MenuItem>, "b", sampleTrip("a", "b"), null);
    delegate.refreshCountdowns(1794410160 - 600);
    CountdownTicker.onTick();
    delegate.onSelect(new WatchUi.MenuItem("x", null, :again, null));
    Test.assert((getServices().trip.currentTrip() as Trip).isSame(sampleTrip("a", "b")));
    delegate.onSelect(new WatchUi.MenuItem("x", null, 0, null));
    delegate.onSelect(new WatchUi.MenuItem("x", null, :later, null));
    delegate.onConnections(null, new ApiError(502, null));

    restorePlannedTrip(plannedOrigin, plannedDestination);

    ConnectionDetail.push(page.connections[0], null);
    new ConnectionDetailDelegate(["16:19 Vestec\nBus 331"] as Array<String>, null).onSelect(new WatchUi.MenuItem("x", null, 0, null));
    return true;
}

(:test)
function tightChangeIsMarkedAndSearchedFrom(logger as Logger) as Boolean {
    var connection = sampleTransferConnection();
    var transfer = connection.transfers()[0];
    Test.assertEqual(Texts.transfer(transfer), "! " + Texts.get(Rez.Strings.Change) + " 2 " + Texts.get(Rez.Strings.Minutes));
    Test.assertEqual(Texts.connectionSummary(connection, 1794410340 + 60).substring(0, 1) as String, "!");
    logger.debug(Texts.connectionSummary(connection, 1794410340 - 600));

    ConnectionDetail.push(connection, "cz-9");
    var delegate = new ConnectionDetailDelegate([] as Array<String>, "cz-9");
    var item = new WatchUi.MenuItem("x", null, transfer, null);
    delegate.onSelect(item);
    delegate.onConnections(null, new ApiError(502, null));
    delegate.onConnections(new ConnectionsPage([] as Array<Connection>, null), null);
    delegate.onConnections(sampleConnectionsPage(), null);
    return true;
}

(:test)
function nameInputTypesErasesAndFinishes(logger as Logger) as Boolean {
    var input = new NameInput();
    Test.assertEqual(NameInput.letter(input.key) as String, "A");
    Test.assert(!input.erase());

    Test.assert(!input.press());
    input.move(1);
    Test.assert(!input.press());
    Test.assertEqual(input.text, "AB");

    // The keys wrap around in both directions.
    Test.assertEqual(input.keyAt(-2), NameInput.DONE);
    Test.assertEqual(input.keyAt(NameInput.keyCount()), input.key);

    Test.assert(input.erase());
    Test.assert(input.erase());
    Test.assertEqual(input.text, "");

    input.key = NameInput.keyCount() - 1;
    for (var i = 0; i < NameInput.MAX_LENGTH + 3; i++) {
        input.press();
    }
    Test.assertEqual(input.text.length(), NameInput.MAX_LENGTH);

    input.move(1);
    Test.assert(input.press());
    return true;
}

(:test)
function stopNameEntryOpensAndHandlesKeys(logger as Logger) as Boolean {
    var item = new WatchUi.MenuItem("x", null, :name, null);
    var main = new MainMenuDelegate(item, item, item, item, item);
    var chooser = new StopChooserDelegate(StopChooser.DESTINATION, [] as Array<Stop>, main.method(:refresh));
    chooser.onSelect(item);

    var input = new NameInput();
    var delegate = new StopNameDelegate(input, chooser);
    delegate.onNextPage();
    delegate.onPreviousPage();
    delegate.onSelect();
    Test.assertEqual(input.text, "A");
    Test.assert(delegate.onBack());
    Test.assert(!delegate.onBack());
    input.move(-1);
    delegate.onSelect();
    return true;
}

(:test)
function holdingAButtonRepeatsWithoutAnExtraStep(logger as Logger) as Boolean {
    var item = new WatchUi.MenuItem("x", null, :name, null);
    var main = new MainMenuDelegate(item, item, item, item, item);
    var chooser = new StopChooserDelegate(StopChooser.DESTINATION, [] as Array<Stop>, main.method(:refresh));
    var input = new NameInput();
    var delegate = new StopNameDelegate(input, chooser);
    var start = input.key;

    // A short press: only the page behavior moves.
    delegate.startHold(1);
    delegate.onNextPage();
    delegate.endHold();
    Test.assertEqual(input.key, start + 1);

    // A hold: every timer tick moves; the behavior that follows is skipped,
    // whether it arrives before or after the release.
    delegate.startHold(1);
    delegate.onRepeat();
    delegate.onRepeat();
    delegate.onNextPage();
    delegate.endHold();
    delegate.onNextPage();
    Test.assertEqual(input.key, start + 3);

    // The step after that counts again.
    delegate.onPreviousPage();
    Test.assertEqual(input.key, start + 2);

    // A hold stops by itself after one round through the keys.
    var before = input.key;
    delegate.startHold(-1);
    for (var i = 0; i < NameInput.keyCount() + 5; i++) {
        delegate.onRepeat();
    }
    Test.assertEqual(input.key, before);
    delegate.endHold();

    // A tick after the release does nothing.
    delegate.onRepeat();
    Test.assertEqual(input.key, start + 2);
    return true;
}

(:test)
function savedListOpensAndShowsASearch(logger as Logger) as Boolean {
    var search = new SavedSearch(sampleTrip("a", "b"), 1794500000, sampleConnectionsPage());
    Test.assertEqual(Texts.tripName(search.trip), "Stop a > Stop b");
    logger.debug(Texts.tripName(sampleTrip(null, "b")));
    logger.debug(Texts.savedAt(search));

    var item = new WatchUi.MenuItem("x", null, :saved, null);
    new MainMenuDelegate(item, item, item, item, item).onSelect(item);
    var main = new MainMenuDelegate(item, item, item, item, item);
    SavedList.push(main.method(:refresh));
    new SavedListDelegate([search] as Array<SavedSearch>, main.method(:refresh)).onSelect(new WatchUi.MenuItem("x", null, 0, null));
    return true;
}

(:test)
function departureMenuSetsAndClearsTheTime(logger as Logger) as Boolean {
    // 12:34:56 past some hour, two hours ahead.
    Test.assertEqual(DepartureMenu.hourStart(100000, 34, 56, 2), 100000 - 34 * 60 - 56 + 7200);

    var item = new WatchUi.MenuItem("x", null, :when, null);
    var main = new MainMenuDelegate(item, item, item, item, item);
    main.onSelect(item);
    DepartureMenu.pushMinutes(1794510000, main.method(:refresh), 2);

    // Midnight belongs to the new day; a moment before it to the old one.
    Test.assertEqual(DepartureMenu.dayOffset(1000, 1000), 0);
    Test.assertEqual(DepartureMenu.dayOffset(1000 + 86399, 1000), 0);
    Test.assertEqual(DepartureMenu.dayOffset(1000 + 86400, 1000), 1);
    Test.assertEqual(DepartureMenu.dayOffset(1000 + 5 * 86400 + 3600, 1000), 5);
    Test.assertEqual(DepartureMenu.dayOffset(999, 1000), -1);

    var trip = getServices().trip;
    new DepartureMinutesDelegate(main.method(:refresh), 2).onSelect(new WatchUi.MenuItem("x", null, 1794510900, null));
    Test.assertEqual(trip.departureTime as Number, 1794510900);
    logger.debug(Texts.departure(trip.departureTime));

    var hours = new DepartureMenuDelegate(main.method(:refresh));
    hours.onSelect(new WatchUi.MenuItem("x", null, 1794510000, null));
    hours.onSelect(new WatchUi.MenuItem("x", null, :now, null));

    // Another day: days, then the hours of the chosen day, then the minutes.
    var inAWeek = Time.today().value() + 7 * 86400;
    hours.onSelect(new WatchUi.MenuItem("x", null, :day, null));
    new DepartureDaysDelegate(main.method(:refresh)).onSelect(new WatchUi.MenuItem("x", null, inAWeek, null));
    new DepartureHoursDelegate(main.method(:refresh), 4).onSelect(new WatchUi.MenuItem("x", null, inAWeek + 17 * 3600, null));
    logger.debug(Texts.departure(inAWeek + 17 * 3600 + 1800));
    logger.debug(Texts.day(Time.today().value() + 86400 + 60));
    Test.assert(trip.departureTime == null);
    logger.debug(Texts.departure(null));
    return true;
}

(:test)
function favouriteListAddsChoosesAndRemoves(logger as Logger) as Boolean {
    var app = getServices();
    var item = new WatchUi.MenuItem("x", null, :favourites, null);
    var main = new MainMenuDelegate(item, item, item, item, item);
    main.onSelect(item);

    var plannedOrigin = app.trip.origin;
    var plannedDestination = app.trip.destination;
    app.trip.setTrip(sampleTrip("a", "b"));
    var list = new FavouriteListDelegate(main.method(:searchChosenTrip));
    list.onSelect(new WatchUi.MenuItem("x", null, :add, null));
    Test.assert(app.favourites.trips[0].isSame(sampleTrip("a", "b")));

    app.trip.setTrip(sampleTrip(null, "c"));
    list.onSelect(new WatchUi.MenuItem("x", null, 0, null));
    Test.assert((app.trip.currentTrip() as Trip).isSame(sampleTrip("a", "b")));

    var count = app.favourites.trips.size();
    list.onSelect(new WatchUi.MenuItem("x", null, :remove, null));
    new FavouriteRemovalDelegate(main.method(:searchChosenTrip)).onSelect(new WatchUi.MenuItem("x", null, 0, null));
    Test.assertEqual(app.favourites.trips.size(), count - 1);
    restorePlannedTrip(plannedOrigin, plannedDestination);
    return true;
}

(:test)
function filterMenuCyclesThroughTheChoices(logger as Logger) as Boolean {
    var trip = getServices().trip;
    var before = trip.filters;
    trip.filters = new SearchFilters();

    var item = new WatchUi.MenuItem("x", null, :filters, null);
    var main = new MainMenuDelegate(item, item, item, item, item);
    main.onSelect(item);
    var menu = new FilterMenuDelegate(main.method(:refresh));
    logger.debug(Texts.filters(trip.filters));

    menu.onSelect(new WatchUi.MenuItem("x", null, :transfers, null));
    Test.assertEqual(trip.filters.maxTransfers as Number, 0);
    menu.onSelect(new WatchUi.MenuItem("x", null, :vehicles, null));
    Test.assertEqual(trip.filters.vehicles, SearchFilters.TRAINS_ONLY);
    logger.debug(Texts.filters(trip.filters));
    menu.onSelect(new WatchUi.MenuItem("x", null, :transfers, null));
    logger.debug(Texts.transfersFilter(trip.filters) + " / " + Texts.vehiclesFilter(trip.filters));

    trip.filters = before;
    trip.saveFilters();
    return true;
}

function sampleBoard() as DepartureBoard {
    return DepartureBoard.fromDictionary({
        "n" => "Vestec,BIOCEV",
        "i" => "cz-PID_U4178Z1",
        "c" => "LATER|1794559020",
        "d" => [
            { "k" => "bus", "r" => "326", "h" => "Jesenice,Belnická", "d" => "16:19", "s" => 1794410340, "p" => "A", "z" => 1 },
            { "k" => "train", "r" => "S21", "h" => "", "d" => "19:40", "s" => 1794422400, "x" => 1 }
        ]
    });
}

(:test)
function departureBoardIsParsedAndDescribed(logger as Logger) as Boolean {
    var board = sampleBoard();
    Test.assertEqual(board.stopName, "Vestec,BIOCEV");
    Test.assertEqual(board.stopId, "cz-PID_U4178Z1");
    Test.assertEqual(board.nextCursor as String, "LATER|1794559020");
    Test.assertEqual(board.departures.size(), 2);

    var bus = board.departures[0];
    Test.assertEqual(bus.platform as String, "A");
    Test.assertEqual(bus.delayMinutes, 1);
    Test.assert(!bus.cancelled);
    Test.assertEqual(Texts.boardDirection(bus), "Jesenice,Belnická");
    // More than two hours ahead: the time instead of a countdown.
    Test.assertEqual(Texts.boardLine(bus, 1794410340 - 3 * 3600), "326 16:19");
    logger.debug(Texts.boardLine(bus, 1794410340 - 4 * 60));
    logger.debug(Texts.departureDetails(bus));

    var train = board.departures[1];
    Test.assert(train.cancelled);
    Test.assert(train.platform == null);
    logger.debug(Texts.boardDirection(train));
    logger.debug(Texts.departureDetails(train));
    return true;
}

(:test)
function departureBoardOpensFromTheChooser(logger as Logger) as Boolean {
    var item = new WatchUi.MenuItem("x", null, :board, null);
    new MainMenuDelegate(item, item, item, item, item).onSelect(item);

    var stops = [new Stop("cz-1", "Opatov", "Praha")] as Array<Stop>;
    var chooser = new BoardChooserDelegate(stops);
    chooser.onSelect(new WatchUi.MenuItem("x", null, :nearest, null));
    chooser.onSelect(new WatchUi.MenuItem("x", null, 0, null));
    chooser.onBoard(null, new ApiError(502, "upstream"));
    chooser.onBoard(new DepartureBoard("", "", [] as Array<Departure>, null), null);
    chooser.onBoard(sampleBoard(), null);

    var board = sampleBoard();
    var line = new WatchUi.MenuItem("x", null, 0, null);
    var delegate = new DepartureBoardDelegate(board, [line, line] as Array<MenuItem>);
    delegate.refreshCountdowns(1794410340 - 600);
    delegate.onSelect(line);

    // Later departures: progress and errors on the item, results as a new board.
    delegate.onSelect(new WatchUi.MenuItem("x", null, :later, null));
    delegate.onBoard(null, new ApiError(-104, null));
    delegate.onBoard(sampleBoard(), null);
    return true;
}

class ApiProbe {
    var board as DepartureBoard?;

    function onBoard(board as DepartureBoard?, error as ApiError?) as Void {
        self.board = board;
        self.error = error;
    }

    var stops as Array<Stop>?;
    var page as ConnectionsPage?;
    var error as ApiError?;

    function initialize() {
    }

    function onStops(stops as Array<Stop>?, error as ApiError?) as Void {
        self.stops = stops;
        self.error = error;
    }

    function onConnections(page as ConnectionsPage?, error as ApiError?) as Void {
        self.page = page;
        self.error = error;
    }
}

(:test)
function apiDeliversStopsAndErrors(logger as Logger) as Boolean {
    var api = new TransitApi();
    var probe = new ApiProbe();

    api.searchStops("vestec", [49.9806d, 14.505d], probe.method(:onStops));
    api.onStopsResponse(200, { "s" => [{ "n" => "Opatov", "i" => "cz-1", "a" => "Praha" }] });
    Test.assertEqual((probe.stops as Array<Stop>).size(), 1);

    api.searchStops("vestec", null, probe.method(:onStops));
    api.onStopsResponse(502, { "e" => "upstream" });
    Test.assert(probe.stops == null);
    Test.assertEqual((probe.error as ApiError).serverCode as String, "upstream");

    // A response nobody waits for is ignored.
    api.onStopsResponse(-104, null);
    return true;
}

(:test)
function apiDeliversConnectionsAndErrors(logger as Logger) as Boolean {
    var api = new TransitApi();
    var probe = new ApiProbe();

    api.searchConnections("49.98060,14.50500", "cz-1", 1794510000, new SearchFilters(), null, probe.method(:onConnections));
    api.onConnectionsResponse(200, { "c" => [], "n" => "" });
    Test.assertEqual((probe.page as ConnectionsPage).connections.size(), 0);

    api.searchConnections("cz-2", "cz-1", null, SearchFilters.fromDictionary({ "x" => 0, "v" => "train" }), "LATER|1", probe.method(:onConnections));
    api.onConnectionsResponse(-104, null);
    Test.assert(probe.page == null);
    Test.assertEqual((probe.error as ApiError).code, -104);
    return true;
}

(:test)
function apiDeliversDeparturesAndErrors(logger as Logger) as Boolean {
    var api = new TransitApi();
    var probe = new ApiProbe();

    api.searchDepartures("cz-1", null, "LATER|1", probe.method(:onBoard));
    api.onDeparturesResponse(200, { "n" => "Opatov", "i" => "cz-1", "d" => [], "c" => "" });
    Test.assertEqual((probe.board as DepartureBoard).stopName, "Opatov");
    Test.assert((probe.board as DepartureBoard).nextCursor == null);

    api.searchDepartures(null, [49.9806d, 14.505d], null, probe.method(:onBoard));
    api.onDeparturesResponse(400, { "e" => "bad_request" });
    Test.assert(probe.board == null);
    Test.assertEqual((probe.error as ApiError).serverCode as String, "bad_request");
    return true;
}

//! Must stay the last test (tests run in file order). The tests above leave
//! web requests, location events and the countdown timer running; the
//! simulator crashed when the test run ended with them still active.
(:test)
function testRunLeavesNothingRunning(logger as Logger) as Boolean {
    Communications.cancelAllRequests();
    getServices().location.stop();
    var lists = CountdownTicker.open.slice(0, null);
    for (var i = 0; i < lists.size(); i++) {
        CountdownTicker.closed(lists[i]);
    }
    return CountdownTicker.ticker == null;
}
