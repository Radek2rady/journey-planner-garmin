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

    //! "any", "direct only" or "max 1"
    function transfersFilter(filters as SearchFilters) as String {
        var limit = filters.maxTransfers;
        if (limit == null) {
            return get(Rez.Strings.FilterAny);
        }
        return limit == 0 ? get(Rez.Strings.FilterDirect) : get(Rez.Strings.FilterMax) + " " + limit;
    }

    //! "all", "trains only" or "without trains"
    function vehiclesFilter(filters as SearchFilters) as String {
        if (filters.vehicles.equals(SearchFilters.TRAINS_ONLY)) {
            return get(Rez.Strings.FilterTrains);
        }
        return get(filters.vehicles.equals(SearchFilters.NO_TRAINS) ? Rez.Strings.FilterNoTrains : Rez.Strings.FilterAllVehicles);
    }

    //! The filters in use, "direct only, trains only", or "off"
    function filters(filters as SearchFilters) as String {
        var parts = [] as Array<String>;
        if (filters.maxTransfers != null) {
            parts.add(transfersFilter(filters));
        }
        if (!filters.vehicles.equals(SearchFilters.ALL_VEHICLES)) {
            parts.add(vehiclesFilter(filters));
        }
        if (parts.size() == 0) {
            return get(Rez.Strings.FiltersOff);
        }
        return parts.size() == 1 ? parts[0] : parts[0] + ", " + parts[1];
    }

    //! Name of the origin stop, or "My location"
    function tripOrigin(trip as Trip) as String {
        var origin = trip.origin;
        return origin != null ? origin.name : get(Rez.Strings.MyLocation);
    }

    //! "Vestec > Opatov"
    function tripName(trip as Trip) as String {
        return tripOrigin(trip) + " > " + trip.destination.name;
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

    //! Characters of a menu sub-label that fit the fr955 display.
    const SUMMARY_BUDGET = 19;

    //! A departure this many minutes away is counted down to.
    const COUNTDOWN_MINUTES = 120;

    //! "in 7 min, 331>C", "departed, 331>C" or, for departures further away,
    //! "3h08, 674>538 +2" with the travel time. Short enough for one menu
    //! line; the full line names are in the detail of the connection. A
    //! leading "!" marks a tight change.
    function connectionSummary(connection as Connection, now as Number) as String {
        var summary = countdown(connection.departureTime, now);
        if (summary == null) {
            summary = duration(connection.durationMinutes);
        }
        if (connection.hasTightTransfer()) {
            summary = "!" + summary;
        }
        var names = [] as Array<String>;
        for (var i = 0; i < connection.legs.size(); i++) {
            var leg = connection.legs[i];
            if (!leg.isWalk()) {
                names.add(shortLine(leg.line));
            }
        }
        if (names.size() > 0) {
            summary += ", " + joinLines(names, SUMMARY_BUDGET - summary.length() - 2);
        }
        return summary;
    }

    //! "in 7 min", "now", "departed"; null when the departure is unknown or
    //! too far away for a countdown.
    function countdown(departureTime as Number, now as Number) as String? {
        if (departureTime == 0) {
            return null;
        }
        var seconds = departureTime - now;
        if (seconds < 0) {
            return get(Rez.Strings.Departed);
        }
        var minutes = seconds / 60;
        if (minutes >= COUNTDOWN_MINUTES) {
            return null;
        }
        return minutes == 0 ? get(Rez.Strings.Now) : get(Rez.Strings.In) + " " + duration(minutes);
    }

    //! "326 in 4 min", or "326 16:19" for a departure too far for a countdown.
    //! Train names are shortened; the full name is in `departureDetails`.
    function boardLine(departure as Departure, now as Number) as String {
        var when = countdown(departure.departureTime, now);
        return shortLine(departure.line) + " " + (when != null ? when : departure.time);
    }

    //! The direction, or the kind of vehicle when the direction is unknown
    function boardDirection(departure as Departure) as String {
        var direction = departure.headsign.equals("") ? vehicle(departure.vehicle) : departure.headsign;
        return departure.cancelled ? get(Rez.Strings.Cancelled) + " " + direction : direction;
    }

    //! All that is known about a departure, one fact per line
    function departureDetails(departure as Departure) as String {
        var details = departure.time;
        if (departure.cancelled) {
            details += " " + get(Rez.Strings.Cancelled);
        } else if (departure.delayMinutes != 0) {
            details += " (" + (departure.delayMinutes > 0 ? "+" : "") + departure.delayMinutes + " " + get(Rez.Strings.Minutes) + ")";
        }
        details += "\n" + vehicle(departure.vehicle) + " " + departure.line;
        if (!departure.headsign.equals("")) {
            details += "\n" + get(Rez.Strings.Direction) + " " + departure.headsign;
        }
        var platform = departure.platform;
        if (platform != null) {
            details += "\n" + get(Rez.Strings.Platform) + " " + platform;
        }
        return details;
    }

    //! "41 min" or "3h08"
    function duration(minutes as Number) as String {
        if (minutes < 60) {
            return minutes + " " + get(Rez.Strings.Minutes);
        }
        return (minutes / 60) + get(Rez.Strings.Hours) + (minutes % 60).format("%02d");
    }

    //! First word of a line name: "S21 (Os 15648)" gives "S21", "Os 20872"
    //! gives "Os", "331" stays.
    function shortLine(line as String) as String {
        var space = line.find(" ");
        if (space == null || space == 0) {
            return line;
        }
        return line.substring(0, space) as String;
    }

    //! Joins `names` with ">" while they fit `budget` characters and counts
    //! the rest: "674>538 +2". The first name is always kept.
    function joinLines(names as Array<String>, budget as Number) as String {
        var result = "";
        for (var i = 0; i < names.size(); i++) {
            var candidate = i == 0 ? names[i] : result + ">" + names[i];
            var left = names.size() - i - 1;
            var needed = candidate.length() + (left > 0 ? (" +" + left).length() : 0);
            if (i > 0 && needed > budget) {
                return result + " +" + (names.size() - i);
            }
            result = candidate;
        }
        return result;
    }

    //! "Change 4 min", or "! Change 1 min" when there is little time to spare
    function transfer(change as Transfer) as String {
        var text = get(Rez.Strings.Change) + " " + change.minutes + " " + get(Rez.Strings.Minutes);
        return change.isTight() ? "! " + text : text;
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
