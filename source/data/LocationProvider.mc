import Toybox.Lang;
import Toybox.Application.Storage;
import Toybox.Position;
import Toybox.Time;
import Toybox.WatchUi;

//! Latitude and longitude in degrees.
typedef Coordinates as [Double, Double];

//! Tracks the watch position while the app runs, once the user has allowed
//! it. Until then no position is read and none leaves the watch.
class LocationProvider {

    private const KEY_ALLOWED = "locationAllowed";
    //! Older fixes no longer say where the watch is.
    static const MAX_AGE_S = 120;

    var allowed as Boolean;
    private var _info as Position.Info?;
    private var _hadFix as Boolean = false;
    private var _listener as (Method() as Void)?;

    function initialize() {
        var stored = Storage.getValue(KEY_ALLOWED);
        allowed = stored instanceof Boolean && stored;
    }

    //! Remembers the user's consent and starts tracking.
    function allow() as Void {
        allowed = true;
        Storage.setValue(KEY_ALLOWED, true);
        start();
    }

    function start() as Void {
        if (!allowed) {
            return;
        }
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
    }

    function stop() as Void {
        if (!allowed) {
            return;
        }
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
    }

    //! `listener` is called whenever a position becomes available or is lost.
    function setListener(listener as (Method() as Void)?) as Void {
        _listener = listener;
    }

    //! Current or last known position; null when the watch has none.
    function getCoordinates() as Coordinates? {
        if (!allowed) {
            return null;
        }
        var info = _info;
        if (info == null) {
            info = Position.getInfo();
        }
        var position = info.position;
        var when = info.when;
        var age = when != null ? Time.now().value() - when.value() : null;
        if (position == null || !isFresh(info.accuracy, age)) {
            return null;
        }
        var degrees = position.toDegrees();
        return isValid(degrees[0], degrees[1]) ? degrees : null;
    }

    function onPosition(info as Position.Info) as Void {
        _info = info;
        var hasFix = getCoordinates() != null;
        if (hasFix == _hadFix) {
            return;
        }
        _hadFix = hasFix;
        var listener = _listener;
        if (listener != null) {
            listener.invoke();
        }
        WatchUi.requestUpdate();
    }

    //! A fix may stand for "here" only when the watch has one now: the last known position
    //! can be from another town and would search from there.
    static function isFresh(accuracy as Position.Quality, ageSeconds as Number?) as Boolean {
        if (accuracy == Position.QUALITY_NOT_AVAILABLE || accuracy == Position.QUALITY_LAST_KNOWN) {
            return false;
        }
        return ageSeconds == null || ageSeconds <= MAX_AGE_S;
    }

    //! Devices report "no position" as out-of-range values or as 0,0.
    static function isValid(latitude as Double, longitude as Double) as Boolean {
        if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
            return false;
        }
        return latitude != 0 || longitude != 0;
    }
}
