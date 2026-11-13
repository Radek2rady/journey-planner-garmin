import Toybox.Lang;
import Toybox.WatchUi;

//! Picks the origin or destination: current location and the stops around it
//! (origin only), a stop found by name, or a recently used stop. The last item
//! leads to deleting recent stops.
module StopChooser {

    enum TripEnd {
        ORIGIN,
        DESTINATION
    }

    //! `onChanged` is called after the trip has been updated.
    function push(end as TripEnd, onChanged as Method() as Void) as Void {
        WatchUi.pushView(menu(end), new StopChooserDelegate(end, getServices().trip.recent, onChanged), WatchUi.SLIDE_LEFT);
    }

    function menu(end as TripEnd) as Menu2 {
        var result = new WatchUi.Menu2({ :title => end == ORIGIN ? Rez.Strings.From : Rez.Strings.To });
        if (end == ORIGIN) {
            result.addItem(new WatchUi.MenuItem(Rez.Strings.MyLocation, Rez.Strings.NearestByGps, :location, null));
            result.addItem(new WatchUi.MenuItem(Rez.Strings.NearbyStops, Rez.Strings.NearbyHint, :nearby, null));
        }
        result.addItem(new WatchUi.MenuItem(Rez.Strings.EnterName, null, :name, null));
        var recent = getServices().trip.recent;
        addStops(result, recent);
        if (recent.size() > 0) {
            result.addItem(new WatchUi.MenuItem(Rez.Strings.DeleteRecent, null, :delete, null));
        }
        return result;
    }

    //! The recent stops to delete one by one, after an item that deletes all.
    function deletionMenu() as Menu2 {
        var result = new WatchUi.Menu2({ :title => Rez.Strings.DeleteRecent });
        result.addItem(new WatchUi.MenuItem(Rez.Strings.DeleteAll, null, :all, null));
        addStops(result, getServices().trip.recent);
        return result;
    }

    //! Adds one item per stop; the item id is the index into `stops`. The
    //! sub-label is the distance of a nearby stop, otherwise its area.
    function addStops(menu as Menu2, stops as Array<Stop>) as Void {
        for (var i = 0; i < stops.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(stops[i].name, Texts.stopDetail(stops[i]), i, null));
        }
    }

    function apply(end as TripEnd, stop as Stop?) as Void {
        var trip = getServices().trip;
        if (end == ORIGIN) {
            trip.setOrigin(stop);
        } else {
            trip.setDestination(stop);
        }
    }
}

class StopChooserDelegate extends WatchUi.Menu2InputDelegate {

    private var _end as StopChooser.TripEnd;
    private var _recent as Array<Stop>;
    private var _onChanged as Method() as Void;
    //! Item that reports the progress of the running stop search.
    private var _progressItem as MenuItem?;

    function initialize(end as StopChooser.TripEnd, recent as Array<Stop>, onChanged as Method() as Void) {
        Menu2InputDelegate.initialize();
        _end = end;
        _recent = recent;
        _onChanged = onChanged;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id == :location) {
            choose(null);
        } else if (id == :nearby) {
            searchNearby(item);
        } else if (id == :name) {
            _progressItem = item;
            StopNameEntry.push(self);
        } else if (id == :delete) {
            WatchUi.switchToView(StopChooser.deletionMenu(), new RecentDeletionDelegate(_end, _onChanged), WatchUi.SLIDE_LEFT);
        } else if (id instanceof Number) {
            choose(_recent[id]);
        }
    }

    //! Called when the name entry is finished. The results are pushed later,
    //! from the response callback.
    function searchByName(name as String) as Void {
        var item = _progressItem;
        if (item == null) {
            return;
        }
        if (name.length() < Config.MIN_QUERY_LENGTH) {
            item.setSubLabel(Rez.Strings.MinTwoLetters);
            return;
        }
        item.setSubLabel(Texts.get(Rez.Strings.Searching) + " " + name);
        var app = getServices();
        app.api.searchStops(name, app.location.getCoordinates(), method(:onStops));
    }

    function onStops(stops as Array<Stop>?, error as ApiError?) as Void {
        var item = _progressItem;
        if (item == null) {
            return;
        }
        if (stops == null) {
            item.setSubLabel(error != null ? Texts.error(error) : null);
        } else if (stops.size() == 0) {
            item.setSubLabel(Rez.Strings.NothingFound);
        } else {
            item.setSubLabel(item.getId() == :nearby ? Rez.Strings.NearbyHint : null);
            var menu = new WatchUi.Menu2({ :title => Rez.Strings.Stops });
            StopChooser.addStops(menu, stops);
            WatchUi.pushView(menu, new StopResultsDelegate(_end, stops, _onChanged), WatchUi.SLIDE_LEFT);
        }
        WatchUi.requestUpdate();
    }

    private function searchNearby(item as MenuItem) as Void {
        var app = getServices();
        var coordinates = app.location.getCoordinates();
        if (coordinates == null) {
            item.setSubLabel(Rez.Strings.WaitingForGps);
        } else {
            _progressItem = item;
            item.setSubLabel(Rez.Strings.Searching);
            app.api.searchNearbyStops(coordinates, method(:onStops));
        }
        WatchUi.requestUpdate();
    }

    private function choose(stop as Stop?) as Void {
        StopChooser.apply(_end, stop);
        _onChanged.invoke();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class StopResultsDelegate extends WatchUi.Menu2InputDelegate {

    private var _end as StopChooser.TripEnd;
    private var _stops as Array<Stop>;
    private var _onChanged as Method() as Void;

    function initialize(end as StopChooser.TripEnd, stops as Array<Stop>, onChanged as Method() as Void) {
        Menu2InputDelegate.initialize();
        _end = end;
        _stops = stops;
        _onChanged = onChanged;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number) {
            StopChooser.apply(_end, _stops[id]);
            _onChanged.invoke();
            // Close the results and the chooser below them.
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
    }
}

//! Deletes the chosen recent stop, or all of them, and returns to the
//! chooser. The planned origin and destination stay as they are.
class RecentDeletionDelegate extends WatchUi.Menu2InputDelegate {

    private var _end as StopChooser.TripEnd;
    private var _onChanged as Method() as Void;

    function initialize(end as StopChooser.TripEnd, onChanged as Method() as Void) {
        Menu2InputDelegate.initialize();
        _end = end;
        _onChanged = onChanged;
    }

    function onSelect(item as MenuItem) as Void {
        var trip = getServices().trip;
        var id = item.getId();
        if (id == :all) {
            trip.clearRecent();
        } else if (id instanceof Number) {
            trip.forgetRecent(id);
        } else {
            return;
        }
        backToChooser();
    }

    //! BACK returns to the chooser rather than to the main menu.
    function onBack() as Void {
        backToChooser();
    }

    private function backToChooser() as Void {
        WatchUi.switchToView(StopChooser.menu(_end), new StopChooserDelegate(_end, getServices().trip.recent, _onChanged), WatchUi.SLIDE_RIGHT);
    }
}
