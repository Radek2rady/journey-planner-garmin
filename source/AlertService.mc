import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;

//! Runs in the background at the time of the departure alert and shows it as
//! a notification. Loads nothing but the stored alert (background memory is
//! 64 kB).
(:background)
class AlertService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var alert = DepartureAlert.load();
        if (alert != null) {
            if (Toybox has :Notifications) {
                Notifications.showNotification(alert.title, alert.detail, { :dismissPrevious => true });
            } else {
                Background.requestApplicationWake(alert.title + "\n" + alert.detail);
            }
        }
        Background.exit(null);
    }
}
