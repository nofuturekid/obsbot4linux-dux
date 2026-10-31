import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Slim hover overlay of the desktop widget's preview: the status on top, below it tracking mode
// chips, zoom -/+ and "Close preview". Presets stay in the panel. Sits over the picture inside
// PreviewFrame (slimOverlay), which decides when it is shown (hover).
//
// ctl is the DesktopPreview: aiMode, trackingModes, status, zoomFactor, zoomRange, setMode(),
// stepZoom(), previewOn (write).
Item {
    id: overlay

    property var ctl
    property bool shown: false

    visible: shown

    // A click assigns currentIndex and breaks its binding; follow the camera state again
    Connections {
        target: overlay.ctl
        function onCamChanged() {
            modeChips.currentIndex = overlay.ctl.trackingModes.findIndex(m => m.key === overlay.ctl.status.ai_mode);
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: topText.implicitHeight + Theme.spacingS * 2
        color: Theme.withAlpha(Theme.surfaceContainer, 0.8)

        StyledText {
            id: topText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.spacingM
            elide: Text.ElideRight
            text: "Awake · " + overlay.ctl.aiMode + " · " + overlay.ctl.zoomFactor.toFixed(1) + "×"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: controls.implicitHeight + Theme.spacingM * 2
        color: Theme.withAlpha(Theme.surfaceContainer, 0.8)

        Column {
            id: controls
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            DFilterChips {
                id: modeChips
                showCheck: false
                width: parent.width
                model: overlay.ctl.trackingModes.map(m => m.label)
                currentIndex: overlay.ctl.trackingModes.findIndex(m => m.key === overlay.ctl.status.ai_mode)
                onSelectionChanged: index => overlay.ctl.setMode(index)
            }

            Item {
                width: parent.width
                height: closeButton.implicitHeight

                Row {
                    spacing: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter

                    DButton {
                        iconName: "remove"
                        minimumWidth: 0
                        tooltipText: "Zoom out"
                        enabled: overlay.ctl.zoomFactor > overlay.ctl.zoomRange[0]
                        onClicked: overlay.ctl.stepZoom(-0.5)
                    }

                    DButton {
                        iconName: "add"
                        minimumWidth: 0
                        tooltipText: "Zoom in"
                        enabled: overlay.ctl.zoomFactor < overlay.ctl.zoomRange[1]
                        onClicked: overlay.ctl.stepZoom(0.5)
                    }
                }

                DButton {
                    id: closeButton
                    anchors.right: parent.right
                    text: "Close preview"
                    iconName: "stop"
                    onClicked: overlay.ctl.previewOn = false
                }
            }
        }
    }
}
