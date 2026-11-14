import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

//! Outcome of the last search over Wi-Fi.
class WifiResult {

    //! Unix seconds when the search finished.
    var time as Number;
    //! Number of connections found and saved.
    var found as Number;
    //! Why the search failed; null when it reached the proxy.
    var error as ApiError?;

    function initialize(time as Number, found as Number, error as ApiError?) {
        self.time = time;
        self.found = found;
        self.error = error;
    }
}

//! A connection search without the phone, over a Wi-Fi network saved in the
//! watch. The watch allows requests over Wi-Fi only in sync mode: the app
//! stores the query and asks for a sync, the watch closes the app and runs
//! `WifiSyncDelegate`, which saves the connections with the saved searches.
module WifiSearch {

    const KEY_QUERY = "wifiQuery";
    const KEY_RESULT = "wifiResult";

    enum Availability {
        AVAILABLE,
        //! The watch has no Wi-Fi.
        NO_WIFI,
        //! No Wi-Fi network is set up in the watch.
        NOT_SET_UP
    }

    function availability() as Availability {
        var wifi = System.getDeviceSettings().connectionInfo[:wifi];
        if (wifi == null) {
            return NO_WIFI;
        }
        return wifi.state == System.CONNECTION_STATE_NOT_INITIALIZED ? NOT_SET_UP : AVAILABLE;
    }

    //! Stores `query` and asks the watch for a sync, which closes the app.
    //! `message` is shown by the watch during the sync.
    function request(query as ConnectionQuery, message as String) as Void {
        Storage.setValue(KEY_QUERY, query.toDictionary() as Dictionary<Storage.KeyType, Storage.ValueType>);
        Storage.deleteValue(KEY_RESULT);
        if (Communications has :startSync2) {
            Communications.startSync2({ :message => message });
        } else {
            Communications.startSync();
        }
    }

    function pending() as ConnectionQuery? {
        var saved = Storage.getValue(KEY_QUERY) as Dictionary?;
        return saved != null ? ConnectionQuery.fromDictionary(saved) : null;
    }

    function result() as WifiResult? {
        var saved = Storage.getValue(KEY_RESULT) as Dictionary?;
        if (saved == null) {
            return null;
        }
        var code = saved["c"] as Number;
        var error = code == 200 ? null : new ApiError(code, saved["e"] as String?);
        return new WifiResult(saved["t"] as Number, saved["n"] as Number, error);
    }

    //! Records the outcome and forgets the query.
    function finish(found as Number, error as ApiError?) as Void {
        var data = { "t" => Time.now().value(), "n" => found, "c" => error != null ? error.code : 200 } as Dictionary<String, Number or String>;
        if (error != null && error.serverCode != null) {
            data["e"] = error.serverCode as String;
        }
        Storage.setValue(KEY_RESULT, data as Dictionary<Storage.KeyType, Storage.ValueType>);
        Storage.deleteValue(KEY_QUERY);
    }
}

//! Runs the stored query in sync mode and saves what it finds. Uses its own
//! API client and storage objects: the app's services would start the GPS.
class WifiSyncDelegate extends Communications.SyncDelegate {

    private var _api as TransitApi = new TransitApi();
    private var _query as ConnectionQuery?;

    function initialize() {
        SyncDelegate.initialize();
    }

    function isSyncNeeded() as Boolean {
        return WifiSearch.pending() != null;
    }

    function onStartSync() as Void {
        var query = WifiSearch.pending();
        _query = query;
        if (query == null) {
            Communications.notifySyncComplete(null);
            return;
        }
        Communications.notifySyncProgress(10);
        _api.searchConnections(query.origin, query.trip.destination.id, query.departureTime, query.arriveBy, query.filters, null, method(:onConnections));
    }

    function onConnections(page as ConnectionsPage?, error as ApiError?) as Void {
        var query = _query;
        var found = 0;
        if (page != null && query != null && page.connections.size() > 0) {
            found = page.connections.size();
            var saved = new SavedSearches();
            saved.load();
            // Later pages need the phone or another sync, so the cursor is not kept.
            saved.save(new SavedSearch(query.trip, Time.now().value(), new ConnectionsPage(page.connections, null)));
        }
        WifiSearch.finish(found, page != null ? null : error);
        Communications.notifySyncProgress(100);
        Communications.notifySyncComplete(null);
    }

    function onStopSync() as Void {
        Communications.cancelAllRequests();
        Communications.notifySyncComplete(null);
    }
}
