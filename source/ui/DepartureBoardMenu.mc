import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

//! Chooses the stop of a departure board: the nearest one or a recent stop.
module BoardChooser {

    function push() as Void {
        var recent = getApp().trip.recent;
        var menu = new WatchUi.Menu2({ :title => Rez.Strings.Board });
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.NearestStop, null, :nearest, null));
        StopChooser.addStops(menu, recent);
        WatchUi.pushView(menu, new BoardChooserDelegate(recent), WatchUi.SLIDE_LEFT);
    }
}

class BoardChooserDelegate extends WatchUi.Menu2InputDelegate {

    private var _recent as Array<Stop>;
    //! Item that reports the progress of the running request.
    private var _progressItem as MenuItem?;

    function initialize(recent as Array<Stop>) {
        Menu2InputDelegate.initialize();
        _recent = recent;
    }

    function onSelect(item as MenuItem) as Void {
        var app = getApp();
        var id = item.getId();
        if (id == :nearest) {
            var coordinates = app.location.getCoordinates();
            if (coordinates == null) {
                item.setSubLabel(Rez.Strings.WaitingForGps);
            } else {
                _progressItem = item;
                item.setSubLabel(Rez.Strings.Searching);
                app.api.searchDepartures(null, coordinates, method(:onBoard));
            }
        } else if (id instanceof Number) {
            _progressItem = item;
            item.setSubLabel(Rez.Strings.Searching);
            app.api.searchDepartures(_recent[id].id, null, method(:onBoard));
        }
        WatchUi.requestUpdate();
    }

    function onBoard(board as DepartureBoard?, error as ApiError?) as Void {
        var item = _progressItem;
        if (item == null) {
            return;
        }
        if (board == null) {
            item.setSubLabel(error != null ? Texts.error(error) : null);
        } else if (board.departures.size() == 0) {
            item.setSubLabel(Rez.Strings.NothingFound);
        } else {
            item.setSubLabel(null);
            DepartureBoardMenu.push(board);
        }
        WatchUi.requestUpdate();
    }
}

//! The departures of one stop; selecting a line shows it in full.
module DepartureBoardMenu {

    function push(board as DepartureBoard) as Void {
        var now = Time.now().value();
        var menu = new WatchUi.Menu2({ :title => board.stopName });
        var items = [] as Array<MenuItem>;
        var departures = board.departures;
        for (var i = 0; i < departures.size(); i++) {
            var item = new WatchUi.MenuItem(Texts.boardLine(departures[i], now), Texts.boardDirection(departures[i]), i, null);
            items.add(item);
            menu.addItem(item);
        }
        var delegate = new DepartureBoardDelegate(board, items);
        CountdownTicker.opened(delegate);
        WatchUi.pushView(menu, delegate, WatchUi.SLIDE_LEFT);
    }
}

class DepartureBoardDelegate extends WatchUi.Menu2InputDelegate {

    private var _board as DepartureBoard;
    //! Items in the order of `_board.departures`.
    private var _items as Array<MenuItem>;

    function initialize(board as DepartureBoard, items as Array<MenuItem>) {
        Menu2InputDelegate.initialize();
        _board = board;
        _items = items;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number) {
            WatchUi.pushView(new FullTextView(Texts.departureDetails(_board.departures[id])),
                new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_LEFT);
        }
    }

    function onBack() as Void {
        CountdownTicker.closed(self);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function refreshCountdowns(now as Number) as Void {
        for (var i = 0; i < _items.size(); i++) {
            _items[i].setLabel(Texts.boardLine(_board.departures[i], now));
        }
        WatchUi.requestUpdate();
    }
}
