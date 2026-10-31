import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Pan/tilt and zoom
SectionCard {
    id: section

    property var ctl
    readonly property var startPose: ctl.cam.state?.startup ?? null

    title: "Framing"
    enabled: ctl.live || arranging
    opacity: ctl.live || arranging ? 1 : 0.38

    Row {
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
            width: parent.width - dpad.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS

            StyledText {
                text: "Pan " + section.ctl.degrees(section.ctl.pan) + " · Tilt " + section.ctl.degrees(section.ctl.tilt)
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.features: { "tnum": 1 }
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                text: section.ctl.gimbalStep + "° per step. Moving switches tracking to Static."
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    ToggleRow {
        width: parent.width
        label: "Fine steps"
        description: "1° per click instead of 5°"
        checked: section.ctl.fineGimbal
        onToggled: checked => section.ctl.fineGimbal = checked
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

    // The pose the camera takes at power-on; shown only when obsbot4linux reports it
    Flow {
        width: parent.width
        spacing: Theme.spacingS
        visible: section.ctl.has("startup")

        DButton {
            text: "Use current pose as start pose"
            iconName: "flag"
            onClicked: section.ctl.send(["startup", "set", "--current"], "Setting the start pose")
        }

        DButton {
            text: "Go to start pose"
            iconName: "start"
            onClicked: section.ctl.send(["startup", "go"], "Moving to the start pose")
        }
    }

    StyledText {
        width: parent.width
        visible: section.ctl.has("startup") && section.startPose !== null
        wrapMode: Text.WordWrap
        text: section.startPose ? "Start pose: pan " + section.ctl.degrees(section.startPose.pan) + " · tilt " + section.ctl.degrees(section.startPose.tilt) + " · zoom " + Number(section.startPose.zoom).toFixed(2) + "×" : ""
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }
}
