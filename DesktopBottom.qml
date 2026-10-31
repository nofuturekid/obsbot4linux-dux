import QtQuick
import qs.Common
import qs.DCommon.Common
import qs.DCommon.Widgets

// Bottom row of the desktop widget card, full card width: zoom (- / slider / +) on the left,
// the camera's three preset slots in the middle, Sleep / Wake at the right end (Retry when the
// camera is not reachable). No background; zoom and presets are greyed out (not hidden) while the
// camera is not live, so the card keeps its size.
//
// ctl is the DesktopPreview: available, awake, live, zoomFactor, zoomRange, presets, presetsFailed,
// has(), setZoom(), stepZoom(), recallPreset(), refreshPresets(), setAwake(), refresh().
// Two lines: the labels (Zoom with its value, Presets), then the controls, all of one height
// (Style.buttonHeightS) and centred on one line.
// interactive: false ignores the buttons (desktop edit mode).
Item {
    id: bottom

    property var ctl
    property bool interactive: true

    // what is left of the row besides the Sleep / Wake button, split 1 : 1
    readonly property real sectionWidth: (width - powerButton.width - Theme.spacingL * 2) / 2
    // the one height of every control on the second line
    readonly property real controlHeight: Style.buttonHeightS
    readonly property bool zoomEnabled: ctl.live && interactive

    implicitHeight: labels.height + Theme.spacingS + controlHeight

    // First line: the labels
    Item {
        id: labels
        width: parent.width
        height: zoomLabel.implicitHeight

        StyledText {
            id: zoomLabel
            x: 0
            text: "Zoom"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
            opacity: bottom.ctl.live ? 1 : 0.38
        }

        StyledText {
            x: bottom.sectionWidth - width
            text: (zoomSlider.value / 10).toFixed(1) + "×"
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
            opacity: bottom.ctl.live ? 1 : 0.38
        }

        StyledText {
            x: bottom.sectionWidth + Theme.spacingL
            visible: bottom.ctl.has("preset")
            text: "Presets"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
            opacity: bottom.ctl.live ? 1 : 0.38
        }
    }

    // Second line: -, slider, +, the three preset slots, Sleep / Wake
    Item {
        id: controls
        anchors.top: labels.bottom
        anchors.topMargin: Theme.spacingS
        width: parent.width
        height: bottom.controlHeight

        Item {
            id: zoomItem
            width: bottom.sectionWidth
            height: parent.height
            enabled: bottom.zoomEnabled
            opacity: bottom.ctl.live ? 1 : 0.38

            DButton {
                id: zoomOut
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                buttonHeight: bottom.controlHeight
                iconName: "remove"
                minimumWidth: 0
                tooltipText: "Zoom out"
                enabled: bottom.ctl.zoomFactor > bottom.ctl.zoomRange[0]
                onClicked: bottom.ctl.stepZoom(-0.5)
            }

            DSlider {
                id: zoomSlider
                anchors.left: zoomOut.right
                anchors.right: zoomIn.left
                anchors.margins: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                showValue: false
                // tenths, the step the buttons and the wheel use
                minimum: Math.round(bottom.ctl.zoomRange[0] * 10)
                maximum: Math.round(bottom.ctl.zoomRange[1] * 10)
                value: Math.round(bottom.ctl.zoomFactor * 10)
                onSliderDragFinished: finalValue => bottom.ctl.setZoom(finalValue / 10)
            }

            DButton {
                id: zoomIn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                buttonHeight: bottom.controlHeight
                iconName: "add"
                minimumWidth: 0
                tooltipText: "Zoom in"
                enabled: bottom.ctl.zoomFactor < bottom.ctl.zoomRange[1]
                onClicked: bottom.ctl.stepZoom(0.5)
            }
        }

        // Three equal slots in slot order; an empty slot leaves its place blank, so a preset keeps
        // its position. Long names are elided in the button and shown in full as the tooltip.
        Item {
            id: presetsItem
            x: bottom.sectionWidth + Theme.spacingL
            width: bottom.sectionWidth
            height: parent.height
            enabled: bottom.zoomEnabled
            opacity: bottom.ctl.live ? 1 : 0.38
            visible: bottom.ctl.has("preset")

            readonly property bool anySaved: (bottom.ctl.presets?.length ?? 0) > 0
            readonly property real slotWidth: (width - Theme.spacingS * 2) / 3

            PresetSlot {
                x: 0
                width: presetsItem.slotWidth
                height: parent.height
                visible: presetsItem.anySaved
                ctl: bottom.ctl
                slotIndex: 0
            }

            PresetSlot {
                x: presetsItem.slotWidth + Theme.spacingS
                width: presetsItem.slotWidth
                height: parent.height
                visible: presetsItem.anySaved
                ctl: bottom.ctl
                slotIndex: 1
            }

            PresetSlot {
                x: (presetsItem.slotWidth + Theme.spacingS) * 2
                width: presetsItem.slotWidth
                height: parent.height
                visible: presetsItem.anySaved
                ctl: bottom.ctl
                slotIndex: 2
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                elide: Text.ElideRight
                visible: !presetsItem.anySaved
                text: bottom.ctl.presets === null ? (bottom.ctl.presetsFailed ? "Could not read the presets" : "Reading presets…") : "No presets saved"
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        DButton {
            id: powerButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            buttonHeight: bottom.controlHeight
            enabled: bottom.interactive
            text: !bottom.ctl.available ? "Retry" : bottom.ctl.awake ? "Sleep" : "Wake"
            iconName: !bottom.ctl.available ? "refresh" : bottom.ctl.awake ? "bedtime" : "videocam"
            onClicked: {
                if (!bottom.ctl.available)
                    bottom.ctl.refresh();
                else
                    bottom.ctl.setAwake(!bottom.ctl.awake);
            }
        }
    }
}
