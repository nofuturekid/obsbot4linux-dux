import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Plugins

// Desktop surface of the plugin: the camera preview as a free-standing widget, with the same
// start/stop overlay as the popout (PreviewFrame). Nothing here starts the preview by itself.
//
// This surface runs its own `obsbot4linux watch` (the bar widget, the Control Center tile and
// the popout are separate objects; the state is not shared between surfaces, only the
// "who runs a preview" flag, see PreviewClaim).
DesktopPluginComponent {
    id: root

    // Geometry defaults and limits: 16:9, the smallest size still shows icon, title and button
    readonly property real defaultWidth: 480
    readonly property real defaultHeight: 270
    minWidth: 240
    minHeight: 135

    // DMS unloads desktop widgets while the desktop is being edited, but the editor shows its own
    // copy of them: that one is inert
    readonly property bool editing: DesktopWidgetRegistry.editing

    // Set by DMS (DesktopWidgetContent) when the component declares it; for the log
    property var screen: null

    // Camera state from obsbot4linux watch, same fields as the popout reads
    property var cam: ({})
    // The bar widget's "Show target box" switch (a global plugin setting, not this instance's).
    // SettingsData replaces pluginSettings on every save, so the binding follows at once.
    readonly property bool showTargetBox: SettingsData.pluginSettings[pluginId]?.showTargetBox ?? false
    readonly property bool toolMissing: watch.toolMissing
    readonly property string videoNode: watch.videoNode
    property bool previewOn: false
    property int requestId: 0

    readonly property bool available: cam.available === true
    readonly property bool awake: available && cam.status?.asleep === false
    readonly property bool live: available && awake
    readonly property string device: cam.device ?? ""
    readonly property bool previewReady: device !== "" && videoNode !== ""
    // Loads Qt Multimedia; not while editing
    readonly property bool interactionActive: !editing

    // Stop rules: whenever the picture cannot be live any more (camera asleep, unplugged, lost),
    // and while editing. DMS also unloads the widget when it is disabled or removed, which
    // closes the camera. Otherwise the preview keeps running until the user stops it.
    onLiveChanged: {
        if (!live)
            previewOn = false;
    }
    onEditingChanged: {
        if (editing)
            previewOn = false;
    }

    function setAwake(on) {
        if (!watch.running)
            return;
        if (!on)
            previewOn = false;
        watch.write(++root.requestId, [on ? "wake" : "sleep"]);
    }

    // Click on the picture: focus once on that spot (x, y 0..1 from the top left)
    readonly property bool canFocusPoint: live && (cam.capabilities ?? []).indexOf("focus_point") >= 0
    function focusAt(x, y) {
        if (watch.running)
            watch.write(++root.requestId, ["focus", "point", Math.round(x * 100) / 100, Math.round(y * 100) / 100]);
    }

    // Retry button: start the watcher again now
    function refresh() {
        watch.refresh();
    }

    // One preview at a time: starting one in the popout switches this one off and vice versa
    PreviewClaim {
        pluginId: root.pluginId
        holding: root.previewOn
        onDisplaced: root.previewOn = false
    }

    // Errors are logged and shown as a toast by the watcher
    CameraWatch {
        id: watch
        active: true
        instanceName: "desktop widget" + (root.screen?.name ? " on screen " + root.screen.name : "")
        device: root.device
        onStateEvent: next => root.cam = next
        onStopped: root.cam = ({})
    }

    PreviewFrame {
        id: frame
        anchors.fill: parent
        ctl: root
        interactive: !root.editing
        dropBodyWhenTight: true

        // On air while the picture is live (the hover overlay keeps it visible)
        Rectangle {
            visible: frame.previewShown
            width: Theme.spacingM
            height: width
            radius: width / 2
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.spacingS
            color: Theme.error
        }
    }
}
