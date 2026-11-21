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
        if (!location.allowed) {
            return get(Rez.Strings.MyLocationOff);
        }
        return get(location.getCoordinates() != null ? Rez.Strings.MyLocation : Rez.Strings.MyLocationWaiting);
    }

    function version(number as String) as String {
        return get(Rez.Strings.Version) + " " + number;
    }

    //! Name, version and the data sources the app must credit.
    function about(number as String) as String {
        return get(Rez.Strings.AppName) + " " + number + "\n" + get(Rez.Strings.AboutSources);
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

    //! The outcome of the last search over Wi-Fi, or what the item does
    function wifiState(result as WifiResult?) as String {
        if (result == null) {
            return get(Rez.Strings.WifiHint);
        }
        var failure = result.error;
        if (failure != null) {
            return error(failure);
        }
        if (result.found == 0) {
            return get(Rez.Strings.NothingFound);
        }
        return get(Rez.Strings.WifiSaved) + " " + clock(result.time);
    }

    //! What went wrong, in words; the number only for an unknown cause.
    function error(error as ApiError) as String {
        var known = errorText(error);
        if (known != null) {
            return get(known);
        }
        if (error.code > 0) {
            return get(Rez.Strings.ErrorServer) + " " + error.code;
        }
        return get(Rez.Strings.ErrorGeneric) + " " + error.code;
    }

    //! The text of a known cause: a code of the proxy (docs/API.md) or of
    //! the watch's communication layer (negative numbers).
    function errorText(error as ApiError) as ResourceId? {
        var serverCode = error.serverCode;
        if (serverCode != null) {
            if (serverCode.equals("bad_key")) {
                return Rez.Strings.ErrorKey;
            }
            if (serverCode.equals("bad_request") || serverCode.equals("not_found")) {
                return Rez.Strings.ErrorRequest;
            }
            if (serverCode.equals("rate_limited") || serverCode.equals("upstream_429")) {
                return Rez.Strings.ErrorBusy;
            }
            if (serverCode.find("upstream") == 0) {
                return Rez.Strings.ErrorSource;
            }
        }
        switch (error.code) {
            // A bare 429 comes from a rate limit in front of the proxy.
            case 429:
                return Rez.Strings.ErrorBusy;
            case Communications.BLE_CONNECTION_UNAVAILABLE:
            case Communications.BLE_ERROR:
            case Communications.BLE_UNKNOWN_SEND_ERROR:
                return Rez.Strings.ErrorPhone;
            case Communications.BLE_HOST_TIMEOUT:
            case Communications.BLE_SERVER_TIMEOUT:
            case Communications.NETWORK_REQUEST_TIMED_OUT:
            case Communications.REQUEST_CONNECTION_DROPPED:
                return Rez.Strings.ErrorTimeout;
            case Communications.BLE_REQUEST_CANCELLED:
            case Communications.REQUEST_CANCELLED:
            case Communications.BLE_QUEUE_FULL:
                return Rez.Strings.ErrorCancelled;
            case Communications.NETWORK_RESPONSE_TOO_LARGE:
            case Communications.NETWORK_RESPONSE_OUT_OF_MEMORY:
            case Communications.STORAGE_FULL:
                return Rez.Strings.ErrorTooLarge;
            case Communications.BLE_NO_DATA:
            case Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE:
            case Communications.INVALID_HTTP_HEADER_FIELDS_IN_NETWORK_RESPONSE:
            case Communications.UNSUPPORTED_CONTENT_TYPE_IN_RESPONSE:
                return Rez.Strings.ErrorResponse;
            case Communications.SECURE_CONNECTION_REQUIRED:
                return Rez.Strings.ErrorHttps;
        }
        return null;
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
    //! "Departure" or "Arrive by": what the chosen time means
    function timeKind(trip as TripStore) as String {
        return get(trip.searchesByArrival() ? Rez.Strings.ArriveBy : Rez.Strings.Departure);
    }

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
    //! "15:50-20:21 4h31": the times and the travel time without the walk to
    //! the first stop. The label of a connection in the list.
    function connectionLabel(connection as Connection) as String {
        var minutes = connection.travelMinutes();
        return connection.departure + "-" + connection.arrival + " " + (minutes / 60) + get(Rez.Strings.Hours) + (minutes % 60).format("%02d");
    }

    function connectionTimes(connection as Connection) as String {
        return connection.departure + " - " + connection.arrival;
    }

    //! Characters of a menu sub-label that fit the fr955 display.
    const SUMMARY_BUDGET = 19;

    //! A departure this many minutes away is counted down to.
    const COUNTDOWN_MINUTES = 120;

    //! "in 7 min, 331>C", "departed, 331>C" or, for departures further away,
    //! just the lines: "674>538 +2". The travel time is in the label
    //! (`connectionLabel`). Short enough for one menu line; the full line
    //! names are in the detail of the connection. A leading "!" marks a
    //! tight change.
    function connectionSummary(connection as Connection, now as Number) as String {
        var when = countdown(connection.departureTime, now);
        var summary = when != null ? when : "";
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
            var separator = summary.length() > 1 ? ", " : "";
            summary += separator + joinLines(names, SUMMARY_BUDGET - summary.length() - separator.length());
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

    //! "120 m" for a nearby stop, otherwise its area; null when neither is known
    function stopDetail(stop as Stop) as String? {
        var distance = stop.distance;
        if (distance != null) {
            return distance + " m";
        }
        return stop.area.equals("") ? null : stop.area;
    }

    //! "alert at 16:14" when `alert` belongs to `connection`, otherwise "off"
    function alertState(connection as Connection, alert as DepartureAlert?) as String {
        if (alert == null || !alert.isFor(connection.departureTime, connection.lines)) {
            return get(Rez.Strings.AlertOff);
        }
        return get(Rez.Strings.AlertAt) + " " + clock(alert.alertTime());
    }

    //! "Departure in 5 min": title of the alert notification
    function alertTitle(leadMinutes as Number) as String {
        return get(Rez.Strings.DepartureIn) + " " + leadMinutes + " " + get(Rez.Strings.Minutes);
    }

    //! "16:19 331, Vestec,u Klimešů": the first ride, or the times without one
    function alertDetail(connection as Connection) as String {
        for (var i = 0; i < connection.legs.size(); i++) {
            var leg = connection.legs[i];
            if (!leg.isWalk()) {
                return leg.departure + " " + shortLine(leg.line) + ", " + leg.from;
            }
        }
        return connectionTimes(connection);
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
