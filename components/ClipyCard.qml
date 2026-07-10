import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property var clipboardItem: null
    property var pluginApi: null
    property string clipboardId: clipboardItem ? clipboardItem.id : ""
    property string mime: clipboardItem ? clipboardItem.mime : ""
    property string preview: clipboardItem ? clipboardItem.preview : ""
    property string pinnedImageDataUrl: ""
    property bool selected: false

    signal clicked()
    signal deleteClicked()

    // Caching/retrieving image URL
    property string imageUrl: ""

    // Content type detection (inspired by clipboardPlus)
    readonly property bool isImage: clipboardItem && clipboardItem.isImage
    readonly property bool isColor: {
        if (isImage || !preview) return false;
        const trimmed = preview.trim();
        return /^#[A-Fa-f0-9]{6}$/.test(trimmed) || 
               /^#[A-Fa-f0-9]{3}$/.test(trimmed) || 
               /^[A-Fa-f0-9]{6}$/.test(trimmed) || 
               /^rgba?\(.*\)$/i.test(trimmed);
    }
    readonly property bool isLink: !isImage && !isColor && preview && /^https?:\/\//.test(preview.trim())
    readonly property bool isCode: !isImage && !isColor && !isLink && preview && (
        preview.includes("function") || 
        preview.includes("import ") || 
        preview.includes("const ") || 
        preview.includes("let ") || 
        preview.includes("var ") || 
        preview.includes("class ") || 
        preview.includes("def ") || 
        preview.includes("return ") || 
        /^[\{\[\(<]/.test(preview.trim())
    )
    readonly property bool isText: !isImage && !isColor && !isLink && !isCode

    readonly property string colorValue: {
        if (!isColor || !preview) return "";
        const trimmed = preview.trim();
        if (/^#[A-Fa-f0-9]{3,6}$/.test(trimmed)) return trimmed;
        if (/^[A-Fa-f0-9]{6}$/.test(trimmed)) return "#" + trimmed;
        return trimmed;
    }

    readonly property string typeLabel: isImage ? "Image" : isColor ? "Color" : isLink ? "Link" : isCode ? "Code" : "Text"
    readonly property string typeIcon: isImage ? "image" : isColor ? "palette" : isLink ? "link" : isCode ? "code" : "format_align_left"

    property bool enableVariableHeight: false
    property int absoluteIndex: -1

    width: parent ? parent.width : 250
    height: enableVariableHeight ? (layout.implicitHeight + Theme.spacingM * 2) : 160

    color: mouseArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
    radius: Theme.cornerRadius
    border.width: 2
    border.color: root.selected ? Theme.primary : Theme.withAlpha(Theme.outline, 0.2)

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    // Top center indicator pill for hover/selected
    Rectangle {
        width: 32
        height: 3
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 4
        color: Theme.primary
        opacity: mouseArea.containsMouse || root.selected ? 0.9 : 0
        radius: 1.5
        z: 20
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        // Card Header: Type indicator + Actions
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            DankIcon {
                name: root.typeIcon
                size: 16
                color: root.isLink ? Theme.primary : Theme.surfaceVariantText
            }

            StyledText {
                text: root.typeLabel
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceVariantText
                Layout.fillWidth: true
            }

            // Delete Button (always visible layout-wise, opacity changes on hover)
            Rectangle {
                id: deleteButton
                width: 24
                height: 24
                radius: Theme.cornerRadiusSmall
                color: deleteMouseArea.containsMouse ? Theme.withAlpha(Theme.error, 0.15) : "transparent"
                opacity: mouseArea.containsMouse || deleteMouseArea.containsMouse ? 1.0 : 0.0
                visible: true

                Behavior on opacity { NumberAnimation { duration: 100 } }

                DankIcon {
                    anchors.centerIn: parent
                    name: "delete"
                    size: 14
                    color: deleteMouseArea.containsMouse ? Theme.error : Theme.surfaceVariantText
                }

                MouseArea {
                    id: deleteMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.deleteClicked()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.outline
            opacity: 0.15
        }

        // Card Body: Content presentation
        // 1. Color Preview
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.isColor
            spacing: Theme.spacingXS

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.enableVariableHeight ? 52 : 44
                color: root.colorValue || "transparent"
                radius: Theme.cornerRadiusSmall
                border.width: 1
                border.color: Theme.outline
            }

            StyledText {
                text: root.colorValue.toUpperCase()
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                color: Theme.surfaceText
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // 2. Image Preview
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.enableVariableHeight ? 120 : 80
            visible: root.isImage
            color: Theme.surfaceContainerHighest
            radius: Theme.cornerRadiusSmall
            clip: true

            Image {
                id: img
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                source: root.imageUrl
                asynchronous: true
                visible: status === Image.Ready

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    radius: Theme.cornerRadiusSmall
                    border.width: 1
                    border.color: Theme.outline
                    opacity: 0.1
                }
            }

            DankIcon {
                anchors.centerIn: parent
                name: "image"
                size: 24
                color: Theme.surfaceVariantText
                visible: img.status !== Image.Ready
            }
        }

        // 3. Code Block
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.enableVariableHeight ? Math.min(180, codeText.implicitHeight + Theme.spacingS * 2) : 80
            visible: root.isCode
            color: Theme.surfaceContainerHighest
            radius: Theme.cornerRadiusSmall
            clip: true
            border.width: 1
            border.color: Theme.withAlpha(Theme.outline, 0.2)

            Flickable {
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                contentWidth: codeText.implicitWidth
                contentHeight: codeText.implicitHeight
                clip: true
                interactive: true

                StyledText {
                    id: codeText
                    text: root.preview
                    font.family: "monospace"
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.surfaceText
                    wrapMode: Text.NoWrap
                }
            }
        }

        // 4. Link Block
        StyledText {
            Layout.fillWidth: true
            visible: root.isLink
            text: root.preview
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.primary
            font.underline: true
            wrapMode: Text.WrapAnywhere
            maximumLineCount: root.enableVariableHeight ? 4 : 3
            elide: Text.ElideRight
        }

        // 5. Standard Text Block
        StyledText {
            Layout.fillWidth: true
            visible: root.isText
            text: root.preview
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
            wrapMode: Text.Wrap
            maximumLineCount: root.enableVariableHeight ? 6 : 4
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Component.onCompleted: {
        if (root.isImage && root.clipboardId && root.pluginApi) {
            root.pluginApi.decodeImage(root.clipboardId, root.mime, function(url) {
                root.imageUrl = url;
            });
        }
    }
}
