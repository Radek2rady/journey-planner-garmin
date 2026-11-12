import Toybox.Lang;

//! Results of a search kept on the watch so that they can be read later
//! without a connection to the phone.
class SavedSearch {

    //! Names as they were shown when the search ran.
    var origin as String;
    var destination as String;
    //! Unix time of the search, in seconds.
    var savedAt as Number;
    var page as ConnectionsPage;

    function initialize(origin as String, destination as String, savedAt as Number, page as ConnectionsPage) {
        self.origin = origin;
        self.destination = destination;
        self.savedAt = savedAt;
        self.page = page;
    }

    function isSameTrip(other as SavedSearch) as Boolean {
        return origin.equals(other.origin) && destination.equals(other.destination);
    }

    static function fromDictionary(data as Dictionary) as SavedSearch {
        return new SavedSearch(data["o"] as String, data["t"] as String, data["s"] as Number,
            ConnectionsPage.fromDictionary(data["p"] as Dictionary));
    }

    function toDictionary() as Dictionary {
        return { "o" => origin, "t" => destination, "s" => savedAt, "p" => page.toDictionary() };
    }
}
