import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Field of view, status LED, mirror and invert (obsbot4linux)
SectionCard {
    id: section

    property var ctl

    readonly property var fovs: ["Wide", "Medium", "Narrow"]
    readonly property var leds: ["Off", "1", "2", "3"]

    // "custom" after the zoom was set freely
    function fovName() {
        const f = ctl.status.field_of_view ?? "";
        return f.charAt(0).toUpperCase() + f.slice(1);
    }

    // Read-only info lines; a line shows only when obsbot4linux reports the field.
    // anti_flicker is a string since obsbot4linux 0.9.0, a number before (same order).
    function antiFlicker() {
        const a = ctl.status.anti_flicker;
        const names = ["off", "50 Hz", "60 Hz", "auto"];
        if (typeof a === "number")
            return names[a] ?? "";
        return a === undefined ? "" : (names.find(n => n.replace(" ", "").toLowerCase() === String(a).toLowerCase()) ?? String(a));
    }

    function percent(v) {
        return v === undefined || v === null ? "" : v + " %";
    }

    readonly property var infoLines: [["Firmware", ctl.cam.firmware ?? ""], ["Anti-flicker", antiFlicker()], ["Frame rate", ctl.status.frame_rate !== undefined ? ctl.status.frame_rate + " fps" : ""], ["Digital zoom", percent(ctl.status.digital_zoom_percent)], ["Wake-up zoom", percent(ctl.status.wake_up_zoom_percent)]].filter(l => l[1] !== "")

    title: "Camera"
    collapsible: true
    expanded: false
    visible: ctl.cardEnabled("Camera") && (["fov", "led", "mirror", "invert"].some(c => ctl.has(c)))
    summary: [fovName(), ctl.status.led !== undefined ? "LED " + leds[ctl.status.led] : "", ctl.status.mirror !== undefined ? "mirror " + (ctl.status.mirror ? "on" : "off") : "", ctl.tracking.invert !== undefined ? "invert " + (ctl.tracking.invert ? "on" : "off") : ""].filter(s => s !== "").join(" · ")
    // the camera takes these while asleep too and keeps them when it wakes
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38

    ChipRow {
        id: fovRow
        width: parent.width
        visible: section.ctl.has("fov")
        // ignored by the camera while it sleeps
        enabled: section.ctl.live
        opacity: enabled ? 1 : 0.38
        label: "Field of view"
        options: section.fovs
        currentIndex: section.fovs.findIndex(f => f.toLowerCase() === section.ctl.status.field_of_view)
        onSelected: index => section.ctl.send(["fov", section.fovs[index].toLowerCase()], "Setting field of view to " + section.fovs[index], { status: { field_of_view: section.fovs[index].toLowerCase() } })
    }

    ChipRow {
        id: ledRow
        width: parent.width
        visible: section.ctl.has("led")
        label: "Status LED"
        options: section.leds
        currentIndex: section.ctl.status.led ?? -1
        onSelected: index => section.ctl.send(["led", index], "Setting status LED to " + section.leds[index], { status: { led: index } })
    }

    ToggleRow {
        width: parent.width
        visible: section.ctl.has("led_blink")
        label: "Blink status LED"
        description: "The camera cannot report this; shows the last value set here"
        checked: section.ctl.ledBlink
        onToggled: checked => section.ctl.setLedBlink(checked)
    }

    ToggleRow {
        width: parent.width
        visible: section.ctl.has("mirror")
        label: "Mirror image"
        checked: section.ctl.status.mirror === true
        onToggled: checked => section.ctl.send(["mirror", checked ? "on" : "off"], checked ? "Mirroring image" : "Unmirroring image", { status: { mirror: checked } })
    }

    ToggleRow {
        width: parent.width
        visible: section.ctl.has("invert")
        label: "Invert gimbal"
        description: "Reverses left/right panning"
        checked: section.ctl.tracking.invert === true
        onToggled: checked => section.ctl.send(["invert", checked ? "on" : "off"], checked ? "Inverting gimbal" : "Restoring gimbal direction", { tracking: { invert: checked } })
    }

    StyledText {
        width: parent.width
        visible: section.infoLines.length > 0
        wrapMode: Text.WordWrap
        text: section.infoLines.map(l => l[0] + ": " + l[1]).join(" · ")
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    // A click assigns currentIndex and breaks the binding; re-sync to the camera state
    Connections {
        target: section.ctl
        function onStateRefreshed() {
            fovRow.sync();
            ledRow.sync();
        }
    }
}
