import QtQuick
import qs.Common
import qs.DCommon.Common
import qs.DCommon.Widgets

// One of the camera's three preset slots in the desktop widget's bottom row: a recall button with
// the preset's name (elided, the full name as tooltip), or nothing while the slot is empty so the
// other slots keep their place. All slots share the secondary container colour and none is
// highlighted: the camera cannot report which preset is active.
//
// ctl is the DesktopPreview: presets, recallPreset().
Item {
    id: slot

    property var ctl
    property int slotIndex: 0

    readonly property var preset: (ctl?.presets ?? []).find(p => p.slot === slotIndex) ?? null

    DButton {
        visible: slot.preset !== null
        anchors.verticalCenter: parent.verticalCenter
        width: slot.width
        buttonHeight: Style.buttonHeightS
        minimumWidth: 0
        maximumWidth: slot.width
        text: slot.preset?.name ?? ""
        tooltipText: slot.preset?.name ?? ""
        backgroundColor: Theme.secondaryContainer
        textColor: Theme.onSecondaryContainer
        onClicked: slot.ctl.recallPreset(slot.slotIndex)
    }
}
