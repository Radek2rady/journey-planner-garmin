import Toybox.Lang;
import Toybox.WatchUi;

//! Asks for the user's consent before the position is first used.
module LocationConsent {

    //! True when the position may be used; otherwise asks and returns false,
    //! so the caller stops and the user repeats the action after allowing.
    function ask() as Boolean {
        if (getServices().location.allowed) {
            return true;
        }
        WatchUi.pushView(new WatchUi.Confirmation(Texts.get(Rez.Strings.LocationQuestion)), new LocationConsentDelegate(), WatchUi.SLIDE_UP);
        return false;
    }
}

class LocationConsentDelegate extends WatchUi.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response as Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            getServices().location.allow();
        }
        WatchUi.requestUpdate();
        return true;
    }
}
