import Toybox.Lang;
import Toybox.WatchUi;

//! Saved searches; selecting one opens its connections without any request.
module SavedList {

    //! `onTripChanged` is called when a saved trip becomes the planned trip
    //! because the user searched it again.
    function push(onTripChanged as Method() as Void) as Void {
        var searches = getServices().savedSearches.searches;
        var menu = new WatchUi.Menu2({ :title => Rez.Strings.Saved });
        for (var i = 0; i < searches.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(Texts.tripName(searches[i].trip), Texts.savedAt(searches[i]), i, null));
        }
        WatchUi.pushView(menu, new SavedListDelegate(searches, onTripChanged), WatchUi.SLIDE_LEFT);
    }
}

class SavedListDelegate extends WatchUi.Menu2InputDelegate {

    private var _searches as Array<SavedSearch>;
    private var _onTripChanged as Method() as Void;

    function initialize(searches as Array<SavedSearch>, onTripChanged as Method() as Void) {
        Menu2InputDelegate.initialize();
        _searches = searches;
        _onTripChanged = onTripChanged;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number) {
            ConnectionList.push(_searches[id].page, _searches[id].trip, _onTripChanged);
        }
    }
}
