import Toybox.Application;
import Toybox.Lang;

//! The last searches with their results, one per trip, persisted across app
//! launches. Every search has its own storage slot to stay well below the
//! size limit of a single stored value.
class SavedSearches {

    private const KEY_PREFIX = "search";
    //! Slots of the first storage format, which kept names only.
    private const LEGACY_KEY_PREFIX = "saved";
    private const LEGACY_SLOTS = 10;

    //! Most recent first.
    var searches as Array<SavedSearch> = [] as Array<SavedSearch>;

    function initialize() {
    }

    function load() as Void {
        searches = [] as Array<SavedSearch>;
        for (var i = 0; i < LEGACY_SLOTS; i++) {
            Storage.deleteValue(LEGACY_KEY_PREFIX + i);
        }
        for (var i = 0; i < Config.MAX_SAVED_SEARCHES; i++) {
            var saved = Storage.getValue(KEY_PREFIX + i) as Dictionary?;
            if (saved != null) {
                searches.add(SavedSearch.fromDictionary(saved));
            }
        }
    }

    function save(search as SavedSearch) as Void {
        searches = withSaved(searches, search, Config.MAX_SAVED_SEARCHES);
        try {
            for (var i = 0; i < Config.MAX_SAVED_SEARCHES; i++) {
                if (i < searches.size()) {
                    Storage.setValue(KEY_PREFIX + i, searches[i].toDictionary() as Dictionary<Storage.KeyType, Storage.ValueType>);
                } else {
                    Storage.deleteValue(KEY_PREFIX + i);
                }
            }
        } catch (e) {
            // Storage is full: the results stay available until the app closes.
        }
    }

    //! Returns `list` with `search` at the front, replacing an older search
    //! of the same trip, capped at `limit`.
    static function withSaved(list as Array<SavedSearch>, search as SavedSearch, limit as Number) as Array<SavedSearch> {
        var result = [search] as Array<SavedSearch>;
        for (var i = 0; i < list.size() && result.size() < limit; i++) {
            if (!list[i].trip.isSame(search.trip)) {
                result.add(list[i]);
            }
        }
        return result;
    }
}
