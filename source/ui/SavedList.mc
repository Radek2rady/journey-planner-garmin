import Toybox.Lang;
import Toybox.WatchUi;

//! Saved searches; selecting one opens its connections without any request.
module SavedList {

    function push() as Void {
        var searches = getApp().savedSearches.searches;
        var menu = new WatchUi.Menu2({ :title => Rez.Strings.Saved });
        for (var i = 0; i < searches.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(Texts.savedTrip(searches[i]), Texts.savedAt(searches[i]), i, null));
        }
        WatchUi.pushView(menu, new SavedListDelegate(searches), WatchUi.SLIDE_LEFT);
    }
}

class SavedListDelegate extends WatchUi.Menu2InputDelegate {

    private var _searches as Array<SavedSearch>;

    function initialize(searches as Array<SavedSearch>) {
        Menu2InputDelegate.initialize();
        _searches = searches;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number) {
            ConnectionList.push(_searches[id].page);
        }
    }
}
