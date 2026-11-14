import Toybox.Lang;

//! Everything a connection search needs, prepared from the planned trip. It
//! is stored for a search over Wi-Fi, which runs after the app has closed.
class ConnectionQuery {

    var trip as Trip;
    //! Stop id or "lat,lon" of the position when the query was made.
    var origin as String;
    var departureTime as Number?;
    var arriveBy as Boolean;
    var filters as SearchFilters;

    function initialize(trip as Trip, origin as String, departureTime as Number?, arriveBy as Boolean, filters as SearchFilters) {
        self.trip = trip;
        self.origin = origin;
        self.departureTime = departureTime;
        self.arriveBy = arriveBy;
        self.filters = filters;
    }

    static function fromDictionary(data as Dictionary) as ConnectionQuery {
        return new ConnectionQuery(Trip.fromDictionary(data["r"] as Dictionary), data["o"] as String, data["t"] as Number?,
            (data["a"] as Number?) == 1, SearchFilters.fromDictionary(data["x"] as Dictionary));
    }

    function toDictionary() as Dictionary {
        var data = { "r" => trip.toDictionary(), "o" => origin, "x" => filters.toDictionary() } as Dictionary<String, Object>;
        var time = departureTime;
        if (time != null) {
            data["t"] = time;
        }
        if (arriveBy) {
            data["a"] = 1;
        }
        return data as Dictionary;
    }
}
