import Toybox.Lang;

//! Results of a search kept on the watch so that they can be read later
//! without a connection to the phone.
class SavedSearch {

    var trip as Trip;
    //! Unix time of the search, in seconds.
    var savedAt as Number;
    var page as ConnectionsPage;

    function initialize(trip as Trip, savedAt as Number, page as ConnectionsPage) {
        self.trip = trip;
        self.savedAt = savedAt;
        self.page = page;
    }

    static function fromDictionary(data as Dictionary) as SavedSearch {
        return new SavedSearch(Trip.fromDictionary(data["r"] as Dictionary), data["s"] as Number,
            ConnectionsPage.fromDictionary(data["p"] as Dictionary));
    }

    function toDictionary() as Dictionary {
        return { "r" => trip.toDictionary(), "s" => savedAt, "p" => page.toDictionary() };
    }
}
