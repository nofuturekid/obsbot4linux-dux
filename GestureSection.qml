import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Gesture switches and how far the zoom gesture zooms in
SectionCard {
    id: section

    property var ctl

    // label shown, CLI argument, key in obsbot4linux's tracking state
    readonly property var gestures: [
        { label: "Target lock", arg: "target-lock", key: "target_lock" },
        { label: "Zoom", arg: "zoom", key: "zoom_gesture" },
        { label: "Dynamic zoom", arg: "dynamic-zoom", key: "dynamic_zoom" },
        { label: "Direction change", arg: "direction-change", key: "direction_change", description: "Reverses which hand movement zooms in or out with Dynamic zoom.", needs: "dynamic_zoom" }
    ]
    readonly property int onCount: gestures.filter(g => ctl.tracking[g.key] === true).length

    title: "Gestures"
    collapsible: true
    expanded: false
    visible: ctl.cardEnabled("Gestures") && ctl.has("gesture")
    summary: (onCount === 0 ? "All off" : gestures.filter(g => ctl.tracking[g.key] === true).map(g => g.label).join(", ") + " on") + (ctl.tracking.gesture_zoom_ratio !== undefined ? " · zoom ratio " + ctl.tracking.gesture_zoom_ratio.toFixed(1) + "×" : "")
    // the camera takes these while asleep too and keeps them when it wakes
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38

    Repeater {
        model: section.gestures

        ToggleRow {
            required property var modelData
            width: parent.width
            label: modelData.label
            description: modelData.description ?? ""
            // reverses Dynamic zoom's direction, does nothing while that is off; still shows the camera's value
            enabled: modelData.needs === undefined || section.ctl.tracking[modelData.needs] === true
            opacity: enabled ? 1 : 0.38
            checked: section.ctl.tracking[modelData.key] === true
            onToggled: checked => section.ctl.send(["gesture", "set", modelData.arg, checked ? "on" : "off"], (checked ? "Turning on " : "Turning off ") + modelData.label.toLowerCase() + " gesture", { tracking: { [modelData.key]: checked } })
        }
    }

    // Tenths of the ratio, 1.0 to 4.0; sent once the slider rests, not on every step
    LabeledSlider {
        width: parent.width
        label: "Zoom gesture ratio"
        minimum: 10
        maximum: 40
        value: Math.round((section.ctl.tracking.gesture_zoom_ratio ?? 2) * 10)
        formatValue: v => (v / 10).toFixed(1) + "×"
        onMoved: value => {
            ratioTimer.ratio = value / 10;
            ratioTimer.restart();
        }
    }

    Timer {
        id: ratioTimer
        property real ratio: 2
        interval: 400
        onTriggered: section.ctl.send(["gesture", "zoom-ratio", ratio.toFixed(1)], "Setting zoom gesture ratio to " + ratio.toFixed(1) + "×", { tracking: { gesture_zoom_ratio: ratio } })
    }
}
