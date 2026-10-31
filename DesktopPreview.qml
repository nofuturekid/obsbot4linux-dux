import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Plugins

// Desktop surface of the plugin: a compact control panel (DesktopPanel: status, tracking mode,
// zoom, presets, sleep/wake) with an optional camera preview. "Show preview" swaps the panel for
// the picture (PreviewFrame with a slim overlay, PreviewControls); closing it frees the camera.
// Nothing here starts the preview by itself.
//
// This surface runs its own `obsbot4linux watch` (the bar widget, the Control Center tile and
// the popout are separate objects; the state is not shared between surfaces, only the
// "who runs a preview" flag, see PreviewClaim).
DesktopPluginComponent {
    id: root

    // The panel is a fixed-width card as high as its content; the preview is 16:9. DMS keeps one
    // saved size per widget, so each state asks for its own size with requestResize (transient,
    // not saved) and the saved size only matters while the desktop is being edited.
    readonly property real panelWidth: 320
    readonly property real previewWidth: 480
    readonly property real previewHeight: 270
    readonly property real defaultWidth: panelWidth
    readonly property real defaultHeight: 400
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

    // Same keys and arguments as ObsbotWidget.trackingModes (`obsbot4linux tracking <arg>`)
    readonly property var trackingModes: [
        { label: "Static", arg: "static", key: "static" },
        { label: "Normal Tracking", arg: "normal", key: "normal" },
        { label: "Upper Body", arg: "upper-body", key: "upper_body" },
        { label: "Close-up", arg: "close-up", key: "close_up" },
        { label: "Headless", arg: "headless", key: "headless" },
        { label: "Lower Body", arg: "lower-body", key: "lower_body" },
        { label: "Hand", arg: "hand", key: "hand" },
        { label: "Group", arg: "group", key: "group" }
    ]
    readonly property var status: cam.status ?? ({})
    readonly property string aiMode: trackingModes.find(m => m.key === status.ai_mode)?.label ?? ""
    readonly property real zoomFactor: cam.zoom?.factor ?? 1
    // [min, max] zoom factor; [1, 1] until obsbot4linux reported its limits
    readonly property var zoomRange: cam.limits?.zoom ?? [1, 1]
    // Another application reads the camera (the own preview is not counted: the panel shows no picture then)
    readonly property bool streaming: cam.streaming === true

    function has(name) {
        return (cam.capabilities ?? []).indexOf(name) >= 0;
    }

    // Sends `obsbot4linux <args>`; the answer is the next state event, errors are shown by the watcher
    function send(args) {
        if (watch.running)
            watch.write(++root.requestId, args);
    }

    function setAwake(on) {
        if (!watch.running)
            return;
        if (!on)
            previewOn = false;
        root.send([on ? "wake" : "sleep"]);
    }

    function setMode(index) {
        root.send(["tracking", root.trackingModes[index].arg]);
    }

    function setZoom(factor) {
        const next = Math.max(root.zoomRange[0], Math.min(root.zoomRange[1], Math.round(factor * 100) / 100));
        root.send(["zoom", next.toFixed(2)]);
    }

    // The +/- buttons: 0.5 per click within the range
    function stepZoom(delta) {
        root.setZoom(root.zoomFactor + delta);
    }

    // Presets stored in the camera: null until `preset list` has answered, [{slot, name, pose}]
    // for the slots in use (empty slots are not listed)
    property var presets: null
    property bool presetsFailed: false
    property int presetListId: 0

    function refreshPresets() {
        if (!watch.running)
            return;
        root.presetsFailed = false;
        root.presetListId = ++root.requestId;
        watch.write(root.presetListId, ["preset", "list"]);
        presetTimeout.restart();
    }

    function recallPreset(slot) {
        root.send(["preset", "recall", slot]);
    }

    function handleReply(msg) {
        if (msg.id !== root.presetListId)
            return;
        root.presetListId = 0;
        const list = msg.result?.value;
        // not Array.isArray: the reply went through a signal, which hands arrays over as list
        // wrappers that fail it
        if (msg.ok !== false && list && typeof list.length === "number") {
            root.presets = Array.from(list);
            root.presetsFailed = false;
            presetTimeout.stop();
        } else {
            root.presetsFailed = true;
        }
    }

    // The list is read when the camera shows up (and again after a watch restart), not with every event
    readonly property bool presetsWanted: available && has("preset") && !editing
    onPresetsWantedChanged: {
        if (presetsWanted)
            refreshPresets();
    }

    Timer {
        id: presetTimeout
        interval: 8000
        onTriggered: {
            if (root.presets === null)
                root.presetsFailed = true;
        }
    }

    // Preview size and panel size: transient override, see panelWidth
    readonly property bool previewShown: previewOn && !editing
    function applySize() {
        if (!requestResize || !clearResize)
            return;
        if (editing)
            clearResize();
        else if (previewShown)
            requestResize(previewWidth, previewHeight);
        else if (panel.implicitHeight > 0)
            requestResize(panelWidth, panel.implicitHeight);
    }
    onPreviewShownChanged: applySize()
    onEditingChanged: applySize()
    onRequestResizeChanged: applySize()
    Component.onCompleted: applySize()

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
        onReply: msg => root.handleReply(msg)
        onStopped: {
            root.cam = ({});
            root.presets = null;
            root.presetListId = 0;
            root.presetsFailed = false;
            presetTimeout.stop();
        }
    }

    DesktopPanel {
        id: panel
        visible: !root.previewShown
        width: parent.width
        ctl: root
        interactive: !root.editing
        onImplicitHeightChanged: root.applySize()
    }

    PreviewFrame {
        id: frame
        anchors.fill: parent
        visible: root.previewShown
        ctl: root
        interactive: !root.editing
        slimOverlay: true

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

        PreviewControls {
            anchors.fill: parent
            ctl: root
            shown: frame.previewShown && frame.overlayShown
        }
    }
}
