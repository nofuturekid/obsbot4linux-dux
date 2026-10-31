import QtQuick
import QtQuick.Window
import QtQml.Models
import Quickshell
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.ControlCenter.Widgets
import qs.Modules.Plugins
import qs.Services

PluginComponent {
    id: root

    // One long-running `obsbot4linux watch` is the only link to the camera: its state events are the
    // only source of truth, commands are requests on its stdin. The UI patches `cam`
    // optimistically when a command goes out; the next event overwrites the patch.

    // key = ai_mode in obsbot4linux's state, arg = `obsbot4linux tracking <arg>`
    // main/sub: the mode/sub-mode pair obsbot4linux reads back as status.default_work_mode
    // (main << 4 | sub in the camera; obsbot4linux src/commands.rs AiMode::to_bytes)
    readonly property var trackingModes: [
        { label: "Static", arg: "static", key: "static", main: 0, sub: 0 },
        { label: "Normal Tracking", arg: "normal", key: "normal", main: 2, sub: 0 },
        { label: "Upper Body", arg: "upper-body", key: "upper_body", main: 2, sub: 1 },
        { label: "Close-up", arg: "close-up", key: "close_up", main: 2, sub: 2 },
        { label: "Headless", arg: "headless", key: "headless", main: 2, sub: 3 },
        { label: "Lower Body", arg: "lower-body", key: "lower_body", main: 2, sub: 4 },
        { label: "Hand", arg: "hand", key: "hand", main: 3, sub: 0 },
        { label: "Group", arg: "group", key: "group", main: 1, sub: 0 }
    ]
    readonly property var speeds: [
        { label: "Standard", arg: "standard" },
        { label: "Headroom", arg: "headroom", needs: "speed_headroom" },
        { label: "Sport", arg: "sport" }
    ]
    // Headroom (more room above the head) needs obsbot4linux 0.11
    readonly property var speedOptions: speeds.filter(s => !s.needs || has(s.needs))

    readonly property var exposureModes: [
        { label: "Global", arg: "global" },
        { label: "Face", arg: "face" },
        { label: "Custom", arg: "manual" }
    ]
    // Manual exposure (UVC auto_exposure 1): exposure_time and gain then set the brightness
    readonly property bool manualExposure: (image.auto_exposure?.value ?? 0) === 1
    // Settings page: tracking mode applied whenever the camera wakes up ("" = keep)
    // Settings page: the pill's mouse wheel zooms, its middle click toggles tracking
    readonly property bool wheelZoom: pluginData?.wheelZoom ?? true
    readonly property bool middleClickTracking: pluginData?.middleClickTracking ?? true
    // Settings page: hide the bar icon while no supported camera is plugged in (default: show it dimmed)
    readonly property bool hideWithoutCamera: pluginData?.hideWithoutCamera ?? false
    // Settings page: short status text next to the bar icon (horizontal bars only), off by default
    readonly property bool statusTextInBar: pluginData?.statusTextInBar ?? false
    // Experimental: draw the tracked target's box over the preview (popout and desktop widget)
    readonly property bool showTargetBox: pluginData?.showTargetBox ?? false
    function setShowTargetBox(on) {
        pluginService?.savePluginData(pluginId, "showTargetBox", on);
    }
    // Settings page: one switch per popout card, all on by default. Popout only; the bar icon
    // and the Control Center tile do not look at them.
    function cardEnabled(card) {
        return pluginData?.["card" + card] ?? true;
    }
    // Last tracking mode other than Static (ai_mode key), what the middle click goes back to
    readonly property string lastTrackingMode: pluginData?.lastTrackingMode ?? "normal"

    // UVC controls shown as sliders; range and default come from obsbot4linux's image.<name>
    readonly property var imageControls: [
        { name: "brightness", label: "Brightness" },
        { name: "contrast", label: "Contrast" },
        { name: "saturation", label: "Saturation" },
        { name: "sharpness", label: "Sharpness" },
        { name: "backlight_compensation", label: "Backlight compensation" }
    ]

    // The state object of the last event, with optimistic patches on top
    property var cam: ({})
    property var truth: ({})
    // The optimistic changes sent since the last event, by request id; a failed request takes
    // back only its own
    property var patches: ({})
    readonly property var status: cam.status ?? ({})
    readonly property var tracking: cam.tracking ?? ({})
    readonly property var image: cam.image ?? ({})
    readonly property real zoomFactor: cam.zoom?.factor ?? 1
    // Gimbal pose in degrees; positive pan = camera left, positive tilt = up
    // live pose (follows AI tracking), else the last pose obsbot4linux set
    readonly property real pan: cam.pose?.pan ?? cam.state?.gimbal?.pan ?? 0
    readonly property real tilt: cam.pose?.tilt ?? cam.state?.gimbal?.tilt ?? 0
    // What gimbal, poses and zone area accept ({pan, tilt, zoom}: [min, max]), from obsbot4linux
    readonly property var limits: cam.limits ?? null
    // [min, max] zoom factor; [1, 1] until obsbot4linux reported its limits
    readonly property var zoomRange: limits?.zoom ?? [1, 1]
    readonly property bool imageAtDefaults: imageControls.every(c => (image[c.name]?.value ?? 0) === (image[c.name]?.default ?? 0))

    // Camera model and V4L2 by-id path, both null in the state while no supported camera is there
    readonly property string model: cam.model ?? ""
    readonly property string device: cam.device ?? ""
    // /dev/videoN behind `device`, what Qt Multimedia calls the camera's id
    readonly property string videoNode: watch.videoNode
    readonly property bool previewReady: device !== "" && videoNode !== ""

    readonly property bool toolMissing: watch.toolMissing
    readonly property bool available: cam.available === true
    readonly property bool awake: available && status.asleep === false
    readonly property string aiMode: trackingModes.find(m => m.key === status.ai_mode)?.label ?? ""
    readonly property string speed: speeds.find(s => s.arg === status.tracking_speed)?.label ?? ""

    // Bar pill text: tracking state while awake, "Asleep", "Offline" without a camera
    readonly property string pillText: !available ? "Offline" : !awake ? "Asleep" : status.ai_mode === "static" ? "Static" : "Tracking"

    function has(name) {
        return (cam.capabilities ?? []).indexOf(name) >= 0;
    }

    // Arrow direction follows the picture: with mirror on, the picture's left is the camera's right.
    // "Invert view and gimbal" needs no extra flip: it leaves the commanded and the reported pan
    // alone (measured on a Tiny 2 Lite, gimbal --pan 20 reads pose.pan 20 with invert on and off)
    readonly property int panLeftSign: status.mirror === true ? -1 : 1

    // Fine steps: 1° per arrow click instead of 5°
    property bool fineGimbal: false
    readonly property int gimbalStep: fineGimbal ? 1 : 5

    // Label of the command in flight, shown in the header until obsbot4linux answers
    property string pendingLabel: ""
    property int pendingId: 0
    property int requestId: 0

    // Live preview; holds the camera, so no other app can open it meanwhile
    property bool previewOn: false
    // Starting the preview on a desktop widget switches this one off, and the other way round
    PreviewClaim {
        id: previewClaim
        pluginId: root.pluginId
        holding: root.previewOn
        onDisplaced: root.previewOn = false
    }
    readonly property bool live: available && awake
    // Off whenever the picture cannot be live any more (asleep, unplugged, watch lost), here or
    // from another surface, like the desktop widget
    onLiveChanged: {
        if (!live)
            previewOn = false;
    }

    readonly property string statusText: {
        if (!available)
            return toolMissing ? "Control tool not found" : "Not reachable";
        if (pendingLabel !== "")
            return pendingLabel + "…";
        // obsbot4linux 0.4.0: target null while static, detected false while the camera searches
        const searching = cam.target?.detected === false;
        return awake ? "Awake · " + aiMode + (searching ? " · searching" : "") : "Asleep · lens stowed";
    }
    // Any application reading the camera, the widget's own preview included (obsbot4linux 0.3.0)
    // On air: any app streams (obsbot4linux's kernel probe) or our own preview runs. The preview is
    // counted here too: Qt reads the frames without mmap, so obsbot4linux can't name it.
    // A preview of ours also runs on a desktop widget (PreviewClaim shares that between surfaces)
    readonly property bool previewRunning: previewOn || previewClaim.anyRunning
    readonly property bool streaming: cam.streaming === true || previewRunning
    // Names obsbot4linux could see (may be empty, e.g. Chrome's sandbox), plus our preview
    readonly property var streamingApps: (cam.streaming_apps ?? []).filter(a => a !== "qs").concat(previewRunning ? ["qs"] : [])
    readonly property var appNames: ({
            "qs": "preview",
            "chrome": "Chrome",
            "chromium": "Chrome",
            "firefox": "Firefox",
            "obs": "OBS"
        })

    readonly property string baseSummary: (model !== "" ? model : "OBSBOT camera") + " · " + statusText
    // Header and pill tooltip show this line
    readonly property string summary: baseSummary + (streaming ? " · On air" + (streamingApps.length > 0 ? ": " + streamingApps.map(a => appNames[a] ?? a).join(", ") : "") : "")

    // DMS only hides the popout, its content stays alive; switch the preview off on close
    onInteractionActiveChanged: {
        if (!interactionActive) {
            previewOn = false;
            arranging = false;
        }
    }

    // obsbot4linux 0.8.0 polls the live pose only for connections that ask for it. Only the
    // popout's Framing card shows the pose (the desktop widget never asks). The subscription
    // belongs to the watch connection: poseSent forgets it when the watch process ends, and the
    // first state of the new connection asks again.
    readonly property bool poseWanted: interactionActive && cardEnabled("Framing") && has("live_pose_on_demand")
    property bool poseSent: false
    onPoseWantedChanged: syncPose()
    function syncPose() {
        if (poseWanted === poseSent || !watch.running)
            return;
        send(["live-pose", poseWanted ? "on" : "off"]);
        poseSent = poseWanted;
    }

    signal stateRefreshed

    // The open card of each tab ("" = all closed); opening one closes the other in the same
    // tab, so the popout stays short
    property var openCards: ({})
    function isOpen(id) {
        return openCards[tabOf(id)] === id;
    }
    function toggleOpen(id) {
        const next = Object.assign({}, openCards);
        next[tabOf(id)] = isOpen(id) ? "" : id;
        openCards = next;
    }

    // The right column of the popout is a tab bar; Preview and Framing stay in the left column.
    // Arrange mode of the popout (header button): cards fold up and can be dragged by their grip,
    // within their tab or onto another tab's button. The assignment is saved as card ids per tab
    // in cardTabs. Ids missing there (new cards) join their default tab at the end, unknown ids
    // are dropped. Hidden and unsupported cards keep their slot, they are only not shown.
    property bool arranging: false
    onArrangingChanged: openCards = ({})
    readonly property var tabs: [
        { id: "tracking", text: "Tracking", icon: "track_changes" },
        { id: "picture", text: "Picture", icon: "tune" },
        { id: "device", text: "Device", icon: "settings" }
    ]
    readonly property var defaultTabs: ({
            tracking: ["tracking", "zone", "presets"],
            picture: ["picture", "image"],
            device: ["camera", "sleep", "audio", "gestures", "reset"]
        })
    property var cardTabs: defaultTabs
    function tabOf(id) {
        return tabs.find(t => cardTabs[t.id].includes(id))?.id ?? "device";
    }

    // The tab selected in the popout ("" = the saved one); the last click is saved as lastTab
    property string tab: ""
    readonly property string lastTab: pluginData?.lastTab ?? "tracking"
    function selectTab(id, save) {
        tab = id;
        if (save)
            pluginService?.savePluginData(pluginId, "lastTab", id);
    }

    // Replaced only when the assignment really differs, so other plugin settings changing
    // do not rebuild the cards
    function refreshTabs() {
        const known = tabs.reduce((all, t) => all.concat(defaultTabs[t.id]), []);
        const defaultTab = id => tabs.find(t => defaultTabs[t.id].includes(id)).id;
        const next = {};
        const seen = {};
        const take = (t, id) => {
            if (known.includes(id) && !seen[id]) {
                seen[id] = true;
                next[t].push(id);
            }
        };
        for (const t of tabs)
            next[t.id] = [];
        const saved = pluginData?.cardTabs;
        if (saved && typeof saved === "object") {
            for (const t of tabs) {
                for (const id of Array.isArray(saved[t.id]) ? saved[t.id] : [])
                    take(t.id, id);
            }
        } else {
            // Before 0.17.0 the order was saved per column (cardOrderLeft / cardOrderRight): every
            // card goes to its default tab, ordered by its place in its old column (left first on a tie)
            const old = [];
            for (const col of ["Left", "Right"]) {
                const list = pluginData?.["cardOrder" + col];
                (Array.isArray(list) ? list : []).filter(id => known.includes(id)).forEach((id, rank) => old.push({ id: id, rank: rank, col: col }));
            }
            old.sort((x, y) => x.rank - y.rank || (x.col === "Left" ? -1 : 1) - (y.col === "Left" ? -1 : 1));
            for (const e of old)
                take(defaultTab(e.id), e.id);
        }
        for (const t of tabs) {
            for (const id of defaultTabs[t.id])
                take(t.id, id);
        }
        if (JSON.stringify(next) !== JSON.stringify(cardTabs))
            cardTabs = next;
    }
    onPluginDataChanged: refreshTabs()

    // anchorId: the visible card next to the drop position (after it or before it); "" = end of the tab
    function moveCard(id, toTab, anchorId, after) {
        const next = {};
        for (const t of tabs)
            next[t.id] = cardTabs[t.id].filter(c => c !== id);
        next[toTab].splice(anchorId === "" ? next[toTab].length : next[toTab].indexOf(anchorId) + (after ? 1 : 0), 0, id);
        selectTab(toTab, false);
        if (JSON.stringify(next) === JSON.stringify(cardTabs))
            return;
        pluginService?.savePluginData(pluginId, "cardTabs", next);
    }

    // undefined drops the keys from the saved settings (the pre-0.17.0 column orders too); cardTabs
    // goes last so the migration of the old keys does not run in between
    function resetLayout() {
        pluginService?.savePluginData(pluginId, "cardOrderLeft", undefined);
        pluginService?.savePluginData(pluginId, "cardOrderRight", undefined);
        pluginService?.savePluginData(pluginId, "cardTabs", undefined);
    }

    // changes: { group: { key: value } }; in "image" the value goes into <control>.value
    function patch(changes) {
        const s = Object.assign({}, root.cam);
        for (const group in changes) {
            // top-level scalars such as audio_volume
            if (typeof changes[group] !== "object") {
                s[group] = changes[group];
                continue;
            }
            s[group] = Object.assign({}, s[group]);
            for (const key in changes[group])
                s[group][key] = group === "image" ? Object.assign({}, s.image[key], { value: changes[group][key] }) : changes[group][key];
        }
        root.cam = s;
    }

    // Sliders: events that arrive while the user is still dragging would pull the handle
    // back, so image and zoom of the state stay as dragged until the drag has rested.
    Timer {
        id: dragHold
        interval: 500
        onTriggered: {
            root.cam = root.truth;
            root.stateRefreshed();
        }
    }

    // Sends `obsbot4linux <args>` and flips the UI to `changes` at once
    function send(args, label, changes, slider) {
        if (!watch.running)
            return;
        const id = ++root.requestId;
        if (changes) {
            root.patch(changes);
            root.patches = Object.assign({}, root.patches, { [id]: changes });
        }
        if (slider)
            dragHold.restart();
        if (label) {
            root.pendingId = id;
            root.pendingLabel = label;
        }
        watch.write(id, args);
        root.stateRefreshed();
    }

    // The answer to a request; the watcher has already logged and shown an error
    function handleReply(msg) {
        if (msg.id === root.pendingId)
            root.pendingLabel = "";
        // Any outstanding `preset list` counts, not only the newest: a slow answer to an earlier
        // request must not be dropped just because the card asked again meanwhile
        if (root.presetListIds[msg.id]) {
            const rest = Object.assign({}, root.presetListIds);
            delete rest[msg.id];
            root.presetListIds = rest;
            // [{slot, name, pose: {pan, tilt, zoom}}], the slots in use
            const list = msg.result?.value;
            // not Array.isArray: the reply went through a signal, which hands arrays over as
            // list wrappers that fail it (the cause of "Reading presets..." sticking)
            if (msg.ok !== false && list && typeof list.length === "number") {
                root.listedPresets = Array.from(list);
                root.presetsFailed = false;
                presetTimeout.stop();
            } else {
                root.presetsFailed = true;
            }
        }
        if (root.presetOps[msg.id]) {
            const rest = Object.assign({}, root.presetOps);
            delete rest[msg.id];
            root.presetOps = rest;
            if (msg.ok !== false)
                root.refreshPresets();
        }
        if (msg.ok === false) {
            // the optimistic change of this request did not happen; the state is rebuilt
            // from the last event and the changes still in flight, the dragged sliders stay
            const rest = Object.assign({}, root.patches);
            delete rest[msg.id];
            root.patches = rest;
            const heldWakeZoom = root.cam.status?.wake_up_zoom_percent;
            const held = dragHold.running ? { image: root.cam.image, zoom: root.cam.zoom, audio_volume: root.cam.audio_volume } : null;
            root.cam = root.truth;
            for (const id in rest)
                root.patch(rest[id]);
            if (held) {
                held.status = Object.assign({}, root.cam.status, { wake_up_zoom_percent: heldWakeZoom });
                root.cam = Object.assign({}, root.cam, held);
            }
            root.stateRefreshed();
        }
    }

    function onState(next) {
        // The card asked while the watch was not up yet, or before it restarted: read the list now
        if (root.listedPresets === null && !root.has("preset_state") && root.presetsRequested && !root.presetsFailed && Object.keys(root.presetListIds).length === 0 && next.available === true && (next.capabilities ?? []).indexOf("preset") >= 0)
            Qt.callLater(root.refreshPresets);
        root.truth = next;
        root.patches = ({});
        if (dragHold.running) {
            const s = Object.assign({}, next);
            s.image = root.cam.image;
            s.zoom = root.cam.zoom;
            s.audio_volume = root.cam.audio_volume;
            s.status = Object.assign({}, next.status, { wake_up_zoom_percent: root.cam.status?.wake_up_zoom_percent });
            root.cam = s;
        } else {
            root.cam = next;
        }
        const mode = next.status?.ai_mode;
        if (mode && mode !== "static" && mode !== root.lastTrackingMode)
            root.pluginService?.savePluginData(root.pluginId, "lastTrackingMode", mode);
        root.syncPose();
        root.stateRefreshed();
    }

    function setAwake(on) {
        if (!on)
            root.previewOn = false;
        root.send([on ? "wake" : "sleep"], on ? "Waking camera" : "Stowing lens", { status: { asleep: !on } });
    }

    function toggleAwake() {
        if (root.available)
            root.setAwake(!root.awake);
    }

    // Middle click: Static <-> the last other mode
    function toggleTracking() {
        if (!root.available)
            return;
        const target = status.ai_mode === "static" ? root.lastTrackingMode : "static";
        const index = root.trackingModes.findIndex(m => m.key === target);
        root.setMode(index < 0 ? 1 : index);
    }

    function setMode(index) {
        const mode = root.trackingModes[index];
        root.send(["tracking", mode.arg], "Switching to " + mode.label, { status: { ai_mode: mode.key } });
    }

    function setSpeed(index) {
        const speed = root.speedOptions[index];
        root.send(["speed", speed.arg], "Setting speed to " + speed.label, { status: { tracking_speed: speed.arg } });
    }

    function setHdr(on) {
        root.send(["hdr", on ? "on" : "off"], on ? "Turning HDR on" : "Turning HDR off", { status: { hdr: on } });
    }

    // The camera restarts and drops off USB for ~20 s; obsbot4linux reports it unavailable meanwhile
    function factoryReset() {
        root.previewOn = false;
        root.send(["factory-reset", "--yes"], "Resetting to factory settings");
    }

    // Presets stored in the camera. Before obsbot4linux 0.13 they are not part of the state events:
    // the Presets card then asks for the list when it needs it and after each change, and
    // `listedPresets` is null until `preset list` has answered.
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
    // Ids of the `preset list` requests not answered yet
    property var presetListIds: ({})
    // The card asked at least once; the list is then read again after a watch restart
    property bool presetsRequested: false
    // No usable answer (error, or none within the timeout): the card shows it with a retry
    property bool presetsFailed: false
    // Ids of the preset commands in flight; the list is read again when one succeeded
    property var presetOps: ({})

    function refreshPresets() {
        if (root.has("preset_state"))
            return;
        root.presetsRequested = true;
        root.presetsFailed = false;
        if (!watch.running)
            return;
        const id = ++root.requestId;
        root.presetListIds = Object.assign({}, root.presetListIds, { [id]: true });
        watch.write(id, ["preset", "list"]);
        presetTimeout.restart();
    }

    // "Reading presets..." must not stay forever (request lost, camera not answering)
    Timer {
        id: presetTimeout
        interval: 8000
        onTriggered: {
            if (root.listedPresets === null)
                root.presetsFailed = true;
        }
    }

    function presetCommand(args, label) {
        const id = root.requestId + 1;
        root.presetOps = Object.assign({}, root.presetOps, { [id]: true });
        root.send(args, label);
    }

    function setExposure(index) {
        const mode = root.exposureModes[index];
        const changes = mode.arg === "manual" ? { image: { auto_exposure: 1 } } : { status: { face_auto_exposure: mode.arg === "face" }, image: { auto_exposure: 0 } };
        root.send(["exposure", mode.arg], "Setting exposure to " + mode.label, changes);
    }

    function setControl(name, value) {
        root.send(["image", name, value], "", { image: { [name]: value } }, true);
    }

    function setVolume(value) {
        root.send(["audio", "volume", value], "", { audio_volume: value }, true);
    }

    // obsbot4linux cannot read the LED blink back: the last value set here is remembered
    readonly property bool ledBlink: pluginData?.ledBlink ?? false
    function setLedBlink(on) {
        pluginService?.savePluginData(pluginId, "ledBlink", on);
        root.send(["led", "blink", on ? "on" : "off"], on ? "Letting the status LED blink" : "Letting the status LED burn steadily");
    }

    // Wake-up zoom in hundredths (the camera stores 0-100 percent: zoom = 1 + 3 * percent / 100)
    function setWakeZoom(hundredths) {
        const percent = Math.round((hundredths / 100 - 1) * 100 / 3);
        root.send(["wake", "zoom", (hundredths / 100).toFixed(2)], "", { status: { wake_up_zoom_percent: percent } }, true);
    }

    // Index in trackingModes of the start mode the camera reports, -1 when unknown
    function wakeModeIndex() {
        const m = status.default_work_mode;
        return m ? trackingModes.findIndex(t => t.main === m.main && t.sub === m.sub) : -1;
    }

    function setWakeMode(index) {
        const mode = root.trackingModes[index];
        root.send(["wake", "mode", mode.arg], "Setting start mode to " + mode.label, { status: { default_work_mode: { main: mode.main, sub: mode.sub } } });
    }

    function setZoom(factor) {
        root.send(["zoom", factor.toFixed(2)], "", { zoom: { factor: factor } }, true);
    }

    // Mouse wheel: 0.1 per notch within the range `obsbot4linux zoom` accepts
    function stepZoom(notches) {
        const next = Math.max(root.zoomRange[0], Math.min(root.zoomRange[1], Math.round((root.zoomFactor + notches * 0.1) * 100) / 100));
        if (next !== root.zoomFactor)
            root.setZoom(next);
    }

    // `obsbot4linux gimbal` takes an absolute pose in degrees and switches to Static itself.
    // The ranges come from obsbot4linux's `limits`; without them it rejects what is out of range.
    // Target of the last own gimbal move. Arrow steps build on it while the gimbal is still on its
    // way: the live pose then reads a point in between, and quick presses would fall short.
    property var moveTarget: null
    property double moveTargetAt: 0
    function stepBase() {
        if (moveTarget && Date.now() - moveTargetAt < 2000)
            return moveTarget;
        return { pan: root.pan, tilt: root.tilt };
    }

    function moveGimbal(newPan, newTilt) {
        const clamp = (v, range) => range ? Math.max(range[0], Math.min(range[1], v)) : v;
        const p = clamp(newPan, root.limits?.pan);
        const t = clamp(newTilt, root.limits?.tilt);
        root.moveTarget = { pan: p, tilt: t };
        root.moveTargetAt = Date.now();
        root.send(["gimbal", "--pan", p, "--tilt", t], "", { state: { gimbal: { pan: p, tilt: t } }, pose: { pan: p, tilt: t }, status: { ai_mode: "static" } });
    }

    function degrees(d) {
        const r = Math.round(d);
        return (r > 0 ? "+" : r < 0 ? "−" : "") + Math.abs(r) + "°";
    }

    // Auto-sleep times offered, the choices of OBSBOT Center
    readonly property var autoSleepTimes: [
        { label: "Off", arg: "off" },
        { label: "30 s", arg: "30" },
        { label: "2 min", arg: "120" },
        { label: "10 min", arg: "600" }
    ]
    function autoSleepIndex() {
        if (status.auto_sleep_enabled === undefined)
            return -1;
        if (!status.auto_sleep_enabled)
            return 0;
        return autoSleepTimes.findIndex(t => t.arg === String(status.auto_sleep_seconds));
    }

    // The watcher's `available` drives the bar icon when it should hide without a camera. DMS only
    // fades the pill out, the component and the watch process stay alive, so the icon returns when
    // the camera is plugged in again.
    function applyVisibility() {
        if (hideWithoutCamera)
            setVisibilityOverride(available);
        else
            clearVisibilityOverride();
    }
    onHideWithoutCameraChanged: applyVisibility()
    onAvailableChanged: applyVisibility()
    Component.onCompleted: {
        applyVisibility();
    }

    // DMS also creates a throw-away instance only to read ccWidgetIcon; it gets no pluginService
    // and runs no watch. The bar sets hostContext and the screen; Control Center sets neither.
    readonly property bool realInstance: pluginService !== null
    readonly property string instanceName: !hostContext ? "Control Center tile or detail page" : (hostContext.kind === "bar" ? "bar widget" : hostContext.kind + " widget") + (parentScreen?.name ? " on screen " + parentScreen.name : "")

    CameraWatch {
        id: watch
        active: root.realInstance
        instanceName: root.instanceName
        device: root.device
        onStateEvent: next => root.onState(next)
        onReply: msg => root.handleReply(msg)
        onStopped: {
            root.poseSent = false;
            root.cam = ({});
            root.truth = ({});
            root.pendingLabel = "";
            root.listedPresets = null;
            root.presetListIds = ({});
            root.presetsFailed = false;
            presetTimeout.stop();
            root.presetOps = ({});
            root.stateRefreshed();
        }
    }

    // Retry button: start the watcher again now
    function refresh() {
        watch.refresh();
    }

    // Layout: the left column (preview, framing) is always there, the right one has the tabs
    // (Tracking | Picture | Device). The preview area stays in place and is black while the
    // preview is off. Cards switched off on the settings page (or not supported by the camera)
    // close up; a tab without cards drops out of the tab bar, and when a column is left without
    // cards the popout narrows to the one column that is left. The popout reports the count.
    property int shownColumns: 2
    // 920 px, but at most 90 % of the screen (only below ~1020 px wide screens, e.g. scaled
    // displays) and at least 720 px so the right column keeps its minimum width
    readonly property int minRightWidth: 320
    popoutWidth: shownColumns >= 2 ? Math.max(720, Math.min(920, Screen.width > 0 ? Math.round(Screen.width * 0.9) : 920)) : 380

    // The bar draws the pill; plugins only provide the content (same as the built-in widgets).
    // Right click is sleep/wake; left click opens the popout.
    horizontalBarPill: Component {
        PillContent {
            ctl: root
        }
    }

    verticalBarPill: Component {
        PillContent {
            ctl: root
        }
    }
    pillRightClickAction: () => root.toggleAwake()

    // Control Center tile: the icon toggles sleep/wake. Larger tiles and the detail page show
    // the tracking card. Control Center runs its own instance of this component.
    ccWidgetIcon: !root.available ? "usb_off" : root.live ? "videocam" : "videocam_off"
    ccWidgetPrimaryText: "OBSBOT Control"
    ccWidgetSecondaryText: root.baseSummary + (root.streaming ? " · On air" : "")
    ccWidgetIsActive: root.awake
    onCcWidgetToggled: root.toggleAwake()
    ccExpandedMinimumHeight: Theme.listItemHeight * 3.5
    ccExpandedContent: Component {
        CcTileContent {
            clip: true

            TrackingSection {
                width: parent.width
                ctl: root
                flat: true
                compact: true
                title: ""
            }
        }
    }
    ccDetailHeight: Theme.listItemHeight * 6
    ccDetailContent: Component {
        Item {
            TrackingSection {
                width: parent.width
                ctl: root
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            Component.onCompleted: root.refresh()

            // In arrange mode the tabs stay, an empty one is a drop target
            Binding {
                target: root
                property: "shownColumns"
                value: (leftColumn.hasCards ? 1 : 0) + (root.arranging || popout.shownTabs.length > 0 ? 1 : 0)
            }

            // The tabs with cards (all of them while arranging) and the selected one: the last
            // click, else the saved tab, else the first tab that is left
            readonly property var shownTabs: root.tabs.filter(t => root.arranging || tabColumn(t.id).hasCards)
            readonly property string activeTab: {
                const want = root.tab !== "" ? root.tab : root.lastTab;
                return shownTabs.some(t => t.id === want) ? want : (shownTabs[0]?.id ?? "");
            }
            onActiveTabChanged: root.openCards = ({})

            function tabColumn(id) {
                return id === "tracking" ? trackingTab : id === "picture" ? pictureTab : deviceTab;
            }

            // Arrange mode: cards report the pointer while their grip is dragged; `drop` is the
            // insert position (tab, neighbour card, side), shown as a line, applied on release.
            // Over a tab button the card goes to the end of that tab (the button is highlighted).
            readonly property bool arranging: root.arranging
            property var drop: null

            function dragMove(id, scenePos) {
                const b = tabBar.mapFromItem(null, scenePos.x, scenePos.y);
                if (b.x >= 0 && b.x < tabBar.width && b.y >= 0 && b.y < tabBar.height) {
                    // DTabBar: equal buttons with `spacing` gaps between them
                    const w = (tabBar.width - tabBar.spacing * (shownTabs.length - 1)) / shownTabs.length;
                    const i = Math.max(0, Math.min(shownTabs.length - 1, Math.floor(b.x / (w + tabBar.spacing))));
                    drop = {
                        tab: shownTabs[i].id,
                        anchorId: "",
                        after: true,
                        bar: true,
                        x: i * (w + tabBar.spacing),
                        width: w
                    };
                    return;
                }
                const column = tabColumn(activeTab);
                const p = column.mapFromItem(null, scenePos.x, scenePos.y);
                const others = [];
                for (const c of column.children) {
                    if (c.cardId && c.cardId !== id && c.visible)
                        others.push(c);
                }
                const k = others.findIndex(c => p.y < c.y + c.height / 2);
                const before = k >= 0 ? others[k] : null;
                const last = others[others.length - 1];
                const at = column.mapToItem(cols, 0, before ? before.y - column.spacing / 2 : last ? last.y + last.height + column.spacing / 2 : 0);
                drop = {
                    tab: activeTab,
                    anchorId: before ? before.cardId : last ? last.cardId : "",
                    after: !before,
                    bar: false,
                    x: at.x,
                    width: column.width,
                    y: at.y
                };
            }

            function dragEnd(id) {
                const d = drop;
                drop = null;
                if (d)
                    Qt.callLater(() => root.moveCard(id, d.tab, d.anchorId, d.after));
            }

            // DMS sizes the popout to its content; past 85 % of the screen the tab content scrolls
            // (the left column shrinks its preview instead) and the header stays in place
            readonly property real maxBodyHeight: Math.round(Screen.height * 0.85) - header.height - Theme.spacingM

            HeaderBar {
                id: header
                width: parent.width
                ctl: root
            }

            Item {
                width: parent.width
                height: Theme.spacingM
            }

            Item {
                id: cols
                width: parent.width
                height: columnRow.height

                Row {
                    id: columnRow
                    width: parent.width
                    spacing: leftColumn.hasCards && rightColumn.shown ? Theme.spacingM : 0

                    // Always there: the picture to watch while changing settings
                    Column {
                        id: leftColumn
                        // Column skips hidden cards; without any it drops out
                        readonly property bool hasCards: visibleChildren.length > 0
                        width: !hasCards ? 0 : rightColumn.shown ? parent.width - parent.spacing - rightColumn.width : parent.width
                        spacing: Theme.spacingM

                        PreviewPane {
                            width: parent.width
                            // On a small screen the preview shrinks so the column fits
                            maxHeight: popout.maxBodyHeight - (framing.visible ? framing.height + leftColumn.spacing : 0)
                            visible: root.cardEnabled("Preview")
                            ctl: root
                        }

                        FramingSection {
                            id: framing
                            width: parent.width
                            visible: root.cardEnabled("Framing")
                            ctl: root
                        }
                    }

                    Column {
                        id: rightColumn
                        readonly property bool shown: popout.shownTabs.length > 0
                        width: !shown ? 0 : !leftColumn.hasCards ? parent.width : Math.max(root.minRightWidth, Math.round((parent.width - parent.spacing) * 0.45))
                        spacing: Theme.spacingM

                        DTabBar {
                            id: tabBar
                            width: parent.width
                            model: popout.shownTabs
                            currentIndex: popout.shownTabs.findIndex(t => t.id === popout.activeTab)
                            onTabClicked: index => root.selectTab(popout.shownTabs[index].id, true)
                        }

                        // The tabs lie on top of each other and the area is as high as the
                        // tallest one, so the popout does not jump when switching. A tab that is
                        // not selected stays "visible" (the cards' visibility is what counts as
                        // having cards) but is see-through and inert. Open cards close on a tab
                        // switch, so a card left open in a hidden tab cannot make the area taller.
                        DFlickable {
                            id: tabFlick
                            width: parent.width
                            // The left column stays put; only the tab content scrolls, within what the
                            // screen leaves below the tab bar
                            height: Math.min(tabArea.height, Math.max(0, popout.maxBodyHeight - tabBar.height - rightColumn.spacing))
                            contentWidth: width
                            contentHeight: tabArea.height
                            clip: true

                            Item {
                                id: tabArea
                                width: parent.width
                                height: Math.max(trackingTab.height, pictureTab.height, deviceTab.height)

                                Column {
                                    id: trackingTab
                                    readonly property bool hasCards: visibleChildren.length > 0
                                    width: parent.width
                                    spacing: Theme.spacingM
                                    opacity: popout.activeTab === "tracking" ? 1 : 0
                                    enabled: popout.activeTab === "tracking"

                                    Repeater {
                                        visible: false
                                        model: root.cardTabs.tracking
                                        delegate: cardChooser
                                    }
                                }

                                Column {
                                    id: pictureTab
                                    readonly property bool hasCards: visibleChildren.length > 0
                                    width: parent.width
                                    spacing: Theme.spacingM
                                    opacity: popout.activeTab === "picture" ? 1 : 0
                                    enabled: popout.activeTab === "picture"

                                    Repeater {
                                        visible: false
                                        model: root.cardTabs.picture
                                        delegate: cardChooser
                                    }
                                }

                                Column {
                                    id: deviceTab
                                    readonly property bool hasCards: visibleChildren.length > 0
                                    width: parent.width
                                    spacing: Theme.spacingM
                                    opacity: popout.activeTab === "device" ? 1 : 0
                                    enabled: popout.activeTab === "device"

                                    Repeater {
                                        visible: false
                                        model: root.cardTabs.device
                                        delegate: cardChooser
                                    }
                                }
                            }
                        }
                    }
                }

                // Insert position of the card being dragged
                Rectangle {
                    visible: popout.drop !== null && !popout.drop.bar
                    x: popout.drop?.x ?? 0
                    y: Math.max(0, (popout.drop?.y ?? 0) - height / 2)
                    width: popout.drop?.width ?? 0
                    height: Theme.spacingXS
                    radius: height / 2
                    color: Theme.primary
                }

                // Tab button the card would be dropped on
                Rectangle {
                    visible: popout.drop?.bar ?? false
                    x: tabBar.mapToItem(cols, popout.drop?.x ?? 0, 0).x
                    y: tabBar.mapToItem(cols, 0, 0).y
                    width: popout.drop?.width ?? 0
                    height: tabBar.height
                    radius: Theme.cornerRadius
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.primary
                }
            }

            // One delegate per card id; the repeaters above create them in the saved order
            DelegateChooser {
                id: cardChooser
                role: "modelData"

                DelegateChoice {
                    roleValue: "camera"
                    CameraSection {
                        width: parent.width
                        cardId: "camera"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("camera")
                        onToggleRequested: root.toggleOpen("camera")
                    }
                }

                DelegateChoice {
                    roleValue: "sleep"
                    SleepSection {
                        width: parent.width
                        cardId: "sleep"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("sleep")
                        onToggleRequested: root.toggleOpen("sleep")
                    }
                }

                DelegateChoice {
                    roleValue: "tracking"
                    TrackingSection {
                        width: parent.width
                        cardId: "tracking"
                        arranger: popout
                        visible: root.cardEnabled("Tracking")
                        ctl: root
                    }
                }

                DelegateChoice {
                    roleValue: "zone"
                    ZoneSection {
                        width: parent.width
                        cardId: "zone"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("zone")
                        onToggleRequested: root.toggleOpen("zone")
                    }
                }

                DelegateChoice {
                    roleValue: "presets"
                    PresetsSection {
                        width: parent.width
                        cardId: "presets"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("presets")
                        onToggleRequested: root.toggleOpen("presets")
                    }
                }

                DelegateChoice {
                    roleValue: "picture"
                    PictureSection {
                        width: parent.width
                        cardId: "picture"
                        arranger: popout
                        visible: root.cardEnabled("Picture")
                        ctl: root
                    }
                }

                DelegateChoice {
                    roleValue: "image"
                    ImageSection {
                        width: parent.width
                        cardId: "image"
                        arranger: popout
                        visible: root.cardEnabled("Image")
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("image")
                        onToggleRequested: root.toggleOpen("image")
                    }
                }

                DelegateChoice {
                    roleValue: "audio"
                    AudioSection {
                        width: parent.width
                        cardId: "audio"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("audio")
                        onToggleRequested: root.toggleOpen("audio")
                    }
                }

                DelegateChoice {
                    roleValue: "gestures"
                    GestureSection {
                        width: parent.width
                        cardId: "gestures"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("gestures")
                        onToggleRequested: root.toggleOpen("gestures")
                    }
                }

                DelegateChoice {
                    roleValue: "reset"
                    ResetSection {
                        width: parent.width
                        cardId: "reset"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("reset")
                        onToggleRequested: root.toggleOpen("reset")
                    }
                }
            }
        }
    }
}
