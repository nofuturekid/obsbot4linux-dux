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

    // Width the column needs: the widest pair of neighbouring mode chips side by side, and the widest
    // single speed chip. Measured from real chips (the hidden DFilterChips below lay out in one
    // row), so it follows the font and theme. The owner sizes the column to this, the chips wrap in it.
    readonly property real naturalWidth: {
        const spacing = measureModes.spacing;
        // the Repeater is a child too, with no width
        const modes = Array.from(measureModes.children).filter(c => c.width > 0);
        const speeds = Array.from(measureSpeeds.children).filter(c => c.width > 0);
        let widest = 0;
        for (let i = 0; i < side.ctl.trackingModes.length; i += 2) {
            const a = modes[i]?.width ?? 0;
            const b = modes[i + 1]?.width ?? 0;
            widest = Math.max(widest, a + (b > 0 ? spacing + b : 0));
        }
        for (let i = 0; i < side.ctl.speedOptions.length; i++)
            widest = Math.max(widest, speeds[i]?.width ?? 0);
        return Math.ceil(widest);
    }

    DFilterChips {
        id: measureModes
        visible: false
        width: 100000
        showCheck: false
        model: side.ctl.trackingModes.map(m => m.label)
    }

    DFilterChips {
        id: measureSpeeds
        visible: false
        width: 100000
        showCheck: false
        model: side.ctl.speedOptions.map(m => m.label)
    }

    // A click assigns currentIndex and breaks its binding; follow the camera state again
    Connections {
        target: side.ctl
        function onCamChanged() {
            modeRow.sync();
            speedRow.sync();
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

    ChipRow {
        id: modeRow
        anchors.top: statusItem.bottom
        anchors.topMargin: Theme.spacingM
        anchors.left: parent.left
        anchors.right: parent.right
        stacked: true
        label: "Tracking mode"
        enabled: side.usable
        opacity: side.ctl.live ? 1 : 0.38
        options: side.ctl.trackingModes.map(m => m.label)
        currentIndex: side.modeIndex()
        onSelected: index => side.ctl.setMode(index)
    }

    ChipRow {
        id: speedRow
        anchors.top: modeRow.bottom
        anchors.topMargin: Theme.spacingM
        anchors.left: parent.left
        anchors.right: parent.right
        stacked: true
        label: "Tracking speed"
        enabled: side.usable
        opacity: side.ctl.live ? 1 : 0.38
        options: side.ctl.speedOptions.map(m => m.label)
        currentIndex: side.speedIndex()
        onSelected: index => side.ctl.setSpeed(index)
    }
}
