import Toybox.Lang;
import Toybox.WatchUi;

//! Main menu: search, origin, destination, swap.
module MainMenu {

    function push() as Void {
        var app = getApp();
        var originItem = new WatchUi.MenuItem(Rez.Strings.From, Texts.originName(app.trip, app.location), :origin, null);
        var destinationItem = new WatchUi.MenuItem(Rez.Strings.To, Texts.destinationName(app.trip), :destination, null);

        var menu = new WatchUi.Menu2({ :title => Rez.Strings.Connections });
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.FindConnections, null, :search, null));
        menu.addItem(originItem);
        menu.addItem(destinationItem);
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Swap, Rez.Strings.SwapHint, :swap, null));
        WatchUi.pushView(menu, new MainMenuDelegate(originItem, destinationItem), WatchUi.SLIDE_UP);
    }
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _originItem as MenuItem;
    private var _destinationItem as MenuItem;
    //! Item that reports the progress of the running search.
    private var _searchItem as MenuItem?;

    function initialize(originItem as MenuItem, destinationItem as MenuItem) {
        Menu2InputDelegate.initialize();
        _originItem = originItem;
        _destinationItem = destinationItem;
        getApp().location.setListener(method(:refresh));
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id == :search) {
            startSearch(item);
        } else if (id == :origin) {
            StopChooser.push(StopChooser.ORIGIN, method(:refresh));
        } else if (id == :destination) {
            StopChooser.push(StopChooser.DESTINATION, method(:refresh));
        } else if (id == :swap) {
            swapStops(item);
        }
        WatchUi.requestUpdate();
    }

    function onBack() as Void {
        getApp().location.setListener(null);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    //! Shows the current origin and destination in the menu.
    function refresh() as Void {
        var app = getApp();
        _originItem.setSubLabel(Texts.originName(app.trip, app.location));
        _destinationItem.setSubLabel(Texts.destinationName(app.trip));
        WatchUi.requestUpdate();
    }

    function onConnections(page as ConnectionsPage?, error as ApiError?) as Void {
        var item = _searchItem;
        if (item == null) {
            return;
        }
        if (page == null) {
            item.setSubLabel(error != null ? Texts.error(error) : null);
        } else if (page.connections.size() == 0) {
            item.setSubLabel(Rez.Strings.NothingFound);
        } else {
            item.setSubLabel(null);
            ConnectionList.push(page);
        }
        WatchUi.requestUpdate();
    }

    private function startSearch(item as MenuItem) as Void {
        _searchItem = item;
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
        app.api.searchConnections(origin, destination.id, cursor, callback);
        return null;
    }
}
