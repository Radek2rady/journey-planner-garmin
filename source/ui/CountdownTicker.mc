import Toybox.Lang;
import Toybox.Time;
import Toybox.Timer;

//! A list whose lines count down to a departure.
typedef CountdownList as interface {
    function refreshCountdowns(now as Number) as Void;
};

//! Keeps the countdowns of the visible list current with one shared timer,
//! however many lists are open below it.
module CountdownTicker {

    const REFRESH_MS = 30000;

    //! The open lists, the visible one last.
    var open as Array<CountdownList> = [] as Array<CountdownList>;
    var ticker as Timer.Timer?;

    //! Call when a list is pushed.
    function opened(list as CountdownList) as Void {
        open.add(list);
        if (ticker == null) {
            var timer = new Timer.Timer();
            timer.start(new Lang.Method(CountdownTicker, :onTick), REFRESH_MS, true);
            ticker = timer;
        }
    }

    //! Call when a list is popped.
    function closed(list as CountdownList) as Void {
        open.remove(list);
        var timer = ticker;
        if (open.size() == 0 && timer != null) {
            timer.stop();
            ticker = null;
        }
    }

    function onTick() as Void {
        if (open.size() > 0) {
            open[open.size() - 1].refreshCountdowns(Time.now().value());
        }
    }
}
