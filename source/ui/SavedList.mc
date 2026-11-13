import Toybox.Lang;
import Toybox.WatchUi;

//! Saved searches; selecting one opens its connections without any request.
//! The last item leads to deleting searches.
module SavedList {

    //! `onTripChanged` is called when a saved trip becomes the planned trip
    //! because the user searched it again.
    function push(onTripChanged as Method() as Void) as Void {
        WatchUi.pushView(menu(), new SavedListDelegate(onTripChanged), WatchUi.SLIDE_LEFT);
    }

    function menu() as Menu2 {
        var result = new WatchUi.Menu2({ :title => Rez.Strings.Saved });
        addSearches(result);
        result.addItem(new WatchUi.MenuItem(Rez.Strings.DeleteSaved, null, :delete, null));
        return result;
    }

    //! The searches to delete one by one, after an item that deletes them all.
    function deletionMenu() as Menu2 {
        var result = new WatchUi.Menu2({ :title => Rez.Strings.DeleteSaved });
        result.addItem(new WatchUi.MenuItem(Rez.Strings.DeleteAll, null, :all, null));
        addSearches(result);
        return result;
    }

    //! One item per search; the item id is its index in the saved searches.
    function addSearches(target as Menu2) as Void {
        var searches = getServices().savedSearches.searches;
        for (var i = 0; i < searches.size(); i++) {
            target.addItem(new WatchUi.MenuItem(Texts.tripName(searches[i].trip), Texts.savedAt(searches[i]), i, null));
        }
    }
}

class SavedListDelegate extends WatchUi.Menu2InputDelegate {

    private var _onTripChanged as Method() as Void;

    function initialize(onTripChanged as Method() as Void) {
        Menu2InputDelegate.initialize();
        _onTripChanged = onTripChanged;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id == :delete) {
            WatchUi.switchToView(SavedList.deletionMenu(), new SavedDeletionDelegate(_onTripChanged), WatchUi.SLIDE_LEFT);
        } else if (id instanceof Number) {
            var search = getServices().savedSearches.searches[id];
            ConnectionList.push(search.page, search.trip, _onTripChanged);
        }
    }
}

//! Deletes the chosen search, or all of them, and returns to the list; to
//! the main menu when nothing is left.
class SavedDeletionDelegate extends WatchUi.Menu2InputDelegate {

    private var _onTripChanged as Method() as Void;

    function initialize(onTripChanged as Method() as Void) {
        Menu2InputDelegate.initialize();
        _onTripChanged = onTripChanged;
    }

    function onSelect(item as MenuItem) as Void {
        var saved = getServices().savedSearches;
        var id = item.getId();
        if (id == :all) {
            saved.clear();
        } else if (id instanceof Number) {
            saved.remove(id);
        } else {
            return;
        }
        if (saved.searches.size() == 0) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        } else {
            WatchUi.switchToView(SavedList.menu(), new SavedListDelegate(_onTripChanged), WatchUi.SLIDE_RIGHT);
        }
    }

    //! BACK returns to the list rather than to the main menu.
    function onBack() as Void {
        WatchUi.switchToView(SavedList.menu(), new SavedListDelegate(_onTripChanged), WatchUi.SLIDE_RIGHT);
    }
}
