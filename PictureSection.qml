import QtQuick
import qs.Common
import qs.DCommon.Widgets

// HDR, exposure mode and autofocus
SectionCard {
    id: section

    property var ctl

    title: "Picture"
    // the camera takes these while asleep too and keeps them when it wakes
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38

    ToggleRow {
        width: parent.width
        label: "HDR"
        checked: section.ctl.status.hdr === true
        onToggled: checked => section.ctl.setHdr(checked)
    }

    // Global / face as status byte 0x07 reports it, custom = manual (UVC auto_exposure 1)
    ChipRow {
        id: exposureRow
        width: parent.width
        label: "Exposure"
        options: section.ctl.exposureModes.map(m => m.label)
        currentIndex: section.ctl.manualExposure ? 2 : (section.ctl.status.face_auto_exposure === undefined ? -1 : (section.ctl.status.face_auto_exposure ? 1 : 0))
        onSelected: index => section.ctl.setExposure(index)
    }

    // Exposure time in 100 µs; past one frame (1/30 s = 333) it no longer brightens.
    // Shown but disabled outside custom exposure, so the card keeps its height.
    LabeledSlider {
        width: parent.width
        enabled: section.ctl.manualExposure
        opacity: enabled ? 1 : 0.38
        label: "Exposure time"
        minimum: section.ctl.image.exposure_time?.min ?? 1
        maximum: Math.min(section.ctl.image.exposure_time?.max ?? 333, 333)
        value: section.ctl.image.exposure_time?.value ?? 0
        formatValue: v => (v / 10).toFixed(1) + " ms"
        onMoved: value => section.ctl.setControl("exposure_time", value)
    }

    LabeledSlider {
        width: parent.width
        enabled: section.ctl.manualExposure
        opacity: enabled ? 1 : 0.38
        label: "Gain"
        minimum: section.ctl.image.gain?.min ?? 1
        maximum: section.ctl.image.gain?.max ?? 64
        value: section.ctl.image.gain?.value ?? 0
        onMoved: value => section.ctl.setControl("gain", value)
    }

    // The camera's own autofocus mode; a click on the running preview focuses once on that spot
    ChipRow {
        id: afRow
        width: parent.width
        visible: section.ctl.has("focus_af_mode")
        label: "Autofocus"
        options: ["Continuous", "Single", "Manual"]
        currentIndex: section.ctl.afModes.indexOf(section.ctl.cam.focus?.mode)
        onSelected: index => section.ctl.setAfMode(index)
    }

    // The UVC focus position, effective in manual mode
    LabeledSlider {
        width: parent.width
        visible: section.ctl.has("focus_af_mode") && section.ctl.image.focus !== undefined
        enabled: section.ctl.cam.focus?.mode === "manual"
        opacity: enabled ? 1 : 0.38
        label: "Manual focus"
        minimum: section.ctl.image.focus?.min ?? 0
        maximum: section.ctl.image.focus?.max ?? 100
        value: section.ctl.image.focus?.value ?? 0
        onMoved: value => section.ctl.setControl("focus", value)
    }

    // A click assigns currentIndex and breaks the binding; re-sync to the camera state
    Connections {
        target: section.ctl
        function onStateRefreshed() {
            exposureRow.sync();
            afRow.sync();
        }
    }
}
