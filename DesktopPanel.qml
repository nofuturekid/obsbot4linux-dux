import QtQuick
import qs.Common
import qs.DCommon.Widgets

// The desktop widget's control panel, below the picture area: status line with the on-air dot,
// tracking mode, zoom, the camera's preset slots in use and Sleep / Wake (Retry when the camera is
// not reachable). It sits in the widget card (DesktopPreview) and has no background of its own.
// The size stays the same when the camera is asleep or offline: the controls grey out.
//
// ctl is the DesktopPreview: available, toolMissing, awake, live, streaming, aiMode,
// trackingModes, status, zoomFactor, zoomRange, presets, presetsFailed,
// setMode(), setZoom(), stepZoom(), recallPreset(), refreshPresets(), setAwake(), refresh().
// interactive: false ignores the buttons (desktop edit mode).
Item {
    id: panel

    property var ctl
    property bool interactive: true

    readonly property bool usable: ctl.live && interactive
    readonly property string title: !ctl.available ? "Offline" : ctl.awake ? "Awake" : "Asleep"
    readonly property string subtitle: !ctl.available ? (ctl.toolMissing ? "Control tool not found" : "Camera not connected") : ctl.awake ? ctl.aiMode : "Lens stowed"

    // A click assigns currentIndex and breaks its binding; follow the camera state again
    Connections {
        target: panel.ctl
        function onCamChanged() {
            modeRow.sync();
        }
    }

    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: panel.width
        spacing: Theme.spacingM

        Item {
            width: parent.width
            height: statusText.implicitHeight

            Column {
                id: statusText
                anchors.left: parent.left
                anchors.right: airRow.left
                anchors.rightMargin: Theme.spacingS

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: panel.title
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                }

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: panel.subtitle
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            // Another application reads the camera
            Row {
                id: airRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS
                visible: panel.ctl.available && panel.ctl.streaming

                Rectangle {
                    width: Theme.spacingM
                    height: width
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.error
                }

                StyledText {
                    text: "On air"
                    color: Theme.error
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                }
            }
        }

        // Greyed out (not hidden) without a live camera, so the card keeps its size
        Column {
            width: parent.width
            spacing: Theme.spacingM
            enabled: panel.usable
            opacity: panel.ctl.live ? 1 : 0.38

            ChipRow {
                id: modeRow
                width: parent.width
                stacked: true
                label: "Tracking mode"
                options: panel.ctl.trackingModes.map(m => m.label)
                currentIndex: panel.ctl.live ? panel.ctl.trackingModes.findIndex(m => m.key === panel.ctl.status.ai_mode) : -1
                onSelected: index => panel.ctl.setMode(index)
            }

            // Zoom: slider with the value above it, -/+ beside it on the slider's line
            Item {
                width: parent.width
                height: zoomSlider.height

                DButton {
                    id: zoomOut
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    iconName: "remove"
                    minimumWidth: 0
                    tooltipText: "Zoom out"
                    enabled: panel.ctl.zoomFactor > panel.ctl.zoomRange[0]
                    onClicked: panel.ctl.stepZoom(-0.5)
                }

                LabeledSlider {
                    id: zoomSlider
                    anchors.left: zoomOut.right
                    anchors.right: zoomIn.left
                    anchors.margins: Theme.spacingS
                    label: "Zoom"
                    // tenths, the step the buttons and the wheel use
                    minimum: Math.round(panel.ctl.zoomRange[0] * 10)
                    maximum: Math.round(panel.ctl.zoomRange[1] * 10)
                    value: Math.round(panel.ctl.zoomFactor * 10)
                    formatValue: v => (v / 10).toFixed(1) + "×"
                    onReleased: value => panel.ctl.setZoom(value / 10)
                }

                DButton {
                    id: zoomIn
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    iconName: "add"
                    minimumWidth: 0
                    tooltipText: "Zoom in"
                    enabled: panel.ctl.zoomFactor < panel.ctl.zoomRange[1]
                    onClicked: panel.ctl.stepZoom(0.5)
                }
            }

            // Slots in use only; an empty slot has nothing to recall
            Column {
                width: parent.width
                spacing: Theme.spacingS
                visible: panel.ctl.has("preset")

                StyledText {
                    text: "Presets"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: (panel.ctl.presets?.length ?? 0) > 0

                    Repeater {
                        model: panel.ctl.presets ?? []

                        delegate: DButton {
                            required property var modelData
                            text: modelData.name
                            iconName: "my_location"
                            maximumWidth: column.width
                            onClicked: panel.ctl.recallPreset(modelData.slot)
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    visible: (panel.ctl.presets?.length ?? 0) === 0
                    text: panel.ctl.presets === null ? (panel.ctl.presetsFailed ? "Could not read the presets" : "Reading presets…") : "No presets saved"
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }

                DButton {
                    visible: panel.ctl.presetsFailed
                    text: "Retry reading presets"
                    iconName: "refresh"
                    onClicked: panel.ctl.refreshPresets()
                }
            }
        }

        // Starting and stopping the preview is the picture area's own button
        DButton {
            anchors.right: parent.right
            enabled: panel.interactive
            text: !panel.ctl.available ? "Retry" : panel.ctl.awake ? "Sleep" : "Wake"
            iconName: !panel.ctl.available ? "refresh" : panel.ctl.awake ? "bedtime" : "videocam"
            onClicked: {
                if (!panel.ctl.available)
                    panel.ctl.refresh();
                else
                    panel.ctl.setAwake(!panel.ctl.awake);
            }
        }
    }
}
