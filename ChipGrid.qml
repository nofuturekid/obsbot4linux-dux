import QtQuick
import qs.Common
import qs.DCommon.Common
import qs.DCommon.Widgets

// Label above a two-column grid of equal-width single-select chips that fill the width exactly
// (the desktop widget's side column). Labels are centred and elided if they do not fit.
// Colours, height, radius, border and text follow DFilterChips (the popout's chips) token by token.
Column {
    id: grid

    property string label: ""
    property var options: []
    property int currentIndex: -1
    signal selected(int index)

    readonly property real chipWidth: (width - Theme.spacingS) / 2

    spacing: Theme.spacingS

    StyledText {
        text: grid.label
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeSmall
    }

    Flow {
        width: parent.width
        spacing: Theme.spacingS

        Repeater {
            model: grid.options

            delegate: Rectangle {
                id: chip

                required property int index
                required property string modelData
                readonly property bool selected: index === grid.currentIndex

                width: grid.chipWidth
                height: Style.buttonHeightXS
                radius: Style.cornerRadiusS
                color: selected ? (chip.enabled ? Style.secondaryContainer : Style.onSurface_12) : "transparent"
                border.width: selected ? 0 : Style.outlineWidth
                border.color: chip.enabled ? Style.outlineVariant : Style.onSurface_38

                StyledText {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXS
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: chip.modelData
                    color: !chip.enabled ? Style.onSurface_38 : chip.selected ? Style.onSecondaryContainer : Style.onSurfaceVariant
                    font.pixelSize: Style.fontSizeSmall
                    font.weight: Style.fontWeightMedium
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        grid.currentIndex = chip.index;
                        grid.selected(chip.index);
                    }
                }
            }
        }
    }
}
