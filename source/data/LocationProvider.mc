import Toybox.Lang;
import Toybox.Position;
import Toybox.WatchUi;

//! Latitude and longitude in degrees.
typedef Coordinates as [Double, Double];

//! Tracks the watch position while the app runs.
class LocationProvider {

    private var _info as Position.Info?;
    private var _hadFix as Boolean = false;
    private var _listener as (Method() as Void)?;

    function initialize() {
    }

    function start() as Void {
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
    }

    function stop() as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
    }

    //! `listener` is called whenever a position becomes available or is lost.
    function setListener(listener as (Method() as Void)?) as Void {
        _listener = listener;
    }

    //! Current or last known position; null when the watch has none.
    function getCoordinates() as Coordinates? {
        var info = _info;
        if (info == null) {
            info = Position.getInfo();
        }
        var position = info.position;
        if (position == null || info.accuracy == Position.QUALITY_NOT_AVAILABLE) {
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

    //! Devices report "no position" as out-of-range values or as 0,0.
    static function isValid(latitude as Double, longitude as Double) as Boolean {
        if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
            return false;
        }
        return latitude != 0 || longitude != 0;
    }
}
