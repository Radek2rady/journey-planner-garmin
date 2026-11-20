import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

//! Main menu: search, favourite trips, origin, destination, departure time,
//! filters, swap, saved connections, departure board, search over Wi-Fi, about.
module MainMenu {

    function push() as Void {
        var app = getServices();
        var originItem = new WatchUi.MenuItem(Rez.Strings.From, Texts.originName(app.trip, app.location), :origin, null);
        var destinationItem = new WatchUi.MenuItem(Rez.Strings.To, Texts.destinationName(app.trip), :destination, null);
        var departureItem = new WatchUi.MenuItem(Texts.timeKind(app.trip), Texts.departure(app.trip.departureTime), :when, null);
        var filtersItem = new WatchUi.MenuItem(Rez.Strings.Filters, Texts.filters(app.trip.filters), :filters, null);

        var menu = new WatchUi.Menu2({ :title => Rez.Strings.Connections });
        var searchItem = new WatchUi.MenuItem(Rez.Strings.FindConnections, null, :search, null);
        menu.addItem(searchItem);
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Favourites, null, :favourites, null));
        menu.addItem(originItem);
        menu.addItem(destinationItem);
        menu.addItem(departureItem);
        menu.addItem(filtersItem);
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Swap, Rez.Strings.SwapHint, :swap, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Saved, Rez.Strings.SavedHint, :saved, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Board, Rez.Strings.BoardHint, :board, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.WifiSearch, Texts.wifiState(WifiSearch.result()), :wifi, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.About, Texts.version(BuildConfig.APP_VERSION), :about, null));
        WatchUi.pushView(menu, new MainMenuDelegate(searchItem, originItem, destinationItem, departureItem, filtersItem), WatchUi.SLIDE_UP);
    }
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {

    //! Reports the progress of the running search.
    private var _searchItem as MenuItem;
    private var _originItem as MenuItem;
    private var _destinationItem as MenuItem;
    private var _departureItem as MenuItem;
    private var _filtersItem as MenuItem;

    function initialize(searchItem as MenuItem, originItem as MenuItem, destinationItem as MenuItem, departureItem as MenuItem, filtersItem as MenuItem) {
        Menu2InputDelegate.initialize();
        _searchItem = searchItem;
        _originItem = originItem;
        _destinationItem = destinationItem;
        _departureItem = departureItem;
        _filtersItem = filtersItem;
        getServices().location.setListener(method(:refresh));
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id == :search) {
            startSearch();
        } else if (id == :wifi) {
            searchOverWifi(item);
        } else if (id == :favourites) {
            FavouriteList.push(method(:searchChosenTrip));
        } else if (id == :origin) {
            StopChooser.push(StopChooser.ORIGIN, method(:refresh));
        } else if (id == :destination) {
            StopChooser.push(StopChooser.DESTINATION, method(:refresh));
        } else if (id == :when) {
            DepartureMenu.push(method(:refresh));
        } else if (id == :board) {
            BoardChooser.push();
        } else if (id == :about) {
            WatchUi.pushView(new FullTextView(Texts.about(BuildConfig.APP_VERSION)), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :filters) {
            FilterMenu.push(method(:refresh));
        } else if (id == :swap) {
            swapStops(item);
        } else if (id == :saved) {
            if (getServices().savedSearches.searches.size() == 0) {
                item.setSubLabel(Rez.Strings.NothingSaved);
            } else {
                item.setSubLabel(Rez.Strings.SavedHint);
                SavedList.push(method(:refresh));
            }
        }
        WatchUi.requestUpdate();
    }

    function onBack() as Void {
        getServices().location.setListener(null);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    //! Shows the current origin, destination, departure time and filters in the menu.
    function refresh() as Void {
        var app = getServices();
        _originItem.setSubLabel(Texts.originName(app.trip, app.location));
        _destinationItem.setSubLabel(Texts.destinationName(app.trip));
        _departureItem.setLabel(Texts.timeKind(app.trip));
        _departureItem.setSubLabel(Texts.departure(app.trip.departureTime));
        _filtersItem.setSubLabel(Texts.filters(app.trip.filters));
        WatchUi.requestUpdate();
    }

    //! Stores the search of the planned trip and asks the watch for a sync
    //! over Wi-Fi; the watch closes the app. The connections end up in the
    //! saved searches.
    private function searchOverWifi(item as MenuItem) as Void {
        if (!mayUseOrigin()) {
            return;
        }
        var problem = wifiProblem(WifiSearch.availability());
        var query = problem == null ? ConnectionSearch.prepare() : problem;
        if (!(query instanceof ConnectionQuery)) {
            item.setSubLabel(query);
            WatchUi.requestUpdate();
            return;
        }
        WifiSearch.request(query, Texts.get(Rez.Strings.WifiSyncing));
    }

    //! A favourite trip was chosen: show it and search right away.
    function searchChosenTrip() as Void {
        refresh();
        startSearch();
    }

    function onConnections(page as ConnectionsPage?, error as ApiError?) as Void {
        var item = _searchItem;
        if (page == null) {
            item.setSubLabel(error != null ? Texts.error(error) : null);
        } else if (page.connections.size() == 0) {
            item.setSubLabel(Rez.Strings.NothingFound);
        } else {
            item.setSubLabel(null);
            ConnectionSearch.remember(page);
            ConnectionList.push(page, null, null);
        }
        WatchUi.requestUpdate();
    }

    private function startSearch() as Void {
        if (!mayUseOrigin()) {
            return;
        }
        var item = _searchItem;
        var problem = ConnectionSearch.start(null, method(:onConnections));
        item.setSubLabel(problem != null ? problem : Rez.Strings.Searching);
    }

    //! A search from the current position needs the user's consent first.
    private function mayUseOrigin() as Boolean {
        return getServices().trip.origin != null || LocationConsent.ask();
    }

    private function swapStops(item as MenuItem) as Void {
        var trip = getServices().trip;
        if (trip.origin == null || trip.destination == null) {
            item.setSubLabel(Rez.Strings.NeedBothStops);
            return;
        }
        trip.swap();
        refresh();
    }
}

//! Problem that keeps the search over Wi-Fi from starting; null when it can.
function wifiProblem(availability as WifiSearch.Availability) as ResourceId? {
    if (availability == WifiSearch.NO_WIFI) {
        return Rez.Strings.WifiMissing;
    }
    return availability == WifiSearch.NOT_SET_UP ? Rez.Strings.WifiNotSetUp : null;
}

//! Starts a connection search for the current trip.
module ConnectionSearch {

    //! Returns null when the request was sent, otherwise the reason why the
    //! search cannot start yet.
    function start(cursor as String?, callback as ConnectionsCallback) as ResourceId? {
        var query = prepare();
        if (!(query instanceof ConnectionQuery)) {
            return query;
        }
        getServices().api.searchConnections(query.origin, query.trip.destination.id, query.departureTime, query.arriveBy, query.filters, cursor, callback);
        return null;
    }

    //! The search of the planned trip, or the reason why it cannot be made yet.
    function prepare() as ConnectionQuery or ResourceId {
        var app = getServices();
        var trip = app.trip.currentTrip();
        if (trip == null) {
            return Rez.Strings.SetDestinationFirst;
        }
        var origin;
        var originStop = trip.origin;
        if (originStop != null) {
            origin = originStop.id;
        } else {
            var coordinates = app.location.getCoordinates();
            if (coordinates == null) {
                return Rez.Strings.WaitingForGps;
            }
            origin = TransitApi.formatCoordinates(coordinates);
        }
        return new ConnectionQuery(trip, origin, app.trip.departureTime, app.trip.searchesByArrival(), app.trip.filters);
    }

    //! Keeps the results of the current trip for reading without a connection.
    function remember(page as ConnectionsPage) as Void {
        var app = getServices();
        var trip = app.trip.currentTrip();
        if (trip == null) {
            return;
        }
        // Later pages cannot be loaded offline, so the cursor is not kept.
        app.savedSearches.save(new SavedSearch(trip, Time.now().value(), new ConnectionsPage(page.connections, null)));
    }
}
