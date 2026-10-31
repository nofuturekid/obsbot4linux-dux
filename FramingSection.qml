import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Pan/tilt and zoom
SectionCard {
    id: section

    property var ctl
    readonly property var startPose: ctl.cam.state?.startup ?? null
    // `startup set --ai` values (obsbot4linux 0.11.1); the camera reports the stored one as
    // state.startup.ai_mode, null while none is set
    readonly property var startModes: [
        { label: "Not set", arg: "none", key: "" },
        { label: "Static", arg: "static", key: "static" },
        { label: "Normal", arg: "normal", key: "normal" },
        { label: "Upper Body", arg: "upper-body", key: "upper_body" },
        { label: "Headless", arg: "headless", key: "headless" },
        { label: "Group", arg: "group", key: "group" }
    ]
    readonly property int startModeIndex: {
        const key = String(startPose?.ai_mode ?? "").replace("-", "_");
        return Math.max(0, startModes.findIndex(m => m.key === key));
    }

    title: "Framing"
    enabled: ctl.live || arranging
    opacity: ctl.live || arranging ? 1 : 0.38

    // D-pad and side panel; the panel drops below the pad when the popout is too narrow for both
    Flow {
        id: moveZoom
        width: parent.width
        spacing: Theme.spacingL

        // D-pad: up / left center right / down
        Grid {
            id: dpad
            columns: 3
            spacing: Theme.spacingXS

            Item { width: upButton.width; height: upButton.height }
            DIconButton {
                id: upButton
                variant: "tonal"
                iconName: "keyboard_arrow_up"
                tooltipText: "Tilt up " + section.ctl.gimbalStep + "°"
                onClicked: {
                    const b = section.ctl.stepBase();
                    section.ctl.moveGimbal(b.pan, b.tilt + section.ctl.gimbalStep);
                }
            }
            Item { width: upButton.width; height: upButton.height }
            DIconButton {
                variant: "tonal"
                iconName: "keyboard_arrow_left"
                tooltipText: "Pan left " + section.ctl.gimbalStep + "°"
                onClicked: {
                    const b = section.ctl.stepBase();
                    section.ctl.moveGimbal(b.pan + section.ctl.panLeftSign * section.ctl.gimbalStep, b.tilt);
                }
            }
            DIconButton {
                variant: "outlined"
                iconName: "filter_center_focus"
                tooltipText: "Center"
                onClicked: section.ctl.moveGimbal(0, 0)
            }
            DIconButton {
                variant: "tonal"
                iconName: "keyboard_arrow_right"
                tooltipText: "Pan right " + section.ctl.gimbalStep + "°"
                onClicked: {
                    const b = section.ctl.stepBase();
                    section.ctl.moveGimbal(b.pan - section.ctl.panLeftSign * section.ctl.gimbalStep, b.tilt);
                }
            }
            Item { width: upButton.width; height: upButton.height }
            DIconButton {
                variant: "tonal"
                iconName: "keyboard_arrow_down"
                tooltipText: "Tilt down " + section.ctl.gimbalStep + "°"
                onClicked: {
                    const b = section.ctl.stepBase();
                    section.ctl.moveGimbal(b.pan, b.tilt - section.ctl.gimbalStep);
                }
            }
            Item { width: upButton.width; height: upButton.height }
        }

        Column {
            // beside the pad while at least sideMin wide, else full width under it
            readonly property real sideMin: Theme.spacingXL * 6
            readonly property real beside: moveZoom.width - dpad.width - moveZoom.spacing
            width: beside >= sideMin ? beside : moveZoom.width
            spacing: Theme.spacingS

            StyledText {
                text: "Pan " + section.ctl.degrees(section.ctl.pan) + " · Tilt " + section.ctl.degrees(section.ctl.tilt)
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.features: { "tnum": 1 }
            }

            ChipRow {
                id: stepRow
                width: parent.width
                label: "Step"
                options: ["5°", "1°"]
                currentIndex: section.ctl.fineGimbal ? 1 : 0
                onSelected: index => section.ctl.fineGimbal = index === 1
            }

            LabeledSlider {
                width: parent.width
                label: "Zoom"
                // hundredths, so the field of view levels (1.15×, 1.47×) show exactly
                minimum: Math.round(section.ctl.zoomRange[0] * 100)
                maximum: Math.round(section.ctl.zoomRange[1] * 100)
                value: Math.round(section.ctl.zoomFactor * 100)
                formatValue: v => (v / 100).toFixed(2) + "×"
                onMoved: value => section.ctl.setZoom(value / 100)
            }
        }
    }

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Moving switches tracking to Static."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    Connections {
        target: section.ctl
        function onFineGimbalChanged() {
            stepRow.sync();
        }
    }

    // The pose the camera takes at power-on; shown only when obsbot4linux reports it
    Item {
        width: parent.width
        height: startRow.height
        visible: section.ctl.has("startup")

        Column {
            anchors.left: parent.left
            anchors.right: startRow.left
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: "Start pose"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
            }

            StyledText {
                width: parent.width
                visible: section.startPose !== null
                wrapMode: Text.WordWrap
                text: section.startPose ? "pan " + section.ctl.degrees(section.startPose.pan) + " · tilt " + section.ctl.degrees(section.startPose.tilt) + " · zoom " + Number(section.startPose.zoom).toFixed(2) + "×" : ""
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Row {
            id: startRow
            anchors.right: parent.right
            spacing: Theme.spacingS

            DButton {
                text: "Use current"
                iconName: "flag"
                onClicked: section.ctl.send(["startup", "set", "--current"], "Setting the start pose")
            }

            DButton {
                text: "Go"
                iconName: "start"
                onClicked: section.ctl.send(["startup", "go"], "Moving to the start pose")
            }
        }
    }

    // A setting stored in the camera; written only when picked here
    ChipRow {
        id: startModeRow
        width: parent.width
        stacked: true
        visible: section.ctl.has("startup") && section.ctl.has("startup_ai")
        label: "Start mode"
        options: section.startModes.map(m => m.label)
        currentIndex: section.startModeIndex
        onSelected: index => section.ctl.send(["startup", "set", "--ai", section.startModes[index].arg], "Setting the start mode", { state: { startup: Object.assign({}, section.startPose, { ai_mode: section.startModes[index].key || null }) } })
    }

    StyledText {
        width: parent.width
        visible: startModeRow.visible
        wrapMode: Text.WordWrap
        text: "With a start mode the camera tracks in it after \"Go\" and powers on in it. Without one, \"Go\" leaves tracking stopped until a mode is picked again."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    // A click assigns currentIndex and breaks the binding; re-sync to the camera state
    Connections {
        target: section.ctl
        function onStateRefreshed() {
            startModeRow.currentIndex = section.startModeIndex;
            startModeRow.sync();
        }
    }
}
