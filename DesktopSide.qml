import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Right column of the desktop widget card, as high as the picture: status line with the on-air
// dot, tracking mode chips and tracking speed chips. It has no background; the controls grey
// out (not hide) when the camera is asleep or offline.
//
// ctl is the DesktopPreview: available, toolMissing, awake, live, streaming, aiMode,
// trackingModes, speedOptions, status, setMode(), setSpeed().
// interactive: false ignores the chips (desktop edit mode).
Item {
    id: side

    property var ctl
    property bool interactive: true

    readonly property bool usable: ctl.live && interactive
    readonly property string title: !ctl.available ? "Offline" : ctl.awake ? "Awake" : "Asleep"
    readonly property string subtitle: !ctl.available ? (ctl.toolMissing ? "Control tool not found" : "Camera not connected") : ctl.awake ? ctl.aiMode : "Lens stowed"

    function modeIndex() {
        return side.ctl.live ? side.ctl.trackingModes.findIndex(m => m.key === side.ctl.status.ai_mode) : -1;
    }
    function speedIndex() {
        return side.ctl.live ? side.ctl.speedOptions.findIndex(m => m.arg === side.ctl.status.tracking_speed) : -1;
    }

    // A click assigns currentIndex and breaks its binding; follow the camera state again
    Connections {
        target: side.ctl
        function onCamChanged() {
            modeRow.currentIndex = side.modeIndex();
            speedRow.currentIndex = side.speedIndex();
        }
    }

    Item {
        id: statusItem
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: statusText.implicitHeight

        Column {
            id: statusText
            anchors.left: parent.left
            anchors.right: airRow.visible ? airRow.left : parent.right
            anchors.rightMargin: Theme.spacingS

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                text: side.title
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
            }

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                text: side.subtitle
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
            visible: side.ctl.available && side.ctl.streaming

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

    ChipGrid {
        id: modeRow
        anchors.top: statusItem.bottom
        anchors.topMargin: Theme.spacingM
        anchors.left: parent.left
        anchors.right: parent.right
        label: "Tracking mode"
        enabled: side.usable
        opacity: side.ctl.live ? 1 : 0.38
        options: side.ctl.trackingModes.map(m => m.label)
        currentIndex: side.modeIndex()
        onSelected: index => side.ctl.setMode(index)
    }

    ChipGrid {
        id: speedRow
        anchors.top: modeRow.bottom
        anchors.topMargin: Theme.spacingM
        anchors.left: parent.left
        anchors.right: parent.right
        label: "Tracking speed"
        enabled: side.usable
        opacity: side.ctl.live ? 1 : 0.38
        options: side.ctl.speedOptions.map(m => m.label)
        currentIndex: side.speedIndex()
        onSelected: index => side.ctl.setSpeed(index)
    }
}
