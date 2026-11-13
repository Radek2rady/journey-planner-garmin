import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

//! List of found connections; selecting one opens its legs. The countdowns
//! to departure are kept current by `CountdownTicker`.
module ConnectionList {

    //! `savedTrip` is set for results read from storage: the list then offers
    //! to search that trip again, and calls `onTripChanged` when it does.
    function push(page as ConnectionsPage, savedTrip as Trip?, onTripChanged as (Method() as Void)?) as Void {
        var now = Time.now().value();
        var menu = new WatchUi.Menu2({ :title => Rez.Strings.Connections });
        var items = [] as Array<MenuItem>;
        var connections = page.connections;
        for (var i = 0; i < connections.size(); i++) {
            var item = new WatchUi.MenuItem(Texts.connectionTimes(connections[i]), Texts.connectionSummary(connections[i], now), i, null);
            items.add(item);
            menu.addItem(item);
        }
        if (page.nextCursor != null) {
            menu.addItem(new WatchUi.MenuItem(Rez.Strings.LaterConnections, null, :later, null));
        }
        if (savedTrip != null) {
            menu.addItem(new WatchUi.MenuItem(Rez.Strings.SearchAgain, null, :again, null));
        }
        var delegate = new ConnectionListDelegate(page, items, savedTrip, onTripChanged);
        CountdownTicker.opened(delegate);
        WatchUi.pushView(menu, delegate, WatchUi.SLIDE_LEFT);
    }
}

class ConnectionListDelegate extends WatchUi.Menu2InputDelegate {

    private var _page as ConnectionsPage;
    //! Items of the connections, in the order of `_page.connections`.
    private var _items as Array<MenuItem>;
    private var _savedTrip as Trip?;
    private var _onTripChanged as (Method() as Void)?;
    //! Item that reports the progress of the running search.
    private var _progressItem as MenuItem?;

    function initialize(page as ConnectionsPage, items as Array<MenuItem>, savedTrip as Trip?, onTripChanged as (Method() as Void)?) {
        Menu2InputDelegate.initialize();
        _page = page;
        _items = items;
        _savedTrip = savedTrip;
        _onTripChanged = onTripChanged;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id == :later) {
            search(item, _page.nextCursor);
        } else if (id == :again) {
            searchAgain(item);
        } else if (id instanceof Number) {
            ConnectionDetail.push(_page.connections[id]);
        }
    }

    function onBack() as Void {
        CountdownTicker.closed(self);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function refreshCountdowns(now as Number) as Void {
        for (var i = 0; i < _items.size(); i++) {
            _items[i].setSubLabel(Texts.connectionSummary(_page.connections[i], now));
        }
        WatchUi.requestUpdate();
    }

    function onConnections(page as ConnectionsPage?, error as ApiError?) as Void {
        var item = _progressItem;
        if (item == null) {
            return;
        }
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

    //! Makes the saved trip the planned one and searches it from now.
    private function searchAgain(item as MenuItem) as Void {
        var trip = _savedTrip;
        if (trip == null) {
            return;
        }
        var planned = getServices().trip;
        planned.setTrip(trip);
        planned.departureTime = null;
        var onTripChanged = _onTripChanged;
        if (onTripChanged != null) {
            onTripChanged.invoke();
        }
        search(item, null);
    }

    private function search(item as MenuItem, cursor as String?) as Void {
        _progressItem = item;
        var problem = ConnectionSearch.start(cursor, method(:onConnections));
        item.setSubLabel(problem != null ? problem : Rez.Strings.Searching);
        WatchUi.requestUpdate();
    }
}

//! Legs of one connection: boarding and alighting of every ride, with the
//! walks between them. Selecting a line shows it in full on its own screen,
//! because a menu line cuts long stop names and directions.
module ConnectionDetail {

    function push(connection as Connection) as Void {
        var menu = new WatchUi.Menu2({ :title => Texts.connectionTimes(connection) });
        var lines = [] as Array<String>;
        var legs = connection.legs;
        for (var i = 0; i < legs.size(); i++) {
            var leg = legs[i];
            if (leg.isWalk()) {
                addLine(menu, lines, Texts.walk(leg), Texts.placeOrDestination(leg.to));
            } else {
                addLine(menu, lines, Texts.boarding(leg), Texts.boardingDetails(leg));
                addLine(menu, lines, Texts.alighting(leg), Texts.get(Rez.Strings.GetOff));
            }
        }
        WatchUi.pushView(menu, new ConnectionDetailDelegate(lines), WatchUi.SLIDE_LEFT);
    }

    //! Adds a menu item and remembers its full text; the item id is the
    //! index into `lines`.
    function addLine(menu as Menu2, lines as Array<String>, label as String, subLabel as String) as Void {
        menu.addItem(new WatchUi.MenuItem(label, subLabel, lines.size(), null));
        lines.add(label + "\n" + subLabel);
    }
}

class ConnectionDetailDelegate extends WatchUi.Menu2InputDelegate {

    private var _lines as Array<String>;

    function initialize(lines as Array<String>) {
        Menu2InputDelegate.initialize();
        _lines = lines;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number) {
            WatchUi.pushView(new FullTextView(_lines[id]), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_LEFT);
        }
    }
}

//! A text wrapped over the whole screen, in the largest font that fits.
class FullTextView extends WatchUi.View {

    private var _text as String;

    function initialize(text as String) {
        View.initialize();
        _text = text;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        // A square inside the round screen.
        var area = new WatchUi.TextArea({
            :text => _text,
            :color => Graphics.COLOR_WHITE,
            :font => [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY],
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER,
            :width => (dc.getWidth() * 0.72).toNumber(),
            :height => (dc.getHeight() * 0.72).toNumber(),
            :justification => Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        });
        area.draw(dc);
    }
}
