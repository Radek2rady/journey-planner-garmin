import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Start screen: shows the planned trip. START or a tap opens the main menu.
class HomeView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var app = getServices();
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        drawCaption(dc, centerX, height * 0.07, Rez.Strings.AppName);
        drawCaption(dc, centerX, height * 0.19, Rez.Strings.From);
        drawCaption(dc, centerX, height * 0.47, Rez.Strings.To);
        drawCaption(dc, centerX, height * 0.80, Rez.Strings.StartHint);

        // The screen is round: the lower box sits nearer the middle and can be wider.
        drawStopName(dc, Texts.originName(app.trip, app.location), height * 0.28, width * 0.80, height * 0.19);
        drawStopName(dc, Texts.destinationName(app.trip), height * 0.56, width * 0.86, height * 0.22);
    }

    private function drawCaption(dc as Dc, x as Number, y as Float, text as ResourceId) as Void {
        dc.drawText(x, y, Graphics.FONT_XTINY, Texts.get(text), Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Wraps the name and shrinks the font until it fits the box.
    private function drawStopName(dc as Dc, name as String, y as Float, width as Float, height as Float) as Void {
        var area = new WatchUi.TextArea({
            :text => name,
            :color => Graphics.COLOR_WHITE,
            :font => [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY],
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => y.toNumber(),
            :width => width.toNumber(),
            :height => height.toNumber(),
            :justification => Graphics.TEXT_JUSTIFY_CENTER
        });
        area.draw(dc);
    }
}

class HomeDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        MainMenu.push();
        return true;
    }

    function onMenu() as Boolean {
        MainMenu.push();
        return true;
    }
}
