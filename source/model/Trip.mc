import Toybox.Lang;

//! Where from and where to. Used for favourite trips and saved searches.
class Trip {

    //! null means "current location".
    var origin as Stop?;
    var destination as Stop;

    function initialize(origin as Stop?, destination as Stop) {
        self.origin = origin;
        self.destination = destination;
    }

    function isSame(other as Trip) as Boolean {
        var mine = origin;
        var theirs = other.origin;
        var sameOrigin = mine == null ? theirs == null : (theirs != null && mine.id.equals(theirs.id));
        return sameOrigin && destination.id.equals(other.destination.id);
    }

    static function fromDictionary(data as Dictionary) as Trip {
        var origin = data["o"] as Dictionary?;
        return new Trip(origin != null ? Stop.fromDictionary(origin) : null, Stop.fromDictionary(data["d"] as Dictionary));
    }

    function toDictionary() as Dictionary {
        var data = { "d" => destination.toDictionary() } as Dictionary<String, Dictionary>;
        var from = origin;
        if (from != null) {
            data["o"] = from.toDictionary();
        }
        return data as Dictionary;
    }
}
