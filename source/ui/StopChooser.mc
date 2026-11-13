import Toybox.Lang;
import Toybox.WatchUi;

//! Picks the origin or destination: current location (origin only), a stop
//! found by name, or a recently used stop.
module StopChooser {

    enum TripEnd {
        ORIGIN,
        DESTINATION
    }

    //! `onChanged` is called after the trip has been updated.
    function push(end as TripEnd, onChanged as Method() as Void) as Void {
        var menu = new WatchUi.Menu2({ :title => end == ORIGIN ? Rez.Strings.From : Rez.Strings.To });
        if (end == ORIGIN) {
            menu.addItem(new WatchUi.MenuItem(Rez.Strings.MyLocation, Rez.Strings.NearestByGps, :location, null));
        }
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.EnterName, null, :name, null));
        var recent = getServices().trip.recent;
        addStops(menu, recent);
        WatchUi.pushView(menu, new StopChooserDelegate(end, recent, onChanged), WatchUi.SLIDE_LEFT);
    }

    //! Adds one item per stop; the item id is the index into `stops`.
    function addStops(menu as Menu2, stops as Array<Stop>) as Void {
        for (var i = 0; i < stops.size(); i++) {
            var area = stops[i].area;
            menu.addItem(new WatchUi.MenuItem(stops[i].name, area.equals("") ? null : area, i, null));
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
    //! Item that reports the progress of the running name search.
    private var _nameItem as MenuItem?;

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
        } else if (id == :name) {
            _nameItem = item;
            StopNameEntry.push(self);
        } else if (id instanceof Number) {
            choose(_recent[id]);
        }
    }

    //! Called when the name entry is finished. The results are pushed later,
    //! from the response callback.
    function searchByName(name as String) as Void {
        var item = _nameItem;
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
        var item = _nameItem;
        if (item == null) {
            return;
        }
        if (stops == null) {
            item.setSubLabel(error != null ? Texts.error(error) : null);
        } else if (stops.size() == 0) {
            item.setSubLabel(Rez.Strings.NothingFound);
        } else {
            item.setSubLabel(null);
            var menu = new WatchUi.Menu2({ :title => Rez.Strings.Stops });
            StopChooser.addStops(menu, stops);
            WatchUi.pushView(menu, new StopResultsDelegate(_end, stops, _onChanged), WatchUi.SLIDE_LEFT);
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
