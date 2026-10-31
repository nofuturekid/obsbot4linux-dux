import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Hand tracking settings stored in the camera: area, axes, return time (obsbot4linux 0.12; each
// part has its own capability) and the gimbal switch, which the camera does not report. Shown by
// the Tracking card while Hand is the tracking mode.
Column {
    id: hand

    property var ctl

    readonly property var area: ctl.cam.hand?.area ?? null
    readonly property var limits: ctl.limits
    readonly property var fullArea: limits ? [limits.pan[0], limits.pan[1], limits.tilt[0], limits.tilt[1]].map(v => Math.round(v)) : [0, 0, 0, 0]
    // [pan from, pan to, tilt from, tilt to] as the camera reports it
    readonly property var cameraArea: area ? [area.pan_min, area.pan_max, area.tilt_min, area.tilt_max].map(v => Math.round(v)) : fullArea
    property int panMin: cameraArea[0]
    property int panMax: cameraArea[1]
    property int tiltMin: cameraArea[2]
    property int tiltMax: cameraArea[3]
    // While a slider is held, and for a moment after the area went out, the camera's (older) area
    // must not pull the sliders back (same as the Zone card)
    readonly property bool editing: areaHold.running || panMinSlider.dragging || panMaxSlider.dragging || tiltMinSlider.dragging || tiltMaxSlider.dragging
    // seconds as the camera reports them, in tenths for the slider
    readonly property real returnAfter: ctl.cam.hand?.return_after ?? NaN
    readonly property bool returnAfterKnown: !isNaN(returnAfter)

    onCameraAreaChanged: {
        if (!editing)
            syncArea();
    }
    onEditingChanged: {
        if (!editing)
            syncArea();
    }

    function syncArea() {
        panMin = cameraArea[0];
        panMax = cameraArea[1];
        tiltMin = cameraArea[2];
        tiltMax = cameraArea[3];
        panMinSlider.sync();
        panMaxSlider.sync();
        tiltMinSlider.sync();
        tiltMaxSlider.sync();
    }

    function deg(v) {
        return String(v).replace("-", "−") + "°";
    }

    // Keeps from < to; the slider that was dragged past the other one stops at it
    function setArea(which, value) {
        if (which === "panMin")
            panMin = Math.min(value, panMax - 1);
        else if (which === "panMax")
            panMax = Math.max(value, panMin + 1);
        else if (which === "tiltMin")
            tiltMin = Math.min(value, tiltMax - 1);
        else
            tiltMax = Math.max(value, tiltMin + 1);
        panMinSlider.sync();
        panMaxSlider.sync();
        tiltMinSlider.sync();
        tiltMaxSlider.sync();
    }

    function sendArea() {
        ctl.send(["hand", "area", "--pan", panMin, panMax, "--tilt", tiltMin, tiltMax], "Setting hand area", { hand: { area: { pan_min: panMin, pan_max: panMax, tilt_min: tiltMin, tilt_max: tiltMax } } });
        areaHold.restart();
    }

    width: parent.width
    spacing: Theme.spacingM

    Timer {
        id: areaHold
        interval: 500
    }

    // Sent once the slider is let go, not on every step
    Column {
        width: parent.width
        spacing: Theme.spacingM
        visible: hand.ctl.has("hand_area")

        LabeledSlider {
            id: panMinSlider
            width: parent.width
            label: "Hand area: pan from"
            minimum: hand.fullArea[0]
            maximum: hand.fullArea[1]
            value: hand.panMin
            formatValue: hand.deg
            onMoved: value => hand.setArea("panMin", value)
            onReleased: hand.sendArea()
        }

        LabeledSlider {
            id: panMaxSlider
            width: parent.width
            label: "Hand area: pan to"
            minimum: hand.fullArea[0]
            maximum: hand.fullArea[1]
            value: hand.panMax
            formatValue: hand.deg
            onMoved: value => hand.setArea("panMax", value)
            onReleased: hand.sendArea()
        }

        LabeledSlider {
            id: tiltMinSlider
            width: parent.width
            label: "Hand area: tilt from"
            minimum: hand.fullArea[2]
            maximum: hand.fullArea[3]
            value: hand.tiltMin
            formatValue: hand.deg
            onMoved: value => hand.setArea("tiltMin", value)
            onReleased: hand.sendArea()
        }

        LabeledSlider {
            id: tiltMaxSlider
            width: parent.width
            label: "Hand area: tilt to"
            minimum: hand.fullArea[2]
            maximum: hand.fullArea[3]
            value: hand.tiltMax
            formatValue: hand.deg
            onMoved: value => hand.setArea("tiltMax", value)
            onReleased: hand.sendArea()
        }

        DButton {
            text: "Default area"
            iconName: "fit_screen"
            onClicked: hand.ctl.send(["hand", "area-reset"], "Setting the hand area back to the default")
        }
    }

    ToggleRow {
        width: parent.width
        visible: hand.ctl.has("hand_axes") && hand.ctl.cam.hand?.pan_enabled !== undefined
        label: "Hand moves pan"
        description: "Off: the pan axis stays where it is"
        checked: hand.ctl.cam.hand?.pan_enabled === true
        onToggled: checked => hand.ctl.send(["hand", "pan", checked ? "on" : "off"], checked ? "Letting the hand pan" : "Holding pan", { hand: { pan_enabled: checked } })
    }

    ToggleRow {
        width: parent.width
        visible: hand.ctl.has("hand_axes") && hand.ctl.cam.hand?.tilt_enabled !== undefined
        label: "Hand moves tilt"
        description: "Off: the tilt axis stays where it is"
        checked: hand.ctl.cam.hand?.tilt_enabled === true
        onToggled: checked => hand.ctl.send(["hand", "tilt", checked ? "on" : "off"], checked ? "Letting the hand tilt" : "Holding tilt", { hand: { tilt_enabled: checked } })
    }

    // Seconds outside the area before the camera goes to the return position; tenths of a second
    // on the slider, up to 30 s (the camera itself only refuses negative values)
    LabeledSlider {
        width: parent.width
        visible: hand.ctl.has("hand_return_after") && hand.returnAfterKnown
        label: "Return after"
        minimum: 0
        maximum: 300
        value: Math.min(300, Math.round(hand.returnAfter * 10))
        formatValue: v => (v / 10).toFixed(1) + " s"
        onReleased: value => hand.ctl.send(["hand", "return-after", (value / 10).toFixed(1)], "Setting the hand return time", { hand: { return_after: value / 10 } })
    }

    ToggleRow {
        width: parent.width
        visible: hand.ctl.has("hand_gimbal")
        label: "Hand moves the gimbal"
        description: "Off stops the gimbal. The camera does not report or keep this; it shows the last value set here."
        checked: hand.ctl.handGimbal
        onToggled: checked => hand.ctl.setHandGimbal(checked)
    }
}
