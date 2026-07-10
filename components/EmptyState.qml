import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    property string iconName: "inbox"
    property string message: "No items found"
    property string details: ""

    width: parent.width
    spacing: Theme.spacingM
    anchors.centerIn: parent

    DankIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        name: root.iconName
        size: 64
        color: Theme.surfaceVariantText
        opacity: 0.5
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.message
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.details
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        visible: root.details !== ""
    }
}
