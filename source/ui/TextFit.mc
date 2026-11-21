import Toybox.Graphics;
import Toybox.Lang;

//! Shortens a text with "..." until it fits a width in pixels.
(:glance)
module TextFit {

    const ELLIPSIS = "...";

    //! Keeps the beginning: "Praha hlavní nád...".
    function keepStart(dc as Dc, text as String, font as FontType, maxWidth as Number) as String {
        if (dc.getTextWidthInPixels(text, font) <= maxWidth) {
            return text;
        }
        for (var length = text.length() - 1; length > 0; length--) {
            var candidate = text.substring(0, length) + ELLIPSIS;
            if (dc.getTextWidthInPixels(candidate, font) <= maxWidth) {
                return candidate;
            }
        }
        return ELLIPSIS;
    }

    //! The first variant that fits whole, otherwise the last one shortened.
    function firstThatFits(dc as Dc, variants as Array<String>, font as FontType, maxWidth as Number) as String {
        for (var i = 0; i < variants.size(); i++) {
            if (dc.getTextWidthInPixels(variants[i], font) <= maxWidth) {
                return variants[i];
            }
        }
        return keepStart(dc, variants[variants.size() - 1], font, maxWidth);
    }

    //! Keeps the end, for text being typed: "...hlavní nádraží_".
    function keepEnd(dc as Dc, text as String, font as FontType, maxWidth as Number) as String {
        if (dc.getTextWidthInPixels(text, font) <= maxWidth) {
            return text;
        }
        var total = text.length();
        for (var start = 1; start < total; start++) {
            var candidate = ELLIPSIS + text.substring(start, total);
            if (dc.getTextWidthInPixels(candidate, font) <= maxWidth) {
                return candidate;
            }
        }
        return ELLIPSIS;
    }
}
