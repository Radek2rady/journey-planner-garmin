import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

//! Main menu: search, favourite trips, origin, destination, departure time,
//! filters, swap, saved connections, departure board.
module MainMenu {

    function push() as Void {
        var app = getApp();
        var originItem = new WatchUi.MenuItem(Rez.Strings.From, Texts.originName(app.trip, app.location), :origin, null);
        var destinationItem = new WatchUi.MenuItem(Rez.Strings.To, Texts.destinationName(app.trip), :destination, null);
        var departureItem = new WatchUi.MenuItem(Rez.Strings.Departure, Texts.departure(app.trip.departureTime), :when, null);
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
        getApp().location.setListener(method(:refresh));
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id == :search) {
            startSearch();
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
        } else if (id == :filters) {
            FilterMenu.push(method(:refresh));
        } else if (id == :swap) {
            swapStops(item);
        } else if (id == :saved) {
            if (getApp().savedSearches.searches.size() == 0) {
                item.setSubLabel(Rez.Strings.NothingSaved);
            } else {
                item.setSubLabel(Rez.Strings.SavedHint);
                SavedList.push(method(:refresh));
            }
        }
        WatchUi.requestUpdate();
    }

    function onBack() as Void {
        getApp().location.setListener(null);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    //! Shows the current origin, destination, departure time and filters in the menu.
    function refresh() as Void {
        var app = getApp();
        _originItem.setSubLabel(Texts.originName(app.trip, app.location));
        _destinationItem.setSubLabel(Texts.destinationName(app.trip));
        _departureItem.setSubLabel(Texts.departure(app.trip.departureTime));
        _filtersItem.setSubLabel(Texts.filters(app.trip.filters));
        WatchUi.requestUpdate();
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
        var item = _searchItem;
        var problem = ConnectionSearch.start(null, method(:onConnections));
        item.setSubLabel(problem != null ? problem : Rez.Strings.Searching);
    }

    private function swapStops(item as MenuItem) as Void {
        var trip = getApp().trip;
        if (trip.origin == null || trip.destination == null) {
            item.setSubLabel(Rez.Strings.NeedBothStops);
            return;
        }
        trip.swap();
        refresh();
    }
}

//! Starts a connection search for the current trip.
module ConnectionSearch {

    //! Returns null when the request was sent, otherwise the reason why the
    //! search cannot start yet.
    function start(cursor as String?, callback as ConnectionsCallback) as ResourceId? {
        var app = getApp();
        var destination = app.trip.destination;
        if (destination == null) {
            return Rez.Strings.SetDestinationFirst;
        }
        var origin;
        var originStop = app.trip.origin;
        if (originStop != null) {
            origin = originStop.id;
        } else {
            var coordinates = app.location.getCoordinates();
            if (coordinates == null) {
                return Rez.Strings.WaitingForGps;
            }
            origin = TransitApi.formatCoordinates(coordinates);
        }
        app.api.searchConnections(origin, destination.id, app.trip.departureTime, app.trip.filters, cursor, callback);
        return null;
    }

    //! Keeps the results of the current trip for reading without a connection.
    function remember(page as ConnectionsPage) as Void {
        var app = getApp();
        var trip = app.trip.currentTrip();
        if (trip == null) {
            return;
        }
        // Later pages cannot be loaded offline, so the cursor is not kept.
        app.savedSearches.save(new SavedSearch(trip, Time.now().value(), new ConnectionsPage(page.connections, null)));
    }
}
