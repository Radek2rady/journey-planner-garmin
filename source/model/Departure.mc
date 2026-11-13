import Toybox.Lang;

//! One line of a departure board (docs/API.md, GET /departures).
class Departure {

    //! Vehicle code from the proxy ("bus", "train", ...).
    var vehicle as String;
    var line as String;
    //! Direction shown on the vehicle; may be empty.
    var headsign as String;
    //! Local time as "HH:MM", including the delay.
    var time as String;
    //! The same moment in Unix seconds.
    var departureTime as Number;
    var platform as String?;
    var delayMinutes as Number = 0;
    var cancelled as Boolean = false;

    function initialize(vehicle as String, line as String, headsign as String, time as String, departureTime as Number) {
        self.vehicle = vehicle;
        self.line = line;
        self.headsign = headsign;
        self.time = time;
        self.departureTime = departureTime;
    }

    static function fromDictionary(data as Dictionary) as Departure {
        var departure = new Departure(data["k"] as String, data["r"] as String, data["h"] as String,
            data["d"] as String, data["s"] as Number);
        departure.platform = data["p"] as String?;
        var delay = data["z"] as Number?;
        if (delay != null) {
            departure.delayMinutes = delay;
        }
        departure.cancelled = (data["x"] as Number?) != null;
        return departure;
    }
}

//! What leaves next from one stop.
class DepartureBoard {

    //! Empty when no stop was found near the position.
    var stopName as String;
    var stopId as String;
    var departures as Array<Departure>;
    //! Opaque cursor for later departures; null when there are none.
    var nextCursor as String?;

    function initialize(stopName as String, stopId as String, departures as Array<Departure>, nextCursor as String?) {
        self.stopName = stopName;
        self.stopId = stopId;
        self.departures = departures;
        self.nextCursor = nextCursor;
    }

    static function fromDictionary(data as Dictionary) as DepartureBoard {
        var departures = [] as Array<Departure>;
        var raw = data["d"] as Array<Dictionary>;
        for (var i = 0; i < raw.size(); i++) {
            departures.add(Departure.fromDictionary(raw[i]));
        }
        var cursor = data["c"] as String?;
        if (cursor != null && cursor.equals("")) {
            cursor = null;
        }
        return new DepartureBoard(data["n"] as String, data["i"] as String, departures, cursor);
    }
}
