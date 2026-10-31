import QtQuick
import qs.Common
import qs.DCommon.Widgets

// The camera's three preset slots: recall, save the current pose, rename, delete. The list comes
// from `obsbot4linux preset list` (not part of the state events), read when the card shows up,
// when it opens and after every change.
SectionCard {
    id: section

    property var ctl

    readonly property var slots: [0, 1, 2]
    // Slot being renamed / asked to delete, -1 = none; only one row at a time
    property int renaming: -1
    property int deleting: -1
    readonly property bool zoneReturnArmed: ctl.tracking.zone_tracking === true && ctl.cam.state?.zone_follow === true
    readonly property bool wanted: visible && ctl.available

    function presetAt(slot) {
        return (ctl.presets ?? []).find(p => p.slot === slot) ?? null;
    }
    function num(v) {
        return String(Math.round(v)).replace("-", "−");
    }
    function poseText(p) {
        return "pan " + num(p.pose.pan) + "° · tilt " + num(p.pose.tilt) + "° · zoom " + Number(p.pose.zoom).toFixed(2) + "×";
    }
    function reset() {
        renaming = -1;
        deleting = -1;
    }

    title: "Presets"
    collapsible: true
    expanded: false
    visible: ctl.cardEnabled("Presets") && ctl.has("preset")
    summary: ctl.presets === null ? "" : ctl.presets.length + " of 3 saved"
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38
    onWantedChanged: {
        if (wanted)
            ctl.refreshPresets();
    }
    onExpandedChanged: {
        reset();
        if (expanded && wanted)
            ctl.refreshPresets();
    }
    Component.onCompleted: {
        if (wanted)
            ctl.refreshPresets();
    }

    Repeater {
        model: section.slots

        delegate: Column {
            id: row

            required property int modelData
            readonly property var preset: section.presetAt(modelData)
            readonly property bool confirmingDelete: section.deleting === modelData
            readonly property bool editing: section.renaming === modelData

            function rename() {
                const name = nameField.text.trim();
                if (name === "")
                    return;
                section.renaming = -1;
                section.ctl.presetCommand(["preset", "rename", row.modelData, name], "Renaming preset " + (row.modelData + 1));
            }

            width: section.width - section.padding * 2
            spacing: Theme.spacingXS

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                text: "Slot " + (row.modelData + 1) + (row.preset ? ": " + row.preset.name : "")
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: !row.confirmingDelete
                text: row.preset ? section.poseText(row.preset) : (section.ctl.presets === null ? "Reading presets..." : "Empty")
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                font.features: { "tnum": 1 }
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: row.confirmingDelete
                text: "Delete this preset from the camera?"
                color: Theme.error
                font.pixelSize: Theme.fontSizeSmall
            }

            DTextField {
                id: nameField
                width: parent.width
                visible: row.editing
                maximumLength: 32
                placeholderText: "Name"
                validator: RegularExpressionValidator {
                    regularExpression: /[\x20-\x7e]*/
                }
                onAccepted: row.rename()
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingS

                DButton {
                    visible: !row.confirmingDelete && !row.editing
                    text: "Recall"
                    iconName: "my_location"
                    enabled: row.preset !== null && section.ctl.live
                    onClicked: section.ctl.presetCommand(["preset", "recall", row.modelData], "Moving to preset " + (row.modelData + 1))
                }

                DButton {
                    visible: !row.confirmingDelete && !row.editing
                    text: "Save current pose"
                    iconName: "save"
                    onClicked: section.ctl.presetCommand(["preset", "save", row.modelData], "Saving preset " + (row.modelData + 1))
                }

                DButton {
                    visible: !row.confirmingDelete && !row.editing
                    text: "Rename"
                    iconName: "edit"
                    enabled: row.preset !== null
                    onClicked: {
                        section.reset();
                        nameField.text = row.preset?.name ?? "";
                        section.renaming = row.modelData;
                        nameField.forceActiveFocus();
                    }
                }

                DButton {
                    visible: !row.confirmingDelete && !row.editing
                    text: "Delete"
                    iconName: "delete"
                    enabled: row.preset !== null
                    backgroundColor: Theme.errorContainer
                    textColor: Theme.onErrorContainer
                    onClicked: {
                        section.reset();
                        section.deleting = row.modelData;
                        cancelTimer.restart();
                    }
                }

                DButton {
                    visible: row.editing
                    text: "Cancel"
                    onClicked: section.renaming = -1
                }

                DButton {
                    visible: row.editing
                    text: "Rename"
                    iconName: "check"
                    enabled: nameField.text.trim() !== ""
                    onClicked: row.rename()
                }

                DButton {
                    visible: row.confirmingDelete
                    text: "Cancel"
                    onClicked: section.deleting = -1
                }

                DButton {
                    visible: row.confirmingDelete
                    text: "Delete now"
                    iconName: "delete"
                    backgroundColor: Theme.error
                    textColor: Theme.onError
                    onClicked: {
                        section.deleting = -1;
                        section.ctl.presetCommand(["preset", "delete", row.modelData], "Deleting preset " + (row.modelData + 1));
                    }
                }
            }
        }
    }

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Saving takes the camera's current pose and zoom. Delete frees the slot."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    StyledText {
        width: parent.width
        visible: section.zoneReturnArmed
        wrapMode: Text.WordWrap
        text: "Zone tracking follows new targets: after a recall, the camera's next return to the zone ends in Static."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    // A forgotten first click must not stay armed
    Timer {
        id: cancelTimer
        interval: 10000
        onTriggered: section.deleting = -1
    }
}
