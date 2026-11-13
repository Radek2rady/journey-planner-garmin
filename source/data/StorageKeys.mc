import Toybox.Lang;

//! Storage keys read by both the full app and the glance.
(:glance)
module StorageKeys {
    const FAVOURITES = "favourites";
    //! Saved searches live in slots "search0", "search1", ...
    const SEARCH_PREFIX = "search";
}
