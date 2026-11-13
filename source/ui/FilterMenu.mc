import Toybox.Lang;
import Toybox.WatchUi;

//! Search filters. Selecting an item moves it to its next choice.
module FilterMenu {

    //! `onChanged` is called after a filter has been changed.
    function push(onChanged as Method() as Void) as Void {
        var filters = getServices().trip.filters;
        var menu = new WatchUi.Menu2({ :title => Rez.Strings.Filters });
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Transfers, Texts.transfersFilter(filters), :transfers, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Vehicles, Texts.vehiclesFilter(filters), :vehicles, null));
        WatchUi.pushView(menu, new FilterMenuDelegate(onChanged), WatchUi.SLIDE_LEFT);
    }
}

class FilterMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _onChanged as Method() as Void;

    function initialize(onChanged as Method() as Void) {
        Menu2InputDelegate.initialize();
        _onChanged = onChanged;
    }

    function onSelect(item as MenuItem) as Void {
        var trip = getServices().trip;
        var filters = trip.filters;
        var id = item.getId();
        if (id == :transfers) {
            filters.cycleTransfers();
            item.setSubLabel(Texts.transfersFilter(filters));
        } else if (id == :vehicles) {
            filters.cycleVehicles();
            item.setSubLabel(Texts.vehiclesFilter(filters));
        } else {
            return;
        }
        trip.saveFilters();
        _onChanged.invoke();
        WatchUi.requestUpdate();
    }
}
