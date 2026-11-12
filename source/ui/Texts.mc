import Toybox.Communications;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Everything that turns data into text shown to the user. All wording comes
//! from string resources; nothing here is language-specific.
module Texts {

    function get(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }

    function originName(trip as TripStore, location as LocationProvider) as String {
        var origin = trip.origin;
        if (origin != null) {
            return origin.name;
        }
        return get(location.getCoordinates() != null ? Rez.Strings.MyLocation : Rez.Strings.MyLocationWaiting);
    }

    function destinationName(trip as TripStore) as String {
        var destination = trip.destination;
        return destination != null ? destination.name : get(Rez.Strings.NotSet);
    }

    function vehicle(code as String) as String {
        var names = {
            "bus" => Rez.Strings.VehicleBus,
            "tram" => Rez.Strings.VehicleTram,
            "metro" => Rez.Strings.VehicleMetro,
            "train" => Rez.Strings.VehicleTrain,
            "ferry" => Rez.Strings.VehicleFerry,
            "cable" => Rez.Strings.VehicleCable,
            "air" => Rez.Strings.VehicleAir
        } as Dictionary<String, ResourceId>;
        var id = names[code];
        return get(id != null ? id : Rez.Strings.VehicleOther);
    }

    function error(error as ApiError) as String {
        if (error.code == Communications.BLE_CONNECTION_UNAVAILABLE) {
            return get(Rez.Strings.ErrorPhone);
        }
        if (error.code == Communications.NETWORK_REQUEST_TIMED_OUT) {
            return get(Rez.Strings.ErrorTimeout);
        }
        var serverCode = error.serverCode;
        if (serverCode != null) {
            return get(Rez.Strings.ErrorServer) + " (" + serverCode + ")";
        }
        return get(Rez.Strings.ErrorGeneric) + " " + error.code;
    }

    //! "17:30", in the time zone of the watch
    function clock(time as Number) as String {
        var info = Gregorian.info(new Time.Moment(time), Time.FORMAT_SHORT);
        return info.hour.format("%02d") + ":" + info.min.format("%02d");
    }

    //! "Fri 13.11."; the weekday comes from the watch in its own language.
    function date(time as Number) as String {
        var moment = new Time.Moment(time);
        var numbers = Gregorian.info(moment, Time.FORMAT_SHORT);
        var weekday = Gregorian.info(moment, Time.FORMAT_MEDIUM).day_of_week as String;
        return weekday + " " + numbers.day + "." + (numbers.month as Number) + ".";
    }

    //! "today", "tomorrow", or the date for days further away
    function day(time as Number) as String {
        var offset = DepartureMenu.dayOffset(time, Time.today().value());
        if (offset == 0) {
            return get(Rez.Strings.Today);
        }
        return offset == 1 ? get(Rez.Strings.Tomorrow) : date(time);
    }

    //! "now", "today 17:30" or "Fri 13.11. 17:30"
    function departure(time as Number?) as String {
        if (time == null) {
            return get(Rez.Strings.Now);
        }
        return day(time) + " " + clock(time);
    }

    //! "Vestec > Opatov"
    function savedTrip(search as SavedSearch) as String {
        return search.origin + " > " + search.destination;
    }

    //! "12.11. 07:15", in the time zone of the watch
    function savedAt(search as SavedSearch) as String {
        var info = Gregorian.info(new Time.Moment(search.savedAt), Time.FORMAT_SHORT);
        return info.day + "." + (info.month as Number) + ". " + clock(search.savedAt);
    }

    //! "16:16 - 16:57"
    function connectionTimes(connection as Connection) as String {
        return connection.departure + " - " + connection.arrival;
    }

    //! "41 min, 331 > C"
    function connectionSummary(connection as Connection) as String {
        var summary = connection.durationMinutes + " " + get(Rez.Strings.Minutes);
        if (!connection.lines.equals("")) {
            summary += ", " + connection.lines;
        }
        return summary;
    }

    //! "Walk 3 min"
    function walk(leg as Leg) as String {
        return get(Rez.Strings.Walk) + " " + leg.walkMinutes + " " + get(Rez.Strings.Minutes);
    }

    function placeOrDestination(name as String) as String {
        return name.equals("") ? get(Rez.Strings.Destination) : name;
    }

    //! "16:19 Vestec,u Klimešů"
    function boarding(leg as Leg) as String {
        return leg.departure + " " + leg.from;
    }

    //! "Bus 331, +1 min, plat. B, to Háje"
    function boardingDetails(leg as Leg) as String {
        var details = vehicle(leg.vehicle) + " " + leg.line;
        if (leg.cancelled) {
            details = get(Rez.Strings.Cancelled) + " " + details;
        } else if (leg.delayMinutes != 0) {
            details += ", " + (leg.delayMinutes > 0 ? "+" : "") + leg.delayMinutes + " " + get(Rez.Strings.Minutes);
        }
        var platform = leg.platform;
        if (platform != null) {
            details += ", " + get(Rez.Strings.Platform) + " " + platform;
        }
        var headsign = leg.headsign;
        if (headsign != null) {
            details += ", " + get(Rez.Strings.Direction) + " " + headsign;
        }
        return details;
    }

    //! "16:33 Opatov"
    function alighting(leg as Leg) as String {
        return leg.arrival + " " + placeOrDestination(leg.to);
    }
}
