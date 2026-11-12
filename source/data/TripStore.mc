import Toybox.Application;
import Toybox.Lang;

//! The trip being planned (origin and destination) and recently used stops,
//! persisted across app launches.
class TripStore {

    private const KEY_ORIGIN = "origin";
    private const KEY_DESTINATION = "destination";
    private const KEY_RECENT = "recent";
    private const KEY_FILTERS = "filters";

    //! null means "current location".
    var origin as Stop?;
    var destination as Stop?;
    //! Requested departure in Unix seconds; null means now. Not persisted: a
    //! time chosen in an earlier session would be stale.
    var departureTime as Number?;
    var filters as SearchFilters = new SearchFilters();
    //! Most recently used first.
    var recent as Array<Stop> = [] as Array<Stop>;

    function initialize() {
    }

    function load() as Void {
        origin = loadStop(KEY_ORIGIN);
        destination = loadStop(KEY_DESTINATION);
        var savedFilters = Storage.getValue(KEY_FILTERS) as Dictionary?;
        filters = savedFilters != null ? SearchFilters.fromDictionary(savedFilters) : new SearchFilters();
        var saved = Storage.getValue(KEY_RECENT) as Array<Dictionary>?;
        recent = [] as Array<Stop>;
        if (saved != null) {
            for (var i = 0; i < saved.size(); i++) {
                recent.add(Stop.fromDictionary(saved[i]));
            }
        }
    }

    function setOrigin(stop as Stop?) as Void {
        origin = stop;
        saveStop(KEY_ORIGIN, stop);
        remember(stop);
    }

    function setDestination(stop as Stop?) as Void {
        destination = stop;
        saveStop(KEY_DESTINATION, stop);
        remember(stop);
    }

    //! Call after changing `filters`.
    function saveFilters() as Void {
        Storage.setValue(KEY_FILTERS, filters.toDictionary() as Dictionary<Storage.KeyType, Storage.ValueType>);
    }

    //! The planned trip; null while no destination is set.
    function currentTrip() as Trip? {
        var to = destination;
        return to != null ? new Trip(origin, to) : null;
    }

    function setTrip(trip as Trip) as Void {
        origin = trip.origin;
        destination = trip.destination;
        saveStop(KEY_ORIGIN, origin);
        saveStop(KEY_DESTINATION, destination);
    }

    function swap() as Void {
        var previousOrigin = origin;
        origin = destination;
        destination = previousOrigin;
        saveStop(KEY_ORIGIN, origin);
        saveStop(KEY_DESTINATION, destination);
    }

    //! Returns `stops` with `stop` moved or added to the front, capped at `limit`.
    static function withRecent(stops as Array<Stop>, stop as Stop, limit as Number) as Array<Stop> {
        var result = [stop] as Array<Stop>;
        for (var i = 0; i < stops.size() && result.size() < limit; i++) {
            if (!stops[i].id.equals(stop.id)) {
                result.add(stops[i]);
            }
        }
        return result;
    }

    private function remember(stop as Stop?) as Void {
        if (stop == null) {
            return;
        }
        recent = withRecent(recent, stop, Config.MAX_RECENT_STOPS);
        var saved = [] as Array<Dictionary<String, String> >;
        for (var i = 0; i < recent.size(); i++) {
            saved.add(recent[i].toDictionary());
        }
        Storage.setValue(KEY_RECENT, saved as Array<Storage.ValueType>);
    }

    private function loadStop(key as String) as Stop? {
        var saved = Storage.getValue(key) as Dictionary?;
        return saved != null ? Stop.fromDictionary(saved) : null;
    }

    private function saveStop(key as String, stop as Stop?) as Void {
        if (stop == null) {
            Storage.deleteValue(key);
        } else {
            Storage.setValue(key, stop.toDictionary() as Dictionary<Storage.KeyType, Storage.ValueType>);
        }
    }
}
