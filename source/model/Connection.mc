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
    //! Station of the boarding stop; null for walks and older saved data.
    var fromId as String?;
    //! Departure in Unix seconds, including the delay; 0 when unknown.
    var departureTime as Number = 0;

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
        leg.fromId = data["i"] as String?;
        var departureTime = data["s"] as Number?;
        if (departureTime != null) {
            leg.departureTime = departureTime;
        }
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
        var station = fromId;
        if (station != null) {
            data["i"] = station;
        }
        if (departureTime != 0) {
            data["s"] = departureTime;
        }
        return data as Dictionary;
    }

    //! Minutes from `earlier` to `later`, both "HH:MM"; a later time before
    //! the earlier one is taken as the next day.
    static function minutesBetween(earlier as String, later as String) as Number {
        var minutes = clockMinutes(later) - clockMinutes(earlier);
        return minutes < 0 ? minutes + 24 * 60 : minutes;
    }

    private static function clockMinutes(time as String) as Number {
        var colon = time.find(":");
        if (colon == null) {
            return 0;
        }
        var hours = time.substring(0, colon);
        var minutes = time.substring(colon + 1, null);
        if (hours == null || minutes == null) {
            return 0;
        }
        var h = hours.toNumber();
        var m = minutes.toNumber();
        return (h != null ? h : 0) * 60 + (m != null ? m : 0);
    }
}

//! A change between two rides of a connection.
class Transfer {

    //! A change with less spare time than this, after walking, is tight.
    static const TIGHT_SPARE_MINUTES = 3;

    //! From the arrival of the previous ride to the departure of `ride`.
    var minutes as Number;
    //! Walking between the two rides.
    var walkMinutes as Number;
    //! The ride boarded at this change.
    var ride as Leg;

    function initialize(minutes as Number, walkMinutes as Number, ride as Leg) {
        self.minutes = minutes;
        self.walkMinutes = walkMinutes;
        self.ride = ride;
    }

    function spareMinutes() as Number {
        return minutes - walkMinutes;
    }

    function isTight() as Boolean {
        return spareMinutes() < TIGHT_SPARE_MINUTES;
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

    //! The changes between rides, in travel order. Cancelled rides count:
    //! the change is planned around them.
    function transfers() as Array<Transfer> {
        var result = [] as Array<Transfer>;
        var previous = null as Leg?;
        var walking = 0;
        for (var i = 0; i < legs.size(); i++) {
            var leg = legs[i];
            if (leg.isWalk()) {
                walking += leg.walkMinutes;
                continue;
            }
            if (previous != null) {
                result.add(new Transfer(Leg.minutesBetween(previous.arrival, leg.departure), walking, leg));
            }
            previous = leg;
            walking = 0;
        }
        return result;
    }

    //! Minutes from the departure of the first ride to the arrival: the
    //! journey without the walk to the first stop. The whole duration when
    //! there is no ride.
    function travelMinutes() as Number {
        for (var i = 0; i < legs.size(); i++) {
            if (!legs[i].isWalk()) {
                return Leg.minutesBetween(legs[i].departure, arrival);
            }
        }
        return durationMinutes;
    }

    function hasTightTransfer() as Boolean {
        var changes = transfers();
        for (var i = 0; i < changes.size(); i++) {
            if (changes[i].isTight()) {
                return true;
            }
        }
        return false;
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
