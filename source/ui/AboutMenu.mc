import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

//! About: version and data sources, and the privacy policy opened on the phone.
module AboutMenu {

    function push() as Void {
        var menu = new WatchUi.Menu2({ :title => Rez.Strings.About });
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.AppName, Texts.version(BuildConfig.APP_VERSION), :info, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.PrivacyPolicy, Rez.Strings.PrivacyHint, :privacy, null));
        WatchUi.pushView(menu, new AboutMenuDelegate(), WatchUi.SLIDE_LEFT);
    }
}

class AboutMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (id == :info) {
            WatchUi.pushView(new FullTextView(Texts.about(BuildConfig.APP_VERSION)), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :privacy) {
            // The watch has no browser: the phone shows a notification that opens the page.
            Communications.openWebPage(Config.PRIVACY_URL, null, null);
            item.setSubLabel(Rez.Strings.PrivacySent);
            WatchUi.requestUpdate();
        }
    }
}
