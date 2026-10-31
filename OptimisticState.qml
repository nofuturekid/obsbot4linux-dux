import QtQuick

// The camera state with optimistic patches on top, shared by the popout (ObsbotWidget) and the
// desktop widget (DesktopPreview) (#89, #91). `truth` is the state object of the last event, `cam`
// is what the UI reads: `truth` plus the changes sent but not yet confirmed. A patch stays until
// an event shows its value or patchTimeout has passed; a newer change of the same value replaces
// the older patch, and the live pose is never held.
Item {
    id: root

    property var cam: ({})
    property var truth: ({})
    // The optimistic changes not yet confirmed by an event, by request id: { changes, at }. A
    // failed request takes back only its own; a later change of the same value replaces it.
    property var patches: ({})
    // An event right after a command can still carry the old value (obsbot4linux up to 0.13.1
    // sends one with old zone, hand, image and zoom values; a full read running when the
    // command came in has not seen it). A value the camera stores differently from what was
    // sent never confirms; it shows the camera's value after this long.
    readonly property int patchTimeout: 3000
    // Optional function (previous cam, rebuilt cam) -> cam, applied last on every rebuild; the
    // popout keeps dragged sliders with it
    property var finish: null

    // After every rebuild of `cam`
    signal refreshed

    Timer {
        id: patchExpiry
        interval: root.patchTimeout + 50
        onTriggered: root.apply()
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

    // Whether `state` has `want` (a value from a patch); objects are compared by the keys sent
    function sameValue(have, want) {
        if (want === null || want === undefined)
            return have === null || have === undefined;
        if (typeof want === "number")
            return typeof have === "number" && Math.abs(have - want) < 1e-6;
        if (typeof want === "object") {
            if (have === null || typeof have !== "object")
                return false;
            for (const k in want)
                if (!root.sameValue(have[k], want[k]))
                    return false;
            return true;
        }
        return have === want;
    }

    // The pose is live (it moves with the gimbal); it is never held, only the settings are
    function confirmed(changes, state) {
        for (const group in changes) {
            if (group === "pose")
                continue;
            const want = changes[group];
            if (typeof want !== "object" || want === null) {
                if (!root.sameValue(state[group], want))
                    return false;
                continue;
            }
            for (const key in want) {
                const have = group === "image" ? state.image?.[key]?.value : state[group]?.[key];
                if (!root.sameValue(have, want[key]))
                    return false;
            }
        }
        return true;
    }

    // `cam` from the last event and the patches it has not confirmed yet
    function apply() {
        const now = Date.now();
        const keep = {};
        for (const id in root.patches) {
            const p = root.patches[id];
            if (now - p.at < root.patchTimeout && !root.confirmed(p.changes, root.truth))
                keep[id] = p;
        }
        root.patches = keep;
        const previous = root.cam;
        root.cam = root.truth;
        // ids count up, so later changes go on top
        for (const id in keep) {
            const changes = Object.assign({}, keep[id].changes);
            delete changes.pose;
            root.patch(changes);
        }
        if (root.finish)
            root.cam = root.finish(previous, root.cam);
        root.refreshed();
    }

    // A state event arrived
    function receive(next) {
        root.truth = next;
        root.apply();
    }

    // A request with id `id` went out: show `changes` at once and hold them until an event
    // confirms them
    function change(id, changes) {
        root.patch(changes);
        root.patches = Object.assign(root.supersede(changes), { [id]: { changes: changes, at: Date.now() } });
        patchExpiry.restart();
    }

    // The request failed: the optimistic change of this request did not happen; the state is
    // rebuilt from the last event and the changes still in flight
    function fail(id) {
        const rest = Object.assign({}, root.patches);
        delete rest[id];
        root.patches = rest;
        root.apply();
    }

    // The watch ended: nothing is known any more
    function reset() {
        root.cam = ({});
        root.truth = ({});
        root.patches = ({});
    }

    // A new change of a value replaces the older patches of it: when the event confirms the
    // older one, the newer one must still show
    function supersede(changes) {
        const rest = {};
        for (const id in root.patches) {
            const old = Object.assign({}, root.patches[id].changes);
            for (const group in changes) {
                if (!(group in old))
                    continue;
                if (typeof changes[group] !== "object" || changes[group] === null || typeof old[group] !== "object" || old[group] === null) {
                    delete old[group];
                    continue;
                }
                const keys = Object.assign({}, old[group]);
                for (const key in changes[group])
                    delete keys[key];
                if (Object.keys(keys).length > 0)
                    old[group] = keys;
                else
                    delete old[group];
            }
            if (Object.keys(old).length > 0)
                rest[id] = { changes: old, at: root.patches[id].at };
        }
        return rest;
    }
}
