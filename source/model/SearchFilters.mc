import Toybox.Lang;

//! Preferences that narrow a connection search.
class SearchFilters {

    //! Values of `vehicles`: lists of vehicle codes as the proxy expects them
    //! in the `v` parameter (docs/API.md).
    static const ALL_VEHICLES = "";
    static const TRAINS_ONLY = "train";
    static const NO_TRAINS = "bus,tram,metro,ferry,cable";

    static const MAX_TRANSFERS_OFFERED = 2;

    //! null means any number of transfers; 0 direct connections only.
    var maxTransfers as Number?;
    var vehicles as String = ALL_VEHICLES;

    function initialize() {
    }

    function isActive() as Boolean {
        return maxTransfers != null || !vehicles.equals(ALL_VEHICLES);
    }

    //! Moves to the next choice: any, direct only, at most 1, at most 2.
    function cycleTransfers() as Void {
        var current = maxTransfers;
        if (current == null) {
            maxTransfers = 0;
        } else {
            maxTransfers = current < MAX_TRANSFERS_OFFERED ? current + 1 : null;
        }
    }

    //! Moves to the next choice: all, trains only, without trains.
    function cycleVehicles() as Void {
        if (vehicles.equals(ALL_VEHICLES)) {
            vehicles = TRAINS_ONLY;
        } else {
            vehicles = vehicles.equals(TRAINS_ONLY) ? NO_TRAINS : ALL_VEHICLES;
        }
    }

    static function fromDictionary(data as Dictionary) as SearchFilters {
        var filters = new SearchFilters();
        filters.maxTransfers = data["x"] as Number?;
        var vehicles = data["v"] as String?;
        if (vehicles != null) {
            filters.vehicles = vehicles;
        }
        return filters;
    }

    function toDictionary() as Dictionary {
        var data = { "v" => vehicles } as Dictionary<String, String or Number>;
        var transfers = maxTransfers;
        if (transfers != null) {
            data["x"] = transfers;
        }
        return data as Dictionary;
    }
}
