import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Bottom row of the desktop widget card, full card width: zoom (slider with - / +) on the left
// half, the camera's preset slots in use on the right half. No background; greyed out (not
// hidden) while the camera is not live, so the card keeps its size.
//
// ctl is the DesktopPreview: live, zoomFactor, zoomRange, presets, presetsFailed, has(),
// setZoom(), stepZoom(), recallPreset(), refreshPresets().
// interactive: false ignores the buttons (desktop edit mode).
Item {
    id: bottom

    property var ctl
    property bool interactive: true

    readonly property real halfWidth: (width - Theme.spacingL) / 2

    implicitHeight: Math.max(zoomItem.height, presetsColumn.height)
    enabled: ctl.live && interactive
    opacity: ctl.live ? 1 : 0.38

    // Zoom: slider with the value above it, -/+ beside it on the slider's line
    Item {
        id: zoomItem
        width: bottom.halfWidth
        height: zoomSlider.height

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
        x: bottom.halfWidth + Theme.spacingL
        width: bottom.halfWidth
        spacing: Theme.spacingS
        visible: bottom.ctl.has("preset")

        StyledText {
            text: "Presets"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
        }

        Flow {
            width: parent.width
            spacing: Theme.spacingS
            visible: (bottom.ctl.presets?.length ?? 0) > 0

            Repeater {
                model: bottom.ctl.presets ?? []

                delegate: DButton {
                    required property var modelData
                    text: modelData.name
                    iconName: "my_location"
                    maximumWidth: presetsColumn.width
                    onClicked: bottom.ctl.recallPreset(modelData.slot)
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
