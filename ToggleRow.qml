import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Label (+ optional description) flush with the card edge and a switch on the right.
// DToggle's own label adds an inner padding that indents it against the other content.
Item {
    id: row

    property string label: ""
    property string description: ""
    property bool checked: false
    signal toggled(bool checked)

    // DToggle sets its height but no implicitHeight; with implicitHeight the row took only
    // the label's height and stacked switches overlapped the next row
    implicitHeight: Math.max(texts.implicitHeight, toggle.height)

    Column {
        id: texts
        anchors.left: parent.left
        anchors.right: toggle.left
        anchors.rightMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        StyledText {
            text: row.label
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
        }

        StyledText {
            width: parent.width
            visible: row.description !== ""
            text: row.description
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }
    }

    DToggle {
        id: toggle
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        hideText: true
        checked: row.checked
        onToggled: checked => row.toggled(checked)
    }
}
