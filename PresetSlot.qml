import QtQuick
import qs.Common
import qs.DCommon.Widgets

// One of the camera's three preset slots in the desktop widget's bottom row: a recall button with
// the preset's name (elided, the full name as tooltip), or nothing while the slot is empty so the
// other slots keep their place. Each slot has its own theme colour: 0 primary, 1 secondary, 2 tertiary.
//
// ctl is the DesktopPreview: presets, recallPreset().
Item {
    id: slot

    property var ctl
    property int slotIndex: 0

    readonly property var preset: (ctl?.presets ?? []).find(p => p.slot === slotIndex) ?? null
    readonly property var colors: [
        { bg: Theme.primaryContainer, fg: Theme.onPrimaryContainer },
        { bg: Theme.secondaryContainer, fg: Theme.onSecondaryContainer },
        { bg: Theme.tertiaryContainer, fg: Theme.onTertiaryContainer }
    ]

    DButton {
        visible: slot.preset !== null
        width: slot.width
        minimumWidth: 0
        maximumWidth: slot.width
        text: slot.preset?.name ?? ""
        tooltipText: slot.preset?.name ?? ""
        backgroundColor: slot.colors[slot.slotIndex].bg
        textColor: slot.colors[slot.slotIndex].fg
        onClicked: slot.ctl.recallPreset(slot.slotIndex)
    }
}
