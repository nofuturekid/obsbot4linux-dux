import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Plugins

// Desktop surface of the plugin, one fixed layout like the popout: the picture area on top
// (PreviewFrame: dark with the "Preview is off" hint and Start button, live picture while the
// preview runs, Stop on hover) and the control panel below it (DesktopPanel: status, tracking mode,
// zoom, presets, sleep/wake). Nothing here starts the preview by itself.
//
// This surface runs its own `obsbot4linux watch` (the bar widget, the Control Center tile and
// the popout are separate objects; the state is not shared between surfaces, only the
// "who runs a preview" flag, see PreviewClaim).
DesktopPluginComponent {
    id: root

    // Fixed layout, one card: the 16:9 picture (640 x 360) with the status, tracking mode and
    // Sleep / Wake in a column to its right and zoom and presets in a row below it. DMS keeps one
    // saved size per widget and the bottom row's height depends on the fonts and the presets, so
    // the widget asks once for the size of its content with requestResize (transient, not saved).
    // Without it the saved size applies.
    readonly property real pictureWidth: 640
    // the side column is as wide as its widest chip row (measured, see DesktopSide.naturalWidth)
    readonly property real sideWidth: sideColumn.naturalWidth
    readonly property real contentWidth: pictureWidth + sideWidth + Theme.spacingM + Theme.spacingL * 2
    readonly property real defaultWidth: contentWidth
    readonly property real defaultHeight: 520
    minWidth: 240
    minHeight: 135

    // DMS unloads desktop widgets while the desktop is being edited, but the editor shows its own
    // copy of them: that one is inert
    readonly property bool editing: DesktopWidgetRegistry.editing

    // Set by DMS (DesktopWidgetContent) when the component declares it; for the log
    property var screen: null

    // Camera state from obsbot4linux watch, same fields as the popout reads, with the changes sent
    // but not yet confirmed by an event on top (OptimisticState, like the popout)
    property alias cam: optimistic.cam
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

    // Stop rules: whenever the camera goes away (unplugged, lost) or falls asleep while the preview
    // was running (a preview started while it sleeps stays on: opening the stream wakes it, #93),
    // and while editing. DMS also unloads the widget when it is disabled or removed, which
    // closes the camera. Otherwise the preview keeps running until the user stops it.
    property bool previewWasAwake: false
    onPreviewOnChanged: previewWasAwake = previewOn && awake
    onAwakeChanged: {
        if (awake) {
            if (previewOn)
                previewWasAwake = true;
        } else if (previewWasAwake) {
            previewOn = false;
        }
    }
    onAvailableChanged: {
        if (!available)
            previewOn = false;
    }
    onEditingChanged: {
        if (editing)
            previewOn = false;
        applySize();
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
    // Same as ObsbotWidget.speeds (`obsbot4linux speed <arg>`); Headroom needs obsbot4linux 0.11
    readonly property var speeds: [
        { label: "Standard", arg: "standard" },
        { label: "Headroom", arg: "headroom", needs: "speed_headroom" },
        { label: "Sport", arg: "sport" }
    ]
    readonly property var speedOptions: speeds.filter(s => !s.needs || has(s.needs))
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

    // Sends `obsbot4linux <args>` and flips the UI to `changes` at once; the next state event
    // confirms it, errors are shown by the watcher
    function send(args, changes) {
        if (!watch.running)
            return;
        const id = ++root.requestId;
        if (changes)
            optimistic.change(id, changes);
        watch.write(id, args);
    }

    // The camera's own state says awake (without the optimistic patches)
    readonly property bool awakeReported: optimistic.truth.available === true && optimistic.truth.status?.asleep === false

    function setAwake(on) {
        if (!watch.running)
            return;
        if (!on)
            previewOn = false;
        root.send([on ? "wake" : "sleep"], { status: { asleep: !on } });
    }

    // The preview wakes a sleeping camera by opening the stream: show it awake at once
    function assumeAwake() {
        optimistic.change(++root.requestId, { status: { asleep: false } });
    }

    function setMode(index) {
        const mode = root.trackingModes[index];
        root.send(["tracking", mode.arg], { status: { ai_mode: mode.key } });
    }

    function setSpeed(index) {
        const speed = root.speedOptions[index];
        root.send(["speed", speed.arg], { status: { tracking_speed: speed.arg } });
    }

    function setZoom(factor) {
        const next = Math.max(root.zoomRange[0], Math.min(root.zoomRange[1], Math.round(factor * 100) / 100));
        root.send(["zoom", next.toFixed(2)], { zoom: { factor: next } });
    }

    // The +/- buttons: 0.5 per click within the range
    function stepZoom(delta) {
        root.setZoom(root.zoomFactor + delta);
    }

    // Presets stored in the camera, [{slot, name, pose}] for the slots in use (empty slots are not
    // listed). `listedPresets` is the answer to `preset list`, null until it came.
    property var listedPresets: null
    // With obsbot4linux 0.13 (capability preset_state) the list is part of the state events and is
    // re-sent after every change (null: no answer); older versions are asked with `preset list`.
    // Arrays from the state may come as list wrappers, hence length and Array.from.
    readonly property var presets: {
        if (!has("preset_state"))
            return listedPresets;
        const list = cam.presets;
        return list && typeof list.length === "number" ? Array.from(list) : null;
    }
    property bool presetsFailed: false
    property int presetListId: 0

    function refreshPresets() {
        if (!watch.running || root.has("preset_state"))
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
        // the optimistic change of this request did not happen
        if (msg.ok === false)
            optimistic.fail(msg.id);
        if (msg.id !== root.presetListId)
            return;
        root.presetListId = 0;
        const list = msg.result?.value;
        // not Array.isArray: the reply went through a signal, which hands arrays over as list
        // wrappers that fail it
        if (msg.ok !== false && list && typeof list.length === "number") {
            root.listedPresets = Array.from(list);
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
            if (root.listedPresets === null)
                root.presetsFailed = true;
        }
    }

    function applySize() {
        if (!requestResize || !clearResize)
            return;
        if (editing)
            clearResize();
        else if (card.implicitHeight > 0)
            requestResize(contentWidth, card.implicitHeight);
    }
    // DMS sets the two functions one after the other, the size can only be asked for once both are there
    onRequestResizeChanged: applySize()
    onClearResizeChanged: applySize()
    Component.onCompleted: applySize()

    // One preview at a time: starting one in the popout switches this one off and vice versa
    PreviewClaim {
        pluginId: root.pluginId
        holding: root.previewOn
        onDisplaced: root.previewOn = false
    }

    OptimisticState {
        id: optimistic
    }

    // Errors are logged and shown as a toast by the watcher
    CameraWatch {
        id: watch
        active: true
        instanceName: "desktop widget" + (root.screen?.name ? " on screen " + root.screen.name : "")
        device: root.device
        onStateEvent: next => optimistic.receive(next)
        onReply: msg => root.handleReply(msg)
        onStopped: {
            optimistic.reset();
            root.listedPresets = null;
            root.presetListId = 0;
            root.presetsFailed = false;
            presetTimeout.stop();
        }
    }

    // One card like the popout's cards: picture area inset at the top, the controls below
    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: content.implicitHeight + Theme.spacingL * 2
        color: Theme.surfaceContainerHigh
        radius: Theme.cornerRadius
        onImplicitHeightChanged: root.applySize()

        Column {
            id: content
            x: Theme.spacingL
            y: Theme.spacingL
            width: card.width - Theme.spacingL * 2
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM

                PreviewFrame {
                    id: frame
                    width: root.pictureWidth
                    height: Math.round(width * 9 / 16)
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

                DesktopSide {
                    id: sideColumn
                    width: root.sideWidth
                    height: frame.height
                    ctl: root
                    interactive: !root.editing
                }
            }

            DesktopBottom {
                width: parent.width
                ctl: root
                interactive: !root.editing
            }
        }
    }
}
