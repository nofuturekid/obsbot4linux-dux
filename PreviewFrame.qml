import QtQuick
import Quickshell.Widgets
import qs.Common
import qs.DCommon.Widgets

// The preview picture with its overlay: live video while the preview runs, otherwise a hint with
// one action (start preview, wake camera, retry when not reachable). Hovering the running video
// shows the same kind of hint over it, with a button to stop the preview. Fills the size it is
// given (the popout card makes it 16:9; the desktop widget lets the user resize it), the video is
// fitted inside. Used by the popout's PreviewPane and the desktop widget.
//
// ctl is what the frame needs from the camera: available, toolMissing, awake, live, previewReady,
// videoNode, previewOn (read/write), interactionActive, refresh(), setAwake(on), and optionally
// canFocusPoint and focusAt(x, y): a click on the running picture then focuses on that spot.
// interactive: false ignores hover and button (desktop edit mode).
ClippingRectangle {
    id: frame

    property var ctl
    property bool interactive: true
    // Desktop widget: drop the hint's text body when the resized frame is too small for it
    property bool dropBodyWhenTight: false

    // Without qt6-multimedia PreviewVideo.qml fails to load; the frame then says so
    readonly property bool videoMissing: videoLoader.status === Loader.Error
    readonly property bool previewShown: ctl.previewOn && ctl.live && !videoMissing
    readonly property bool overlayShown: !previewShown || (interactive && frameHover.hovered)
    readonly property bool focusClick: previewShown && interactive && (ctl.canFocusPoint ?? false)
    // The video is 16:9 and fitted inside the frame (PreserveAspectFit): bars at the sides or top
    readonly property real videoWidth: Math.min(width, height * 16 / 9)
    readonly property real videoHeight: videoWidth * 9 / 16
    readonly property var hint: previewShown
        ? { icon: "visibility", title: "Preview is on", body: "No other app can use the camera while it's on. Stop it before a call." + (focusClick ? " Click the picture to focus on that spot." : ""), button: "Stop preview", buttonIcon: "stop" }
        : !ctl.available
        ? (ctl.toolMissing
            ? { icon: "terminal", title: "Control tool not found", body: "obsbot4linux could not be run. Check that it is installed and on PATH.", button: "Retry", buttonIcon: "refresh" }
            : { icon: "usb_off", title: "Camera not connected", body: "The camera doesn't respond on USB. Plug it back in.", button: "Retry", buttonIcon: "refresh" })
        : videoMissing
            ? { icon: "extension_off", title: "Preview unavailable", body: "The live preview needs qt6-multimedia. All other controls work without it.", button: "Stop preview", buttonIcon: "stop" }
        : !ctl.awake
            ? { icon: "videocam_off", title: "Camera is asleep", body: "Lens is stowed face-down. Wake it to preview, track or adjust the picture.", button: "Wake camera", buttonIcon: "videocam" }
        : !ctl.previewReady
            ? { icon: "hourglass_empty", title: "Waiting for the camera", body: "The preview starts once the camera's video device is known.", button: "", buttonIcon: "" }
            : { icon: "visibility_off", title: "Preview is off", body: "Turn it on to see the picture while you adjust it. While it's on, no other app can use the camera.", button: "Start preview", buttonIcon: "play_arrow" }

    function hintAction() {
        if (!interactive)
            return;
        if (previewShown)
            ctl.previewOn = false;
        else if (!ctl.available)
            ctl.refresh();
        else if (videoMissing)
            ctl.previewOn = false;
        else if (!ctl.awake)
            ctl.setAwake(true);
        else if (ctl.previewReady)
            ctl.previewOn = true;
    }

    // ClippingRectangle: plain clip cuts square corners into the video
    color: Theme.surfaceContainerLowest
    radius: Theme.cornerRadius

    // Loaded in the background as soon as the popout opens (Qt Multimedia takes ~2 s to
    // load), so starting the preview only creates the camera
    Loader {
        id: videoLoader
        anchors.fill: parent
        active: frame.ctl.interactionActive
        asynchronous: true
        source: Qt.resolvedUrl("PreviewVideo.qml")
    }

    Binding {
        target: videoLoader.item
        property: "node"
        value: frame.ctl.videoNode
        when: videoLoader.status === Loader.Ready
    }

    Binding {
        target: videoLoader.item
        property: "running"
        value: frame.ctl.previewOn && frame.ctl.live
        when: videoLoader.status === Loader.Ready
    }

    // Experimental: the tracked target's box (target.box, normalised, read as left, top, right,
    // bottom) over the 16:9 video, which PreserveAspectFit centres in the frame
    Item {
        readonly property real videoWidth: Math.min(frame.width, frame.height * 16 / 9)
        readonly property var box: frame.ctl.cam?.target?.box ?? null
        x: (frame.width - width) / 2
        y: (frame.height - height) / 2
        width: videoWidth
        height: videoWidth * 9 / 16
        visible: frame.previewShown && (frame.ctl.showTargetBox ?? false) && box !== null && box.length === 4

        Rectangle {
            readonly property var b: parent.box ?? [0, 0, 0, 0]
            x: b[0] * parent.width
            y: b[1] * parent.height
            width: Math.max(0, (b[2] - b[0]) * parent.width)
            height: Math.max(0, (b[3] - b[1]) * parent.height)
            color: "transparent"
            radius: Theme.cornerRadius / 2
            border.width: 2
            // green while the camera has the target, warning colour while it searches
            border.color: frame.ctl.cam?.target?.detected === false ? Theme.warning : Theme.success

            Behavior on x { NumberAnimation { duration: 250 } }
            Behavior on y { NumberAnimation { duration: 250 } }
            Behavior on width { NumberAnimation { duration: 250 } }
            Behavior on height { NumberAnimation { duration: 250 } }
        }
    }

    // Click on the picture -> focus point, normalised to the video (not the frame, so the bars of
    // a letterboxed frame are ignored). Not mirrored or flipped here: with mirror or invert on the
    // firmware's coordinates are untested. The overlay's own button keeps its click.
    TapHandler {
        enabled: frame.focusClick
        onTapped: eventPoint => {
            const p = eventPoint.position;
            if (button.visible && button.contains(button.mapFromItem(frame, p.x, p.y)))
                return;
            const x = (p.x - (frame.width - frame.videoWidth) / 2) / frame.videoWidth;
            const y = (p.y - (frame.height - frame.videoHeight) / 2) / frame.videoHeight;
            if (x < 0 || x > 1 || y < 0 || y > 1)
                return;
            frame.ctl.focusAt(x, y);
            focusMark.x = p.x - focusMark.width / 2;
            focusMark.y = p.y - focusMark.height / 2;
            focusMarkFade.restart();
        }
    }

    // Shows for a moment where the click went
    Rectangle {
        id: focusMark
        width: Theme.iconSizeLarge
        height: width
        radius: Theme.cornerRadius
        color: "transparent"
        border.width: 2
        border.color: Theme.primary
        opacity: 0

        SequentialAnimation {
            id: focusMarkFade
            PropertyAction { target: focusMark; property: "opacity"; value: 1 }
            PauseAnimation { duration: 600 }
            NumberAnimation { target: focusMark; property: "opacity"; to: 0; duration: 400 }
        }
    }

    HoverHandler {
        id: frameHover
        enabled: frame.interactive
    }

    // Dims the video under the hint while hovering
    Rectangle {
        anchors.fill: parent
        visible: frame.previewShown && frame.overlayShown
        color: Theme.withAlpha(Theme.surfaceContainerLowest, 0.75)
    }

    Column {
        id: hintColumn
        anchors.centerIn: parent
        width: parent.width - Theme.spacingXL * 2
        spacing: Theme.spacingS
        visible: frame.overlayShown

        // With dropBodyWhenTight the text body goes when the frame is too small for icon, title, text and button
        readonly property bool bodyFits: !frame.dropBodyWhenTight || frame.height - Theme.spacingL * 2 >= icon.height + titleText.height + bodyText.implicitHeight + (button.visible ? button.height : 0) + spacing * (button.visible ? 3 : 2)

        DIcon {
            id: icon
            anchors.horizontalCenter: parent.horizontalCenter
            name: frame.hint.icon
            color: Theme.surfaceVariantText
            size: Theme.iconSizeLarge
        }

        StyledText {
            id: titleText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: frame.hint.title
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.DemiBold
        }

        StyledText {
            id: bodyText
            width: parent.width
            visible: hintColumn.bodyFits
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: frame.hint.body
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
        }

        DButton {
            id: button
            anchors.horizontalCenter: parent.horizontalCenter
            visible: frame.hint.button !== ""
            enabled: frame.interactive
            text: frame.hint.button
            iconName: frame.hint.buttonIcon
            onClicked: frame.hintAction()
        }
    }
}
