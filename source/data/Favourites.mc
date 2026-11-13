import Toybox.Application;
import Toybox.Lang;

//! Favourite trips, persisted across app launches.
class Favourites {


    //! Most recently added first.
    var trips as Array<Trip> = [] as Array<Trip>;

    function initialize() {
    }

    function load() as Void {
        trips = [] as Array<Trip>;
        var saved = Storage.getValue(StorageKeys.FAVOURITES) as Array<Dictionary>?;
        if (saved != null) {
            for (var i = 0; i < saved.size(); i++) {
                trips.add(Trip.fromDictionary(saved[i]));
            }
        }
    }

    function add(trip as Trip) as Void {
        trips = withTrip(trips, trip, Config.MAX_FAVOURITES);
        persist();
    }

    function remove(index as Number) as Void {
        if (index >= 0 && index < trips.size()) {
            trips.remove(trips[index]);
            persist();
        }
    }

    //! Returns `list` with `trip` at the front, without its older copy,
    //! capped at `limit`.
    static function withTrip(list as Array<Trip>, trip as Trip, limit as Number) as Array<Trip> {
        var result = [trip] as Array<Trip>;
        for (var i = 0; i < list.size() && result.size() < limit; i++) {
            if (!list[i].isSame(trip)) {
                result.add(list[i]);
            }
        }
        return result;
    }

    private function persist() as Void {
        var saved = [] as Array<Dictionary>;
        for (var i = 0; i < trips.size(); i++) {
            saved.add(trips[i].toDictionary());
        }
        Storage.setValue(StorageKeys.FAVOURITES, saved as Array<Storage.ValueType>);
    }
}
