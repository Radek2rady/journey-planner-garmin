import Toybox.Application;
import Toybox.Lang;

//! What the glance shows: the first favourite trip and its next departure.
(:glance)
class NextDeparture {

    var destination as String;
    //! Unix seconds of the next departure; null when none is known.
    var departureTime as Number?;

    function initialize(destination as String) {
        self.destination = destination;
    }
}

//! Reads what the glance needs straight from storage, without the classes of
//! the full app, which are not loaded in glance mode (64 kB). The departures
//! come from the last saved search of the trip: no request is made, so they
//! are as fresh as that search.
(:glance)
module GlanceData {

    //! The first favourite trip with its next departure at or after `now`;
    //! null when there is no favourite.
    function nextOfFavourite(now as Number) as NextDeparture? {
        var favourites = Storage.getValue(StorageKeys.FAVOURITES) as Array<Dictionary>?;
        if (favourites == null || favourites.size() == 0) {
            return null;
        }
        var trip = favourites[0];
        var destination = trip["d"] as Dictionary;
        var result = new NextDeparture(destination["n"] as String);
        var connections = savedConnections(trip);
        if (connections != null) {
            var times = [] as Array<Number>;
            for (var i = 0; i < connections.size(); i++) {
                var time = connections[i]["s"] as Number?;
                times.add(time != null ? time : 0);
            }
            var next = firstUpcoming(times, now);
            if (next != null) {
                result.departureTime = times[next];
            }
        }
        return result;
    }

    //! Index of the first time at or after `now` in `times` (in departure
    //! order); 0 marks an unknown time and is skipped. Null when none is left.
    function firstUpcoming(times as Array<Number>, now as Number) as Number? {
        for (var i = 0; i < times.size(); i++) {
            if (times[i] != 0 && times[i] >= now) {
                return i;
            }
        }
        return null;
    }

    //! Connections of the saved search of `trip`; null when it has none.
    //! Slots are read one at a time to keep the memory use low.
    function savedConnections(trip as Dictionary) as Array<Dictionary>? {
        for (var i = 0; i < Config.MAX_SAVED_SEARCHES; i++) {
            var saved = Storage.getValue(StorageKeys.SEARCH_PREFIX + i) as Dictionary?;
            if (saved != null && sameTrip(saved["r"] as Dictionary, trip)) {
                return (saved["p"] as Dictionary)["c"] as Array<Dictionary>;
            }
        }
        return null;
    }

    //! Same stops at both ends; a missing origin means "my location".
    function sameTrip(a as Dictionary, b as Dictionary) as Boolean {
        return sameStop(a["d"] as Dictionary?, b["d"] as Dictionary?) && sameStop(a["o"] as Dictionary?, b["o"] as Dictionary?);
    }

    function sameStop(a as Dictionary?, b as Dictionary?) as Boolean {
        if (a == null || b == null) {
            return a == null && b == null;
        }
        return (a["i"] as String).equals(b["i"] as String);
    }
}
