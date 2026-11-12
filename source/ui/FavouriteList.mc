import Toybox.Lang;
import Toybox.WatchUi;

//! Favourite trips: choosing one makes it the planned trip. The list also
//! adds the planned trip to the favourites and leads to removing one.
module FavouriteList {

    //! `onChosen` is called after a favourite became the planned trip.
    function push(onChosen as Method() as Void) as Void {
        WatchUi.pushView(menu(), new FavouriteListDelegate(onChosen), WatchUi.SLIDE_LEFT);
    }

    function menu() as Menu2 {
        var app = getApp();
        var trips = app.favourites.trips;
        var current = app.trip.currentTrip();
        var result = new WatchUi.Menu2({ :title => Rez.Strings.Favourites });
        addTrips(result, trips);
        result.addItem(new WatchUi.MenuItem(Rez.Strings.AddCurrentTrip, current != null ? Texts.tripName(current) : null, :add, null));
        if (trips.size() > 0) {
            result.addItem(new WatchUi.MenuItem(Rez.Strings.RemoveFavourite, null, :remove, null));
        }
        return result;
    }

    function removalMenu() as Menu2 {
        var result = new WatchUi.Menu2({ :title => Rez.Strings.RemoveFavourite });
        addTrips(result, getApp().favourites.trips);
        return result;
    }

    //! Adds one item per trip: the destination, with the origin below it.
    //! The item id is the index into `trips`.
    function addTrips(target as Menu2, trips as Array<Trip>) as Void {
        for (var i = 0; i < trips.size(); i++) {
            target.addItem(new WatchUi.MenuItem(trips[i].destination.name, Texts.tripOrigin(trips[i]), i, null));
        }
    }
}

class FavouriteListDelegate extends WatchUi.Menu2InputDelegate {

    private var _onChosen as Method() as Void;

    function initialize(onChosen as Method() as Void) {
        Menu2InputDelegate.initialize();
        _onChosen = onChosen;
    }

    function onSelect(item as MenuItem) as Void {
        var app = getApp();
        var id = item.getId();
        if (id == :add) {
            var current = app.trip.currentTrip();
            if (current == null) {
                item.setSubLabel(Rez.Strings.SetDestinationFirst);
                WatchUi.requestUpdate();
                return;
            }
            app.favourites.add(current);
            WatchUi.switchToView(FavouriteList.menu(), new FavouriteListDelegate(_onChosen), WatchUi.SLIDE_IMMEDIATE);
        } else if (id == :remove) {
            WatchUi.switchToView(FavouriteList.removalMenu(), new FavouriteRemovalDelegate(_onChosen), WatchUi.SLIDE_LEFT);
        } else if (id instanceof Number) {
            app.trip.setTrip(app.favourites.trips[id]);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            _onChosen.invoke();
        }
    }
}

class FavouriteRemovalDelegate extends WatchUi.Menu2InputDelegate {

    private var _onChosen as Method() as Void;

    function initialize(onChosen as Method() as Void) {
        Menu2InputDelegate.initialize();
        _onChosen = onChosen;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number) {
            getApp().favourites.remove(id);
            WatchUi.switchToView(FavouriteList.menu(), new FavouriteListDelegate(_onChosen), WatchUi.SLIDE_RIGHT);
        }
    }
}
