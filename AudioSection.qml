import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Microphone processing. Turning the microphone off is left to the CLI: it restarts the camera.
SectionCard {
    id: section

    property var ctl

    readonly property var levels: ["Off", "Weak", "Medium", "Strong"]
    readonly property var distances: ["Near", "Standard", "Far"]

    title: "Audio"
    collapsible: true
    expanded: false
    visible: ctl.cardEnabled("Audio") && ctl.has("audio")
    summary: [ctl.status.noise_reduction ? "Noise reduction " + ctl.status.noise_reduction : "", ctl.status.pickup_distance ? "pickup " + ctl.status.pickup_distance : "", ctl.cam.audio_volume !== undefined && ctl.cam.audio_volume !== null ? "volume " + ctl.cam.audio_volume : "", ctl.status.auto_gain !== undefined ? "auto gain " + (ctl.status.auto_gain ? "on" : "off") : "", ctl.status.mic_in_sleep !== undefined ? "mic asleep " + (ctl.status.mic_in_sleep ? "on" : "off") : ""].filter(s => s !== "").join(" · ")
    // the camera takes these while asleep too and keeps them when it wakes
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38

    ChipRow {
        id: levelRow
        width: parent.width
        label: "Noise reduction"
        stacked: true
        options: section.levels
        currentIndex: section.levels.findIndex(l => l.toLowerCase() === section.ctl.status.noise_reduction)
        onSelected: index => section.ctl.send(["audio", "noise", section.levels[index].toLowerCase()], "Setting noise reduction to " + section.levels[index], { status: { noise_reduction: section.levels[index].toLowerCase() } })
    }

    ChipRow {
        id: distanceRow
        width: parent.width
        label: "Pickup distance"
        options: section.distances
        currentIndex: section.distances.findIndex(d => d.toLowerCase() === section.ctl.status.pickup_distance)
        onSelected: index => section.ctl.send(["audio", "distance", section.distances[index].toLowerCase()], "Setting pickup distance to " + section.distances[index], { status: { pickup_distance: section.distances[index].toLowerCase() } })
    }

    // Null in the state while the camera sleeps or does not answer; the pickup distance above follows it
    LabeledSlider {
        width: parent.width
        visible: section.ctl.has("audio_volume")
        enabled: section.ctl.cam.audio_volume !== undefined && section.ctl.cam.audio_volume !== null
        opacity: enabled ? 1 : 0.38
        label: "Microphone volume"
        minimum: 0
        maximum: 100
        value: section.ctl.cam.audio_volume ?? 0
        onMoved: value => section.ctl.setVolume(value)
    }

    ToggleRow {
        width: parent.width
        label: "Automatic gain"
        checked: section.ctl.status.auto_gain === true
        onToggled: checked => section.ctl.send(["audio", "gain", checked ? "on" : "off"], checked ? "Turning automatic gain on" : "Turning automatic gain off", { status: { auto_gain: checked } })
    }

    ToggleRow {
        width: parent.width
        label: "Microphone while asleep"
        checked: section.ctl.status.mic_in_sleep === true
        onToggled: checked => section.ctl.send(["audio", "sleep-mic", checked ? "on" : "off"], checked ? "Keeping the microphone on while asleep" : "Muting the microphone while asleep", { status: { mic_in_sleep: checked } })
    }

    Connections {
        target: section.ctl
        function onStateRefreshed() {
            levelRow.sync();
            distanceRow.sync();
        }
    }
}
