import QtQuick
import qs.Common
import qs.DCommon.Common
import qs.DCommon.Widgets

// Bottom row of the desktop widget card, full card width: zoom (slider with - / +) on the left,
// the camera's three preset slots in the middle, Sleep / Wake at the right end (Retry when the
// camera is not reachable). No background; zoom and presets are greyed out (not hidden) while the
// camera is not live, so the card keeps its size.
//
// ctl is the DesktopPreview: available, awake, live, zoomFactor, zoomRange, presets, presetsFailed,
// has(), setZoom(), stepZoom(), recallPreset(), refreshPresets(), setAwake(), refresh().
// interactive: false ignores the buttons (desktop edit mode).
Item {
    id: bottom

    property var ctl
    property bool interactive: true

    // what is left of the row besides the Sleep / Wake button, split 1 : 1
    readonly property real sectionWidth: (width - powerButton.width - Theme.spacingL * 2) / 2

    implicitHeight: Math.max(zoomItem.height, presetsColumn.height, powerButton.height)

    DButton {
        id: powerButton
        anchors.right: parent.right
        anchors.bottom: parent.bottom
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

    // Zoom: slider with the value above it, -/+ beside it on the slider's line
    Item {
        id: zoomItem
        width: bottom.sectionWidth
        height: zoomSlider.height
        enabled: bottom.ctl.live && bottom.interactive
        opacity: bottom.ctl.live ? 1 : 0.38

        DButton {
            id: zoomOut
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            iconName: "remove"
            minimumWidth: 0
            tooltipText: "Zoom out"
            enabled: bottom.ctl.zoomFactor > bottom.ctl.zoomRange[0]
            onClicked: bottom.ctl.stepZoom(-0.5)
        }

        LabeledSlider {
            id: zoomSlider
            anchors.left: zoomOut.right
            anchors.right: zoomIn.left
            anchors.margins: Theme.spacingS
            label: "Zoom"
            // tenths, the step the buttons and the wheel use
            minimum: Math.round(bottom.ctl.zoomRange[0] * 10)
            maximum: Math.round(bottom.ctl.zoomRange[1] * 10)
            value: Math.round(bottom.ctl.zoomFactor * 10)
            formatValue: v => (v / 10).toFixed(1) + "×"
            onReleased: value => bottom.ctl.setZoom(value / 10)
        }

        DButton {
            id: zoomIn
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            iconName: "add"
            minimumWidth: 0
            tooltipText: "Zoom in"
            enabled: bottom.ctl.zoomFactor < bottom.ctl.zoomRange[1]
            onClicked: bottom.ctl.stepZoom(0.5)
        }
    }

    // Slots in use only; an empty slot has nothing to recall
    Column {
        id: presetsColumn
        x: bottom.sectionWidth + Theme.spacingL
        width: bottom.sectionWidth
        spacing: Theme.spacingS
        enabled: bottom.ctl.live && bottom.interactive
        opacity: bottom.ctl.live ? 1 : 0.38
        visible: bottom.ctl.has("preset")

        StyledText {
            text: "Presets"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
        }

        // Three equal slots in slot order; an empty slot leaves its place blank, so a preset keeps
        // its position and colour (slot 1 primary, 2 secondary, 3 tertiary). Long names are elided
        // in the button and shown in full as the tooltip.
        Row {
            id: slotRow
            width: parent.width
            height: Style.buttonHeightS
            spacing: Theme.spacingS
            visible: (bottom.ctl.presets?.length ?? 0) > 0

            readonly property real slotWidth: (width - spacing * 2) / 3
            readonly property var slotColors: [
                { bg: Theme.primaryContainer, fg: Theme.onPrimaryContainer },
                { bg: Theme.secondaryContainer, fg: Theme.onSecondaryContainer },
                { bg: Theme.tertiaryContainer, fg: Theme.onTertiaryContainer }
            ]

            Repeater {
                    model: [0, 1, 2]

                delegate: Item {
                    id: slotItem

                    required property int modelData
                    readonly property var preset: (bottom.ctl.presets ?? []).find(p => p.slot === modelData) ?? null

                    width: slotRow.slotWidth
                    height: slotRow.height

                    DButton {
                        visible: slotItem.preset !== null
                        width: parent.width
                        minimumWidth: 0
                        maximumWidth: slotRow.slotWidth
                        text: slotItem.preset?.name ?? ""
                        tooltipText: slotItem.preset?.name ?? ""
                        backgroundColor: slotRow.slotColors[slotItem.modelData].bg
                        textColor: slotRow.slotColors[slotItem.modelData].fg
                        onClicked: bottom.ctl.recallPreset(slotItem.modelData)
                    }
                }
            }
        }

        StyledText {
            width: parent.width
            visible: (bottom.ctl.presets?.length ?? 0) === 0
            text: bottom.ctl.presets === null ? (bottom.ctl.presetsFailed ? "Could not read the presets" : "Reading presets…") : "No presets saved"
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
        }

        DButton {
            visible: bottom.ctl.presetsFailed
            text: "Retry reading presets"
            iconName: "refresh"
            onClicked: bottom.ctl.refreshPresets()
        }
    }
}
