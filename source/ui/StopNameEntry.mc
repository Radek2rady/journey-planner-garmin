import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

//! Entry of a stop name with the buttons or by swiping: UP/DOWN move through
//! the keys (holding the button keeps moving), START types the highlighted one,
//! BACK erases. Replaces the native
//! `TextPicker`, which crashes the fr955 simulator on input.
module StopNameEntry {

    function push(chooser as StopChooserDelegate) as Void {
        var input = new NameInput();
        WatchUi.pushView(new StopNameView(input), new StopNameDelegate(input, chooser), WatchUi.SLIDE_UP);
    }
}

//! The text typed so far and the highlighted key. Key `DONE` finishes the
//! entry; the keys after it are the letters. Diacritics are not needed, the
//! stop search ignores them.
class NameInput {

    static const DONE = 0;
    static const LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ ";
    static const MAX_LENGTH = 16;

    var text as String = "";
    var key as Number = 1;

    function initialize() {
    }

    static function keyCount() as Number {
        return LETTERS.length() + 1;
    }

    //! Key `offset` steps away from the highlighted one, wrapping around.
    function keyAt(offset as Number) as Number {
        var count = keyCount();
        return ((key + offset) % count + count) % count;
    }

    //! Letter typed by `key`; null for `DONE`.
    static function letter(key as Number) as String? {
        return key == DONE ? null : LETTERS.substring(key - 1, key);
    }

    function move(offset as Number) as Void {
        key = keyAt(offset);
    }

    //! Presses the highlighted key. Returns true when the entry is finished.
    function press() as Boolean {
        var typed = letter(key);
        if (typed == null) {
            return true;
        }
        if (text.length() < MAX_LENGTH) {
            text += typed;
        }
        return false;
    }

    //! Erases the last letter. Returns false when there was nothing to erase.
    function erase() as Boolean {
        var length = text.length();
        if (length == 0) {
            return false;
        }
        var rest = length > 1 ? text.substring(0, length - 1) : null;
        text = rest != null ? rest : "";
        return true;
    }
}

class StopNameView extends WatchUi.View {

    private var _input as NameInput;

    function initialize(input as NameInput) {
        View.initialize();
        _input = input;
    }

    function onUpdate(dc as Dc) as Void {
        var x = dc.getWidth() / 2;
        var height = dc.getHeight();
        var centered = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        dc.drawText(x, height * 0.2, Graphics.FONT_SMALL, _input.text + "_", centered);
        dc.drawText(x, height * 0.54, Graphics.FONT_LARGE, keyLabel(0), centered);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, height * 0.37, Graphics.FONT_SMALL, keyLabel(-1), centered);
        dc.drawText(x, height * 0.71, Graphics.FONT_SMALL, keyLabel(1), centered);
    }

    private function keyLabel(offset as Number) as String {
        var typed = NameInput.letter(_input.keyAt(offset));
        if (typed == null) {
            return Texts.get(Rez.Strings.SearchKey);
        }
        return typed.equals(" ") ? Texts.get(Rez.Strings.SpaceKey) : typed;
    }
}

class StopNameDelegate extends WatchUi.BehaviorDelegate {

    //! Holding UP or DOWN this long starts moving through the keys repeatedly.
    private const REPEAT_DELAY_MS = 400;
    private const REPEAT_INTERVAL_MS = 110;
    //! A page behavior arriving this soon after a hold belongs to that hold.
    private const RELEASE_GUARD_MS = 300;

    private var _input as NameInput;
    private var _chooser as StopChooserDelegate;
    private var _timer as Timer.Timer?;
    private var _direction as Number = 0;
    private var _repeating as Boolean = false;
    private var _releasedAt as Number?;

    function initialize(input as NameInput, chooser as StopChooserDelegate) {
        BehaviorDelegate.initialize();
        _input = input;
        _chooser = chooser;
    }

    function onKeyPressed(event as KeyEvent) as Boolean {
        var key = event.getKey();
        if (key == WatchUi.KEY_DOWN) {
            startHold(1);
        } else if (key == WatchUi.KEY_UP) {
            startHold(-1);
        }
        return false;
    }

    function onKeyReleased(event as KeyEvent) as Boolean {
        endHold();
        return false;
    }

    //! A button went down: the single step comes from the page behavior, the
    //! timer adds further steps while the button stays down.
    function startHold(direction as Number) as Void {
        endHold();
        _releasedAt = null;
        _direction = direction;
        var timer = new Timer.Timer();
        timer.start(method(:onRepeat), REPEAT_DELAY_MS, false);
        _timer = timer;
    }

    function endHold() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
            _timer = null;
        }
        if (_repeating) {
            _repeating = false;
            _releasedAt = System.getTimer();
        }
    }

    function onRepeat() as Void {
        var timer = _timer;
        if (timer == null) {
            return;
        }
        if (!_repeating) {
            _repeating = true;
            timer.start(method(:onRepeat), REPEAT_INTERVAL_MS, true);
        }
        _input.move(_direction);
        WatchUi.requestUpdate();
    }

    function onNextPage() as Boolean {
        return step(1);
    }

    function onPreviousPage() as Boolean {
        return step(-1);
    }

    //! Holding UP is the system gesture for a menu; here it only scrolls.
    function onMenu() as Boolean {
        return true;
    }

    function onSelect() as Boolean {
        endHold();
        if (_input.press()) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _chooser.searchByName(_input.text);
        } else {
            WatchUi.requestUpdate();
        }
        return true;
    }

    //! Erases a letter; with nothing typed the system closes the view.
    function onBack() as Boolean {
        endHold();
        if (!_input.erase()) {
            return false;
        }
        WatchUi.requestUpdate();
        return true;
    }

    //! Single step from a button press or a swipe. Skipped when it is the
    //! tail of a hold that has already moved through the keys.
    private function step(direction as Number) as Boolean {
        var releasedAt = _releasedAt;
        _releasedAt = null;
        var afterHold = releasedAt != null && System.getTimer() - releasedAt < RELEASE_GUARD_MS;
        if (!_repeating && !afterHold) {
            _input.move(direction);
            WatchUi.requestUpdate();
        }
        return true;
    }
}
