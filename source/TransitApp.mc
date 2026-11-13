import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Application entry point. Runs in two modes: as a glance in the glance
//! list (64 kB, only `(:glance)` code is loaded) and as the full app. The
//! services are therefore created on first use in the full app, never in
//! the glance; UI code reaches them through getServices().
(:glance)
class TransitApp extends Application.AppBase {

    //! `AppServices` once the full app has started; typed loosely because the
    //! class is not loaded in glance mode.
    var services as Object?;

    function initialize() {
        AppBase.initialize();
    }

    //! Runs in both modes; services exist only in the full app.
    (:typecheck(disableGlanceCheck))
    function onStop(state as Dictionary?) as Void {
        var started = services;
        if (started != null) {
            (started as AppServices).stop();
        }
    }

    //! Called only in the full app, where all code is loaded.
    (:typecheck(disableGlanceCheck))
    function getInitialView() as [Views] or [Views, InputDelegates] {
        getServices();
        return [new HomeView(), new HomeDelegate()];
    }

    function getGlanceView() as [GlanceView] or [GlanceView, GlanceViewDelegate] or Null {
        return [new TransitGlance()];
    }
}

//! Glance in the watch's glance list: app name and what it offers. START on
//! it opens the full app.
(:glance)
class TransitGlance extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var height = dc.getHeight();
        var left = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, height * 0.3, Graphics.FONT_GLANCE, WatchUi.loadResource(Rez.Strings.AppName) as String, left);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, height * 0.72, Graphics.FONT_GLANCE, WatchUi.loadResource(Rez.Strings.GlanceHint) as String, left);
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
