import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Column {
    id: root

    width: parent.width
    spacing: Theme.spacingL
    anchors.centerIn: parent

    BusyIndicator {
        anchors.horizontalCenter: parent.horizontalCenter
        running: true
        width: 48
        height: 48
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Loading clipboard history..."
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceVariantText
    }
}
