import Toybox.Application;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Application entry point. Runs in two modes: as a glance in the glance
//! list (64 kB, only `(:glance)` code is loaded) and as the full app. The
//! services are therefore created on first use in the full app, never in
//! the glance; UI code reaches them through getServices().
(:glance, :background)
class TransitApp extends Application.AppBase {

    //! `AppServices` once the full app has started; typed loosely because the
    //! class is not loaded in glance mode.
    var services as Object?;

    function initialize() {
        AppBase.initialize();
    }

    //! Runs in both modes; services exist only in the full app.
    (:typecheck([disableGlanceCheck, disableBackgroundCheck]))
    function onStop(state as Dictionary?) as Void {
        var started = services;
        if (started != null) {
            (started as AppServices).stop();
        }
    }

    //! Called only in the full app, where all code is loaded.
    (:typecheck([disableGlanceCheck, disableBackgroundCheck]))
    function getInitialView() as [Views] or [Views, InputDelegates] {
        getServices();
        return [new HomeView(), new HomeDelegate()];
    }

    //! Runs a search over Wi-Fi; see `WifiSearch`. Called in sync mode only.
    (:typecheck([disableGlanceCheck, disableBackgroundCheck]))
    function getSyncDelegate() as Communications.SyncDelegate? {
        return new WifiSyncDelegate();
    }

    //! Shows the departure alert; see `DepartureAlert`. Never called in a glance.
    (:typecheck(disableGlanceCheck))
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new AlertService()];
    }

    (:typecheck(disableBackgroundCheck))
    function getGlanceView() as [GlanceView] or [GlanceView, GlanceViewDelegate] or Null {
        return [new TransitGlance()];
    }
}

//! Glance in the watch's glance list: the destination of the first favourite
//! trip and its next departure from the last saved search; the app name
//! without favourites. START on it opens the full app. The fr955 redraws a
//! glance only now and then (when shown, at most every 30 s), so the
//! countdown is computed at drawing time, not by a timer.
(:glance)
class TransitGlance extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var now = Time.now().value();
        var next = GlanceData.nextOfFavourite(now);
        var height = dc.getHeight();
        var width = dc.getWidth();
        var font = Graphics.FONT_GLANCE;
        var title = WatchUi.loadResource(Rez.Strings.AppName) as String;
        var detail = TextFit.firstThatFits(dc, [
            WatchUi.loadResource(Rez.Strings.GlanceHint) as String,
            WatchUi.loadResource(Rez.Strings.GlanceHintShort) as String
        ] as Array<String>, font, width);
        if (next != null) {
            title = next.destination;
            var time = next.departureTime;
            detail = time != null ? GlanceText.departure(time, now) : WatchUi.loadResource(Rez.Strings.GlanceSearch) as String;
        }
        var left = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, height * 0.3, font, TextFit.keepStart(dc, title, font, width), left);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, height * 0.72, font, TextFit.keepStart(dc, detail, font, width), left);
    }
}

//! Text of the glance; the full app's `Texts` is not loaded in glance mode.
(:glance)
module GlanceText {

    //! A departure further away than this shows its time only.
    const COUNTDOWN_MINUTES = 120;

    //! "16:19, in 7 min", "16:19, now", or "16:19" when further away.
    function departure(time as Number, now as Number) as String {
        var info = Gregorian.info(new Time.Moment(time), Time.FORMAT_SHORT);
        var text = (info.hour as Number).format("%d") + ":" + (info.min as Number).format("%02d");
        var minutes = (time - now) / 60;
        if (minutes == 0) {
            return text + ", " + WatchUi.loadResource(Rez.Strings.Now);
        }
        if (minutes > 0 && minutes < COUNTDOWN_MINUTES) {
            return text + ", " + WatchUi.loadResource(Rez.Strings.In) + " " + minutes + " " + WatchUi.loadResource(Rez.Strings.Minutes);
        }
        return text;
    }
}

//! Long-lived services of the full app.
class AppServices {

    var api as TransitApi = new TransitApi();
    var location as LocationProvider = new LocationProvider();
    var trip as TripStore = new TripStore();
    var savedSearches as SavedSearches = new SavedSearches();
    var favourites as Favourites = new Favourites();

    function initialize() {
        trip.load();
        savedSearches.load();
        favourites.load();
        location.start();
    }

    function stop() as Void {
        location.stop();
    }
}

(:glance)
function getApp() as TransitApp {
    return Application.getApp() as TransitApp;
}

//! Services of the full app, created on first use.
function getServices() as AppServices {
    var app = getApp();
    var services = app.services;
    if (services == null) {
        services = new AppServices();
        app.services = services;
    }
    return services as AppServices;
}
