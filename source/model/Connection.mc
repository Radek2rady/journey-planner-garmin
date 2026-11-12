import Toybox.Lang;

// The dictionary forms below are shared by the proxy wire format (docs/API.md)
// and by persistent storage.

//! One part of a connection: a ride on a single vehicle, or a walk.
class Leg {

    static const WALK = "walk";

    //! Vehicle code from the proxy ("bus", "train", ...) or WALK.
    var vehicle as String;
    var line as String = "";
    var from as String = "";
    var to as String = "";
    //! Local times as "HH:MM"; empty for walks.
    var departure as String = "";
    var arrival as String = "";
    //! Direction shown on the vehicle; null when unknown or same as `to`.
    var headsign as String?;
    var platform as String?;
    var delayMinutes as Number = 0;
    var cancelled as Boolean = false;
    var walkMinutes as Number = 0;

    function initialize(vehicle as String) {
        self.vehicle = vehicle;
    }

    function isWalk() as Boolean {
        return vehicle.equals(WALK);
    }

    static function fromDictionary(data as Dictionary) as Leg {
        var leg = new Leg(data["k"] as String);
        leg.to = data["t"] as String;
        if (leg.isWalk()) {
            leg.walkMinutes = data["m"] as Number;
            return leg;
        }
        leg.line = data["r"] as String;
        leg.from = data["f"] as String;
        leg.departure = data["d"] as String;
        leg.arrival = data["a"] as String;
        leg.headsign = data["h"] as String?;
        leg.platform = data["p"] as String?;
        var delay = data["z"] as Number?;
        if (delay != null) {
            leg.delayMinutes = delay;
        }
        leg.cancelled = (data["x"] as Number?) != null;
        return leg;
    }

    function toDictionary() as Dictionary {
        if (isWalk()) {
            return { "k" => vehicle, "t" => to, "m" => walkMinutes };
        }
        var data = { "k" => vehicle, "t" => to, "r" => line, "f" => from, "d" => departure, "a" => arrival } as Dictionary<String, String or Number>;
        var direction = headsign;
        if (direction != null) {
            data["h"] = direction;
        }
        var track = platform;
        if (track != null) {
            data["p"] = track;
        }
        if (delayMinutes != 0) {
            data["z"] = delayMinutes;
        }
        if (cancelled) {
            data["x"] = 1;
        }
        return data as Dictionary;
    }
}

//! A journey from origin to destination, possibly with transfers.
class Connection {

    var departure as String;
    var arrival as String;
    var durationMinutes as Number;
    //! Departure in Unix seconds; 0 when unknown (saved by an older version).
    var departureTime as Number = 0;
    //! Lines in travel order, e.g. "331 > C".
    var lines as String;
    var legs as Array<Leg>;

    function initialize(departure as String, arrival as String, durationMinutes as Number, lines as String, legs as Array<Leg>) {
        self.departure = departure;
        self.arrival = arrival;
        self.durationMinutes = durationMinutes;
        self.lines = lines;
        self.legs = legs;
    }

    static function fromDictionary(data as Dictionary) as Connection {
        var legs = [] as Array<Leg>;
        var rawLegs = data["l"] as Array<Dictionary>;
        for (var i = 0; i < rawLegs.size(); i++) {
            legs.add(Leg.fromDictionary(rawLegs[i]));
        }
        var connection = new Connection(data["d"] as String, data["a"] as String, data["m"] as Number, data["r"] as String, legs);
        var departureTime = data["s"] as Number?;
        if (departureTime != null) {
            connection.departureTime = departureTime;
        }
        return connection;
    }

    function toDictionary() as Dictionary {
        var rawLegs = [] as Array<Dictionary>;
        for (var i = 0; i < legs.size(); i++) {
            rawLegs.add(legs[i].toDictionary());
        }
        return { "d" => departure, "a" => arrival, "s" => departureTime, "m" => durationMinutes, "r" => lines, "l" => rawLegs };
    }
}

//! One page of search results.
class ConnectionsPage {

    var connections as Array<Connection>;
    //! Opaque cursor for the following page; null when there is none.
    var nextCursor as String?;

    function initialize(connections as Array<Connection>, nextCursor as String?) {
        self.connections = connections;
        self.nextCursor = nextCursor;
    }

    static function fromDictionary(data as Dictionary) as ConnectionsPage {
        var connections = [] as Array<Connection>;
        var raw = data["c"] as Array<Dictionary>;
        for (var i = 0; i < raw.size(); i++) {
            connections.add(Connection.fromDictionary(raw[i]));
        }
        var cursor = data["n"] as String?;
        if (cursor != null && cursor.equals("")) {
            cursor = null;
        }
        return new ConnectionsPage(connections, cursor);
    }

    function toDictionary() as Dictionary {
        var raw = [] as Array<Dictionary>;
        for (var i = 0; i < connections.size(); i++) {
            raw.add(connections[i].toDictionary());
        }
        var cursor = nextCursor;
        return { "c" => raw, "n" => cursor != null ? cursor : "" };
    }
}
