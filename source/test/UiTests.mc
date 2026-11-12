import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// Smoke tests of the screens: every menu can be built and reacts to a
// selection without crashing. Run with `make test-watch`.

function sampleConnectionsPage() as ConnectionsPage {
    return ConnectionsPage.fromDictionary({
        "c" => [{
            "d" => "16:16", "a" => "16:57", "m" => 41, "r" => "331 > C",
            "l" => [
                { "k" => "walk", "m" => 3, "t" => "Vestec,u Klimešů" },
                { "k" => "bus", "r" => "331", "f" => "Vestec,u Klimešů", "d" => "16:19", "t" => "Opatov", "a" => "16:33", "p" => "B", "z" => 1 },
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
    logger.debug(Texts.connectionSummary(connection));
    logger.debug(Texts.walk(connection.legs[0]));
    logger.debug(Texts.boardingDetails(connection.legs[1]));
    logger.debug(Texts.placeOrDestination(connection.legs[2].to));
    logger.debug(Texts.error(new ApiError(502, "upstream")));
    logger.debug(Texts.error(new ApiError(-104, null)));
    logger.debug(Texts.vehicle("train") + " " + Texts.vehicle("unknown"));
    return true;
}

(:test)
function mainMenuOpensAndHandlesItems(logger as Logger) as Boolean {
    MainMenu.push();
    var item = new WatchUi.MenuItem("x", null, :swap, null);
    var delegate = new MainMenuDelegate(item, item);
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
    var main = new MainMenuDelegate(item, item);
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
    ConnectionList.push(page);
    var delegate = new ConnectionListDelegate(page);
    delegate.onSelect(new WatchUi.MenuItem("x", null, 0, null));
    delegate.onSelect(new WatchUi.MenuItem("x", null, :later, null));
    delegate.onConnections(null, new ApiError(502, null));
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
    var main = new MainMenuDelegate(item, item);
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
    var main = new MainMenuDelegate(item, item);
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

    // A tick after the release does nothing.
    delegate.onRepeat();
    Test.assertEqual(input.key, start + 2);
    return true;
}

class ApiProbe {
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

    api.searchConnections("49.98060,14.50500", "cz-1", null, probe.method(:onConnections));
    api.onConnectionsResponse(200, { "c" => [], "n" => "" });
    Test.assertEqual((probe.page as ConnectionsPage).connections.size(), 0);

    api.searchConnections("cz-2", "cz-1", "LATER|1", probe.method(:onConnections));
    api.onConnectionsResponse(-104, null);
    Test.assert(probe.page == null);
    Test.assertEqual((probe.error as ApiError).code, -104);
    return true;
}
