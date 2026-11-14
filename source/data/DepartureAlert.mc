import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Time;

//! An alert some minutes before the departure of a chosen connection. It is
//! shown by `AlertService` in the background, also when the app is closed.
//! The texts are prepared by the app, because the background service loads
//! no resources. Only one alert exists at a time: the watch keeps a single
//! scheduled background event per app.
(:background)
class DepartureAlert {

    private static const KEY = "alert";

    //! Departure of the connection, Unix seconds.
    var departureTime as Number;
    var leadMinutes as Number;
    //! Lines of the connection; with the time it identifies the connection.
    var lines as String;
    var title as String;
    var detail as String;

    function initialize(departureTime as Number, leadMinutes as Number, lines as String, title as String, detail as String) {
        self.departureTime = departureTime;
        self.leadMinutes = leadMinutes;
        self.lines = lines;
        self.title = title;
        self.detail = detail;
    }

    function alertTime() as Number {
        return departureTime - leadMinutes * 60;
    }

    function isFor(departureTime as Number, lines as String) as Boolean {
        return self.departureTime == departureTime && self.lines.equals(lines);
    }

    //! The lead time after `current` minutes in the cycle 5, 10, 15, off (0),
    //! skipping lead times whose alert would be at or before `now`.
    static function nextLead(current as Number, departureTime as Number, now as Number) as Number {
        var leads = [5, 10, 15] as Array<Number>;
        for (var i = 0; i < leads.size(); i++) {
            if (leads[i] > current && departureTime - leads[i] * 60 > now) {
                return leads[i];
            }
        }
        return 0;
    }

    static function fromDictionary(data as Dictionary) as DepartureAlert {
        return new DepartureAlert(data["t"] as Number, data["l"] as Number, data["r"] as String, data["h"] as String, data["b"] as String);
    }

    function toDictionary() as Dictionary {
        return { "t" => departureTime, "l" => leadMinutes, "r" => lines, "h" => title, "b" => detail };
    }

    //! The stored alert, whether or not it has already been shown.
    static function load() as DepartureAlert? {
        var saved = Storage.getValue(KEY) as Dictionary?;
        return saved != null ? fromDictionary(saved) : null;
    }

    //! The alert still to come; a past one is deleted. Foreground only.
    static function upcoming(now as Number) as DepartureAlert? {
        var alert = load();
        if (alert != null && alert.alertTime() <= now) {
            Storage.deleteValue(KEY);
            return null;
        }
        return alert;
    }

    //! Stores `alert` and schedules it, replacing any other. Returns false
    //! when the watch refuses the time. Foreground only.
    static function schedule(alert as DepartureAlert) as Boolean {
        try {
            Background.registerForTemporalEvent(new Time.Moment(alert.alertTime()));
        } catch (e) {
            return false;
        }
        Storage.setValue(KEY, alert.toDictionary() as Dictionary<Storage.KeyType, Storage.ValueType>);
        return true;
    }

    //! Foreground only.
    static function cancel() as Void {
        Background.deleteTemporalEvent();
        Storage.deleteValue(KEY);
    }
}
