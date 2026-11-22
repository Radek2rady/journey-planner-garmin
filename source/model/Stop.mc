import Toybox.Lang;

//! A public transport stop. The dictionary form is shared by the proxy wire
//! format (docs/API.md) and by persistent storage.
class Stop {

    var id as String;
    var name as String;
    //! Municipality and district; may be empty.
    var area as String;
    //! Vehicle code of what stops there ("train", "bus"...); null when unknown.
    var vehicle as String?;
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
        stop.vehicle = data["v"] as String?;
        return stop;
    }

    function toDictionary() as Dictionary<String, String> {
        var data = { "i" => id, "n" => name, "a" => area } as Dictionary<String, String>;
        var kind = vehicle;
        if (kind != null) {
            data["v"] = kind;
        }
        return data;
    }
}
