import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Named poses stored in the camera (obsbot4linux 0.12, capability zone_views): go, rename, delete,
// save the current pose. The list is `zone.views` of the state events, [{id, name, pose}]; the
// camera does not track by them. Rename and delete work like in the Presets card.
Column {
    id: views

    property var ctl

    readonly property var list: {
        const l = ctl.cam.zone?.views;
        // list wrapper from the state event, not Array.isArray
        return l && typeof l.length === "number" ? Array.from(l) : [];
    }
    // View id being renamed / asked to delete, -1 = none; only one row at a time
    property int renaming: -1
    property int deleting: -1

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
    function save() {
        const name = newName.text.trim();
        if (name === "")
            return;
        newName.text = "";
        ctl.send(["zone", "view", "save", name], "Saving zone view " + name);
    }

    width: parent.width
    spacing: Theme.spacingS

    StyledText {
        width: parent.width
        text: "Views"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeSmall
    }

    StyledText {
        width: parent.width
        visible: views.list.length === 0
        text: "No views saved"
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    Repeater {
        model: views.list

        delegate: Column {
            id: row

            required property var modelData
            readonly property bool confirmingDelete: views.deleting === modelData.id
            readonly property bool editing: views.renaming === modelData.id

            function rename() {
                const name = nameField.text.trim();
                if (name === "")
                    return;
                views.renaming = -1;
                views.ctl.send(["zone", "view", "rename", row.modelData.id, name], "Renaming zone view");
            }

            width: views.width
            spacing: Theme.spacingXS

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                text: row.modelData.name
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: !row.confirmingDelete
                text: views.poseText(row.modelData)
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                font.features: { "tnum": 1 }
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: row.confirmingDelete
                text: "Delete this view from the camera?"
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
                    text: "Go"
                    iconName: "my_location"
                    enabled: views.ctl.live
                    onClicked: views.ctl.send(["zone", "view", "go", row.modelData.id], "Moving to zone view " + row.modelData.name)
                }

                DButton {
                    visible: !row.confirmingDelete && !row.editing
                    text: "Rename"
                    iconName: "edit"
                    onClicked: {
                        views.reset();
                        nameField.text = row.modelData.name;
                        views.renaming = row.modelData.id;
                        nameField.forceActiveFocus();
                    }
                }

                DButton {
                    visible: !row.confirmingDelete && !row.editing
                    text: "Delete"
                    iconName: "delete"
                    backgroundColor: Theme.errorContainer
                    textColor: Theme.onErrorContainer
                    onClicked: {
                        views.reset();
                        views.deleting = row.modelData.id;
                        cancelTimer.restart();
                    }
                }

                DButton {
                    visible: row.editing
                    text: "Cancel"
                    onClicked: views.renaming = -1
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
                    onClicked: views.deleting = -1
                }

                DButton {
                    visible: row.confirmingDelete
                    text: "Delete now"
                    iconName: "delete"
                    backgroundColor: Theme.error
                    textColor: Theme.onError
                    onClicked: {
                        views.deleting = -1;
                        views.ctl.send(["zone", "view", "delete", row.modelData.id], "Deleting zone view " + row.modelData.name);
                    }
                }
            }
        }
    }

    DTextField {
        id: newName
        width: parent.width
        maximumLength: 32
        placeholderText: "Name for the current pose"
        validator: RegularExpressionValidator {
            regularExpression: /[\x20-\x7e]*/
        }
        onAccepted: views.save()
    }

    DButton {
        text: "Save current pose as view"
        iconName: "save"
        enabled: newName.text.trim() !== ""
        onClicked: views.save()
    }

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "In a tracking mode, Go only applies the view's zoom (tracking keeps pan and tilt); in Static the camera moves to the full pose. The camera does not track by views."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    // A forgotten first click must not stay armed
    Timer {
        id: cancelTimer
        interval: 10000
        onTriggered: views.deleting = -1
    }
}
