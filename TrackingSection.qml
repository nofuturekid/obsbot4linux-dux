import QtQuick
import qs.Common
import qs.DCommon.Widgets

// AI tracking mode, speed and the hand that hand tracking follows
SectionCard {
    id: section

    property var ctl
    // compact: for the Control Center tile; the tracked hand stays in the popout and the detail page
    property bool compact: false

    readonly property var sides: ["Left", "Right"]
    readonly property var hand: ctl.cam.hand ?? null
    // {pan, tilt, zoom?} the camera returns to after the hand left, null while none is set
    readonly property var handReturn: hand?.return ?? null
    readonly property var handArea: hand?.area ?? null
    readonly property bool handReturnShown: ctl.has("hand_return") && !compact && ctl.status.ai_mode === "hand"

    function deg(v) {
        return String(Math.round(v)).replace("-", "−") + "°";
    }

    function modeIndex() {
        return ctl.trackingModes.findIndex(m => m.label === ctl.aiMode);
    }

    title: "Tracking"
    // the camera takes these while asleep too and keeps them when it wakes
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38

    DFilterChips {
        id: modeChips
        // the selected chip is marked by its colour only; a check mark would widen it
        showCheck: false
        width: parent.width
        model: section.ctl.trackingModes.map(m => m.label)
        currentIndex: section.modeIndex()
        onSelectionChanged: index => section.ctl.setMode(index)
    }

    ChipRow {
        id: speedRow
        width: parent.width
        label: "Speed"
        options: section.ctl.speedOptions.map(m => m.label)
        currentIndex: section.ctl.speedOptions.findIndex(s => s.label === section.ctl.speed)
        onSelected: index => section.ctl.setSpeed(index)
    }

    // Greyed out but readable outside hand tracking, so the side that would be tracked shows
    ChipRow {
        id: sideRow
        width: parent.width
        visible: section.ctl.has("hand") && !section.compact
        enabled: section.ctl.status.ai_mode === "hand"
        opacity: enabled ? 1 : 0.38
        label: "Tracked hand"
        options: section.sides
        currentIndex: section.sides.findIndex(s => s.toLowerCase() === section.ctl.tracking.hand_side)
        onSelected: index => section.ctl.send(["hand", section.sides[index].toLowerCase()], "Tracking the " + section.sides[index].toLowerCase() + " hand", { tracking: { hand_side: section.sides[index].toLowerCase() } })
    }

    // Only while hand tracking is selected. Needs the capability hand_return (obsbot4linux 0.6.0).
    Flow {
        width: parent.width
        visible: section.handReturnShown
        spacing: Theme.spacingS

        DButton {
            text: "Return here"
            iconName: "my_location"
            onClicked: section.ctl.send(["hand", "return-here"], "Setting the hand return position")
        }

        DButton {
            text: "Go to return position"
            iconName: "u_turn_left"
            enabled: section.handReturn !== null
            onClicked: section.ctl.send(["hand", "return-go"], "Moving to the hand return position")
        }

        DButton {
            text: "Clear"
            iconName: "close"
            enabled: section.handReturn !== null
            onClicked: section.ctl.send(["hand", "return-reset"], "Clearing the hand return position", { hand: { return: null } })
        }
    }

    StyledText {
        width: parent.width
        visible: section.handReturnShown
        wrapMode: Text.WordWrap
        text: (section.handReturn ? "Return position: pan " + section.deg(section.handReturn.pan) + " · tilt " + section.deg(section.handReturn.tilt) + (section.handReturn.zoom !== undefined ? " · zoom " + Number(section.handReturn.zoom).toFixed(1) + "×" : "") : "Return position: none")
            + (section.handArea ? "\nHand area: pan " + section.deg(section.handArea.pan_min) + "…" + section.deg(section.handArea.pan_max) + " · tilt " + section.deg(section.handArea.tilt_min) + "…" + section.deg(section.handArea.tilt_max) : "")
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    // Measured with zone tracking on (Tiny 2 Lite): when the target left the area the camera kept
    // tracking and took a new one. Before obsbot4linux 0.7.3 its pose polling made it go Static
    // instead (nofuturekid/obsbot4linux#67). Not in the compact tile.
    ToggleRow {
        width: parent.width
        visible: section.ctl.has("zone_follow") && !section.compact
        label: "Follow new targets"
        checked: section.ctl.cam.state?.zone_follow === true
        onToggled: checked => section.ctl.send(["zone", "follow", checked ? "on" : "off"], checked ? "Following new targets" : "Not following new targets", { state: { zone_follow: checked } })
    }

    // Experimental: the tracked target's box over the preview
    ToggleRow {
        width: parent.width
        visible: section.ctl.has("target") && !section.compact
        label: "Show target box in preview"
        checked: section.ctl.showTargetBox
        onToggled: checked => section.ctl.setShowTargetBox(checked)
    }

    // A click assigns currentIndex and breaks the binding; re-sync to the camera state
    Connections {
        target: section.ctl
        function onStateRefreshed() {
            modeChips.currentIndex = section.modeIndex();
            speedRow.sync();
            sideRow.sync();
        }
    }
}
