import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Picks the departure time of the search. The first menu offers "now" and
//! the hours of the next day; "another day" leads to a date further ahead.
//! Every path ends with the minutes.
module DepartureMenu {

    const HOURS_AHEAD = 24;
    //! The timetables of the data source reach about 11 days ahead.
    const DAYS_AHEAD = 10;
    const MINUTE_STEP = 15;
    const SECONDS_PER_DAY = 86400;

    //! Start of the hour `offset` hours after the one that contains `now`,
    //! which is `minute` minutes and `second` seconds past the hour.
    function hourStart(now as Number, minute as Number, second as Number, offset as Number) as Number {
        return now - minute * 60 - second + offset * 3600;
    }

    //! Whole days between the day starting at `todayStart` and `time`:
    //! 0 is today, 1 tomorrow.
    function dayOffset(time as Number, todayStart as Number) as Number {
        return Math.floor((time - todayStart).toFloat() / SECONDS_PER_DAY).toNumber();
    }

    //! `onChanged` is called after the departure time has been updated.
    function push(onChanged as Method() as Void) as Void {
        var now = Time.now().value();
        var info = Gregorian.info(new Time.Moment(now), Time.FORMAT_SHORT);
        var menu = new WatchUi.Menu2({ :title => Rez.Strings.Departure });
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.Now, null, :now, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.OtherDay, null, :day, null));
        addHours(menu, hourStart(now, info.min, info.sec, 0));
        WatchUi.pushView(menu, new DepartureMenuDelegate(onChanged), WatchUi.SLIDE_LEFT);
    }

    //! The days after today; selecting one leads to its hours.
    function pushDays(onChanged as Method() as Void) as Void {
        var today = Time.today().value();
        var menu = new WatchUi.Menu2({ :title => Rez.Strings.Departure });
        for (var i = 1; i <= DAYS_AHEAD; i++) {
            var day = today + i * SECONDS_PER_DAY;
            menu.addItem(new WatchUi.MenuItem(Texts.date(day), i == 1 ? Rez.Strings.Tomorrow : null, day, null));
        }
        WatchUi.pushView(menu, new DepartureDaysDelegate(onChanged), WatchUi.SLIDE_LEFT);
    }

    //! The hours of the day starting at `dayStart`.
    function pushHours(dayStart as Number, onChanged as Method() as Void) as Void {
        var menu = new WatchUi.Menu2({ :title => Texts.date(dayStart) });
        addHours(menu, dayStart);
        // Minutes, hours, days and the first menu close after the choice.
        WatchUi.pushView(menu, new DepartureHoursDelegate(onChanged, 4), WatchUi.SLIDE_LEFT);
    }

    //! Last step: the minutes within the hour starting at `hour`. After the
    //! choice `depth` views are closed, back to where the selection began.
    function pushMinutes(hour as Number, onChanged as Method() as Void, depth as Number) as Void {
        var menu = new WatchUi.Menu2({ :title => Texts.day(hour) });
        for (var minute = 0; minute < 60; minute += MINUTE_STEP) {
            var time = hour + minute * 60;
            menu.addItem(new WatchUi.MenuItem(Texts.clock(time), null, time, null));
        }
        WatchUi.pushView(menu, new DepartureMinutesDelegate(onChanged, depth), WatchUi.SLIDE_LEFT);
    }

    //! Adds the 24 hours that begin at `firstHour`; the item id is the start
    //! of the hour in Unix seconds.
    function addHours(menu as Menu2, firstHour as Number) as Void {
        for (var i = 0; i < HOURS_AHEAD; i++) {
            var hour = firstHour + i * 3600;
            menu.addItem(new WatchUi.MenuItem(Texts.clock(hour), Texts.day(hour), hour, null));
        }
    }
}

//! First menu: now, another day, or an hour of the next 24.
class DepartureMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _onChanged as Method() as Void;

    function initialize(onChanged as Method() as Void) {
        Menu2InputDelegate.initialize();
        _onChanged = onChanged;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id == :now) {
            getServices().trip.departureTime = null;
            _onChanged.invoke();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        } else if (id == :day) {
            DepartureMenu.pushDays(_onChanged);
        } else if (id instanceof Number) {
            DepartureMenu.pushMinutes(id, _onChanged, 2);
        }
    }
}

class DepartureDaysDelegate extends WatchUi.Menu2InputDelegate {

    private var _onChanged as Method() as Void;

    function initialize(onChanged as Method() as Void) {
        Menu2InputDelegate.initialize();
        _onChanged = onChanged;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number) {
            DepartureMenu.pushHours(id, _onChanged);
        }
    }
}

class DepartureHoursDelegate extends WatchUi.Menu2InputDelegate {

    private var _onChanged as Method() as Void;
    private var _depth as Number;

    function initialize(onChanged as Method() as Void, depth as Number) {
        Menu2InputDelegate.initialize();
        _onChanged = onChanged;
        _depth = depth;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number) {
            DepartureMenu.pushMinutes(id, _onChanged, _depth);
        }
    }
}

class DepartureMinutesDelegate extends WatchUi.Menu2InputDelegate {

    private var _onChanged as Method() as Void;
    private var _depth as Number;

    function initialize(onChanged as Method() as Void, depth as Number) {
        Menu2InputDelegate.initialize();
        _onChanged = onChanged;
        _depth = depth;
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number) {
            getServices().trip.departureTime = id;
            _onChanged.invoke();
            for (var i = 1; i < _depth; i++) {
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
    }
}
