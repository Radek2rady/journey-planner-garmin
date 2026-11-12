import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! Application entry point. Owns the long-lived services; UI code reaches
//! them through getApp().
class TransitApp extends Application.AppBase {

    var api as TransitApi = new TransitApi();
    var location as LocationProvider = new LocationProvider();
    var trip as TripStore = new TripStore();

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        trip.load();
        location.start();
    }

    function onStop(state as Dictionary?) as Void {
        location.stop();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new HomeView(), new HomeDelegate()];
    }
}

function getApp() as TransitApp {
    return Application.getApp() as TransitApp;
}
