import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Zone tracking: stay within an area, return to a chosen position. obsbot4linux 0.5.0 reads
// the area, follow and the return position from the camera (status key `zone`); 0.7.1 reports
// the ranges the area may take (`limits`).
SectionCard {
    id: section

    property var ctl

    readonly property var fullArea: ctl.limits ? [ctl.limits.pan[0], ctl.limits.pan[1], ctl.limits.tilt[0], ctl.limits.tilt[1]].map(v => Math.round(v)) : [0, 0, 0, 0]
    readonly property var zone: ctl.cam.zone ?? null
    // [pan from, pan to, tilt from, tilt to] as the camera reports it
    readonly property var cameraArea: zone ? [zone.pan_min, zone.pan_max, zone.tilt_min, zone.tilt_max].map(v => Math.round(v)) : fullArea
    property int panMin: cameraArea[0]
    property int panMax: cameraArea[1]
    property int tiltMin: cameraArea[2]
    property int tiltMax: cameraArea[3]
    // While a slider is held, and for a moment after the area went out (like dragHold in the
    // widget), the camera's (older) area must not pull the sliders back. A drag that is cancelled
    // instead of released ends it too; the sliders then show the camera's area again.
    readonly property bool editing: areaHold.running || panMinSlider.dragging || panMaxSlider.dragging || tiltMinSlider.dragging || tiltMaxSlider.dragging
    readonly property var returnPos: zone?.return ?? null
    readonly property bool zoneOn: ctl.tracking.zone_tracking === true
    readonly property bool fullAreaSet: panMin === fullArea[0] && panMax === fullArea[1] && tiltMin === fullArea[2] && tiltMax === fullArea[3]

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

    function num(v) {
        return String(v).replace("-", "−");
    }
    function deg(v) {
        return num(v) + "°";
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
        ctl.send(["zone", "area", "--pan", panMin, panMax, "--tilt", tiltMin, tiltMax], "Setting zone area", { zone: { pan_min: panMin, pan_max: panMax, tilt_min: tiltMin, tilt_max: tiltMax } });
        areaHold.restart();
    }

    Timer {
        id: areaHold
        interval: 500
    }

    title: "Zone"
    collapsible: true
    expanded: false
    visible: ctl.cardEnabled("Zone") && ctl.has("zone")
    summary: (ctl.tracking.zone_tracking === undefined ? "" : "Zone " + (zoneOn ? "on" : "off") + " · ") + "pan " + num(panMin) + "…" + deg(panMax) + " · tilt " + num(tiltMin) + "…" + deg(tiltMax)
    // the camera takes these while asleep too and keeps them when it wakes
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38

    ToggleRow {
        width: parent.width
        label: "Zone tracking"
        checked: section.zoneOn
        onToggled: checked => section.ctl.send(["zone", checked ? "on" : "off"], checked ? "Turning on zone tracking" : "Turning off zone tracking", { tracking: { zone_tracking: checked } })
    }

    // Sent once the slider is let go, not on every step
    LabeledSlider {
        id: panMinSlider
        width: parent.width
        label: "Pan from"
        minimum: section.fullArea[0]
        maximum: section.fullArea[1]
        value: section.panMin
        formatValue: section.deg
        onMoved: value => section.setArea("panMin", value)
        onReleased: section.sendArea()
    }

    LabeledSlider {
        id: panMaxSlider
        width: parent.width
        label: "Pan to"
        minimum: section.fullArea[0]
        maximum: section.fullArea[1]
        value: section.panMax
        formatValue: section.deg
        onMoved: value => section.setArea("panMax", value)
        onReleased: section.sendArea()
    }

    LabeledSlider {
        id: tiltMinSlider
        width: parent.width
        label: "Tilt from"
        minimum: section.fullArea[2]
        maximum: section.fullArea[3]
        value: section.tiltMin
        formatValue: section.deg
        onMoved: value => section.setArea("tiltMin", value)
        onReleased: section.sendArea()
    }

    LabeledSlider {
        id: tiltMaxSlider
        width: parent.width
        label: "Tilt to"
        minimum: section.fullArea[2]
        maximum: section.fullArea[3]
        value: section.tiltMax
        formatValue: section.deg
        onMoved: value => section.setArea("tiltMax", value)
        onReleased: section.sendArea()
    }

    Flow {
        width: parent.width
        spacing: Theme.spacingS

        DButton {
            text: "Full area"
            iconName: "fit_screen"
            enabled: !section.fullAreaSet
            onClicked: {
                section.panMin = section.fullArea[0];
                section.panMax = section.fullArea[1];
                section.tiltMin = section.fullArea[2];
                section.tiltMax = section.fullArea[3];
                section.sendArea();
            }
        }

        DButton {
            text: "Return here"
            iconName: "my_location"
            onClicked: section.ctl.send(["zone", "return-here"], "Setting the zone return position")
        }

        DButton {
            text: "Go to return position"
            iconName: "u_turn_left"
            visible: section.ctl.has("zone_return")
            onClicked: section.ctl.send(["zone", "return-go"], "Moving to the zone return position")
        }
    }

    StyledText {
        width: parent.width
        visible: section.returnPos !== null
        text: section.returnPos ? "Return position: pan " + section.deg(Math.round(section.returnPos.pan)) + " · tilt " + section.deg(Math.round(section.returnPos.tilt)) + " · zoom " + Number(section.returnPos.zoom).toFixed(1) + "×" : ""
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: section.ctl.cam.state?.zone_follow === true
            ? "When the target leaves the area, the camera returns to its return position, keeps tracking and takes the next person who enters it."
            : "When the target leaves the area, tracking stops (Static) and the camera returns to its return position."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    ZoneViews {
        width: parent.width
        visible: section.ctl.has("zone_views")
        ctl: section.ctl
    }
}
