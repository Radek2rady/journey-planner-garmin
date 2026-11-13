import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;

//! A failed request: HTTP status or negative Communications error code,
//! plus the error code sent by the proxy, when there is one.
class ApiError {

    var code as Number;
    var serverCode as String?;

    function initialize(code as Number, serverCode as String?) {
        self.code = code;
        self.serverCode = serverCode;
    }
}

typedef ResponseData as Dictionary or String or PersistedContent.Iterator or Null;
typedef StopsCallback as Method(stops as Array<Stop>?, error as ApiError?) as Void;
typedef ConnectionsCallback as Method(page as ConnectionsPage?, error as ApiError?) as Void;
typedef BoardCallback as Method(board as DepartureBoard?, error as ApiError?) as Void;

//! Client of the proxy (docs/API.md). One request of each kind may be in
//! flight; a newer request replaces the callback of an older one.
class TransitApi {

    private var _stopsCallback as StopsCallback?;
    private var _connectionsCallback as ConnectionsCallback?;
    private var _boardCallback as BoardCallback?;

    function initialize() {
    }

    //! Finds stops by name. `near` only ranks nearby stops higher.
    function searchStops(query as String, near as Coordinates?, callback as StopsCallback) as Void {
        var params = { "q" => query } as Dictionary<String, String>;
        if (near != null) {
            params["lat"] = formatDegrees(near[0]);
            params["lon"] = formatDegrees(near[1]);
        }
        _stopsCallback = callback;
        get("/stops", params, method(:onStopsResponse));
    }

    //! Finds connections departing now, or the page identified by `cursor`.
    //! `origin` is a stop id or "lat,lon".
    //! `departureTime` is in Unix seconds, null means now. A `cursor` continues
    //! an earlier search and takes precedence over the time.
    //! The filters are sent with a `cursor` as well.
    function searchConnections(origin as String, destinationId as String, departureTime as Number?, filters as SearchFilters, cursor as String?, callback as ConnectionsCallback) as Void {
        var params = { "from" => origin, "to" => destinationId } as Dictionary<String, String>;
        if (cursor != null) {
            params["c"] = cursor;
        } else if (departureTime != null) {
            params["t"] = departureTime.toString();
        }
        var maxTransfers = filters.maxTransfers;
        if (maxTransfers != null) {
            params["x"] = maxTransfers.toString();
        }
        if (!filters.vehicles.equals(SearchFilters.ALL_VEHICLES)) {
            params["v"] = filters.vehicles;
        }
        _connectionsCallback = callback;
        get("/plan", params, method(:onConnectionsResponse));
    }

    static function formatCoordinates(coordinates as Coordinates) as String {
        return formatDegrees(coordinates[0]) + "," + formatDegrees(coordinates[1]);
    }

    //! Departure board of the stop `stopId`, or of the stop nearest to `near`
    //! when no stop is given. A `cursor` continues the board of `stopId`.
    function searchDepartures(stopId as String?, near as Coordinates?, cursor as String?, callback as BoardCallback) as Void {
        var params = {} as Dictionary<String, String>;
        if (stopId != null) {
            params["stop"] = stopId;
        } else if (near != null) {
            params["lat"] = formatDegrees(near[0]);
            params["lon"] = formatDegrees(near[1]);
        }
        if (cursor != null) {
            params["c"] = cursor;
        }
        _boardCallback = callback;
        get("/departures", params, method(:onDeparturesResponse));
    }

    function onDeparturesResponse(code as Number, data as ResponseData) as Void {
        var callback = _boardCallback;
        _boardCallback = null;
        if (callback == null) {
            return;
        }
        if (code != 200 || !(data instanceof Dictionary)) {
            callback.invoke(null, toError(code, data));
            return;
        }
        callback.invoke(DepartureBoard.fromDictionary(data), null);
    }

    function onStopsResponse(code as Number, data as ResponseData) as Void {
        var callback = _stopsCallback;
        _stopsCallback = null;
        if (callback == null) {
            return;
        }
        if (code != 200 || !(data instanceof Dictionary)) {
            callback.invoke(null, toError(code, data));
            return;
        }
        var stops = [] as Array<Stop>;
        var raw = data["s"] as Array<Dictionary>;
        for (var i = 0; i < raw.size(); i++) {
            stops.add(Stop.fromDictionary(raw[i]));
        }
        callback.invoke(stops, null);
    }

    function onConnectionsResponse(code as Number, data as ResponseData) as Void {
        var callback = _connectionsCallback;
        _connectionsCallback = null;
        if (callback == null) {
            return;
        }
        if (code != 200 || !(data instanceof Dictionary)) {
            callback.invoke(null, toError(code, data));
            return;
        }
        callback.invoke(ConnectionsPage.fromDictionary(data), null);
    }

    private function get(path as String, params as Dictionary<String, String>, callback as Method(code as Number, data as ResponseData) as Void) as Void {
        if (!BuildConfig.PROXY_KEY.equals("")) {
            params["k"] = BuildConfig.PROXY_KEY;
        }
        Communications.makeWebRequest(
            BuildConfig.PROXY_URL + path,
            params as Dictionary<Object, Object>,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            callback
        );
    }

    private function toError(code as Number, data as ResponseData) as ApiError {
        var serverCode = null;
        if (data instanceof Dictionary) {
            serverCode = data["e"] as String?;
        }
        return new ApiError(code, serverCode);
    }

    //! Five decimals are about one metre, plenty for stop search.
    private static function formatDegrees(value as Double) as String {
        return value.format("%.5f");
    }
}
