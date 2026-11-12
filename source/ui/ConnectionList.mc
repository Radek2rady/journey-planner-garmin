import Toybox.Lang;
import Toybox.WatchUi;

//! List of found connections; selecting one opens its legs.
module ConnectionList {

    function push(page as ConnectionsPage) as Void {
        var menu = new WatchUi.Menu2({ :title => Rez.Strings.Connections });
        var connections = page.connections;
        for (var i = 0; i < connections.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(Texts.connectionTimes(connections[i]), Texts.connectionSummary(connections[i]), i, null));
        }
        if (page.nextCursor != null) {
            menu.addItem(new WatchUi.MenuItem(Rez.Strings.LaterConnections, null, :later, null));
        }
        WatchUi.pushView(menu, new ConnectionListDelegate(page), WatchUi.SLIDE_LEFT);
    }
}

class ConnectionListDelegate extends WatchUi.Menu2InputDelegate {

    private var _page as ConnectionsPage;
    //! Item that reports the progress of loading the next page.
    private var _laterItem as MenuItem?;

    function initialize(page as ConnectionsPage) {
        Menu2InputDelegate.initialize();
        _page = page;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id == :later) {
            _laterItem = item;
            var problem = ConnectionSearch.start(_page.nextCursor, method(:onConnections));
            item.setSubLabel(problem != null ? problem : Rez.Strings.Searching);
            WatchUi.requestUpdate();
        } else if (id instanceof Number) {
            ConnectionDetail.push(_page.connections[id]);
        }
    }

    function onConnections(page as ConnectionsPage?, error as ApiError?) as Void {
        var item = _laterItem;
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
}

//! Legs of one connection: boarding and alighting of every ride, with the
//! walks between them.
module ConnectionDetail {

    function push(connection as Connection) as Void {
        var menu = new WatchUi.Menu2({ :title => Texts.connectionTimes(connection) });
        var legs = connection.legs;
        for (var i = 0; i < legs.size(); i++) {
            var leg = legs[i];
            if (leg.isWalk()) {
                menu.addItem(new WatchUi.MenuItem(Texts.walk(leg), Texts.placeOrDestination(leg.to), :leg, null));
            } else {
                menu.addItem(new WatchUi.MenuItem(Texts.boarding(leg), Texts.boardingDetails(leg), :leg, null));
                menu.addItem(new WatchUi.MenuItem(Texts.alighting(leg), Rez.Strings.GetOff, :leg, null));
            }
        }
        WatchUi.pushView(menu, new WatchUi.Menu2InputDelegate(), WatchUi.SLIDE_LEFT);
    }
}
