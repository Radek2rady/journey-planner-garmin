import Toybox.Lang;

//! A public transport stop. The dictionary form is shared by the proxy wire
//! format (docs/API.md) and by persistent storage.
class Stop {

    var id as String;
    var name as String;
    //! Municipality and district; may be empty.
    var area as String;
    //! Metres from the position of a nearby-stops search; null otherwise.
    //! Not stored: it is true only where the search was made.
    var distance as Number?;

    function initialize(id as String, name as String, area as String) {
        self.id = id;
        self.name = name;
        self.area = area;
    }

    static function fromDictionary(data as Dictionary) as Stop {
        var area = data["a"] as String?;
        var stop = new Stop(data["i"] as String, data["n"] as String, area != null ? area : "");
        stop.distance = data["m"] as Number?;
        return stop;
    }

    function toDictionary() as Dictionary<String, String> {
        return { "i" => id, "n" => name, "a" => area };
    }
}
