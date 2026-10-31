import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Auto-sleep and what the camera shows while asleep
SectionCard {
    id: section

    property var ctl

    readonly property var backgrounds: ["Black", "Image"]

    title: "Sleep"
    collapsible: true
    expanded: false
    visible: ctl.cardEnabled("Sleep") && (ctl.has("auto_sleep") || ctl.has("sleep_background") || ctl.has("wake_zoom") || ctl.has("wake_mode"))
    summary: [ctl.status.auto_sleep_enabled === undefined ? "" : "Auto-sleep " + (ctl.status.auto_sleep_enabled ? ctl.status.auto_sleep_seconds + " s" : "off"), ctl.status.sleep_background ? "background " + ctl.status.sleep_background : ""].filter(s => s !== "").join(" · ")
    // Unlike the other settings these matter (and work) while the camera is asleep
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38

    ChipRow {
        id: autoSleepRow
        width: parent.width
        visible: section.ctl.has("auto_sleep")
        label: "Auto-sleep"
        stacked: true
        options: section.ctl.autoSleepTimes.map(t => t.label)
        currentIndex: section.ctl.autoSleepIndex()
        onSelected: index => {
            const time = section.ctl.autoSleepTimes[index];
            // "off" keeps the configured time
            section.ctl.send(["auto-sleep", time.arg], "Setting auto-sleep to " + time.label, { status: index === 0 ? { auto_sleep_enabled: false } : { auto_sleep_enabled: true, auto_sleep_seconds: Number(time.arg) } });
        }
    }

    ChipRow {
        id: backgroundRow
        width: parent.width
        visible: section.ctl.has("sleep_background")
        label: "While asleep"
        options: section.backgrounds
        currentIndex: section.backgrounds.findIndex(b => b.toLowerCase() === section.ctl.status.sleep_background)
        onSelected: index => section.ctl.send(["sleep-background", section.backgrounds[index].toLowerCase()], "Setting sleep background to " + section.backgrounds[index], { status: { sleep_background: section.backgrounds[index].toLowerCase() } })
    }

    // Stored in the camera and used when it powers on (plugged in), also without the widget running.
    // Waking from sleep, by command or by an app's stream, does not apply them (measured, #75)
    StyledText {
        width: parent.width
        visible: section.ctl.has("wake_zoom") || section.ctl.has("wake_mode")
        wrapMode: Text.WordWrap
        text: "Power-on settings: waking from sleep does not apply them."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    LabeledSlider {
        width: parent.width
        visible: section.ctl.has("wake_zoom")
        enabled: section.ctl.status.wake_up_zoom_percent !== undefined
        opacity: enabled ? 1 : 0.38
        label: "Zoom at power-on"
        // hundredths: percent p is 1 + 3 * p / 100
        minimum: 100
        maximum: 400
        value: 100 + 3 * (section.ctl.status.wake_up_zoom_percent ?? 0)
        formatValue: v => (v / 100).toFixed(2) + "×"
        onMoved: value => section.ctl.setWakeZoom(value)
    }

    ChipRow {
        id: wakeModeRow
        width: parent.width
        visible: section.ctl.has("wake_mode")
        label: "Tracking mode at power-on"
        stacked: true
        options: section.ctl.trackingModes.map(m => m.label)
        currentIndex: section.ctl.wakeModeIndex()
        onSelected: index => section.ctl.setWakeMode(index)
    }

    Connections {
        target: section.ctl
        function onStateRefreshed() {
            autoSleepRow.sync();
            backgroundRow.sync();
            wakeModeRow.sync();
        }
    }
}
