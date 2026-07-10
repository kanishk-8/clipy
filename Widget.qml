import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins
import "./components" as ClipyComponents

PluginComponent {
    id: root

    layerNamespacePlugin: "clipy"
    pluginId: "clipy"

    // Settings & Configuration bindings
    property int popoutWidthSetting: pluginData.popoutWidth !== undefined ? pluginData.popoutWidth : 560
    property int popoutHeightSetting: pluginData.popoutHeight !== undefined ? pluginData.popoutHeight : 600
    property bool useDmsClipboard: pluginData.useDmsClipboard !== undefined ? pluginData.useDmsClipboard : true
    property bool autoPasteOnClick: pluginData.autoPasteOnClick !== undefined ? pluginData.autoPasteOnClick : false
    property int autoPasteDelay: pluginData.autoPasteDelay !== undefined ? pluginData.autoPasteDelay : 300
    property bool enableVariableHeight: pluginData.enableVariableHeight !== undefined ? pluginData.enableVariableHeight : false
    // Set popout size dynamically based on user settings
    popoutWidth: popoutWidthSetting
    popoutHeight: popoutHeightSetting

    // State properties
    property var items: []
    property bool loading: false
    property string searchText: ""
    property string activeTab: "All"
    property string filterType: activeTab === "All" ? "" : activeTab
    property var categories: ["All", "Text", "Image", "Code", "Link", "Color"]
    property var imageCache: ({})
    property bool wtypeAvailable: false
    property bool confirmClearVisible: false
    property int selectedClipIndex: 0
    property bool autoPasteAfterNextCopy: false

    // Models for 2-column reactive rendering
    property var filteredItems: {
        var allItems = root.items || [];
        return allItems.filter(function(item) {
            // Category/Tab Filter
            if (root.filterType) {
                var type = root.getItemType(item);
                if (type !== root.filterType) return false;
            }
            // Search Filter
            if (root.searchText) {
                var preview = (item.preview || "").toLowerCase();
                if (preview.indexOf(root.searchText.toLowerCase()) === -1) return false;
            }
            return true;
        });
    }

    onFilteredItemsChanged: {
        root.selectedClipIndex = 0;
    }

    onSelectedClipIndexChanged: {
        console.warn("[Clipy Debug] selectedClipIndex changed to:", selectedClipIndex);
    }

    property var col1Model: {
        var list = [];
        var cols = root.popoutWidthSetting > 480 ? 2 : 1;
        for (var i = 0; i < filteredItems.length; i++) {
            if (cols === 1 || i % 2 === 0) {
                list.push(filteredItems[i]);
            }
        }
        return list;
    }

    property var col2Model: {
        var list = [];
        var cols = root.popoutWidthSetting > 480 ? 2 : 1;
        if (cols === 2) {
            for (var i = 1; i < filteredItems.length; i += 2) {
                list.push(filteredItems[i]);
            }
        }
        return list;
    }

    // Bar Indicator Pills
    horizontalBarPill: Component {
        Item {
            implicitWidth: icon.size
            implicitHeight: icon.size

            DankIcon {
                id: icon
                anchors.centerIn: parent
                name: "content_paste"
                size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                color: Theme.widgetIconColor
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: icon.size
            implicitHeight: icon.size

            DankIcon {
                id: icon
                anchors.centerIn: parent
                name: "content_paste"
                size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                color: Theme.widgetIconColor
            }
        }
    }

    // Main Popout View Component
    popoutContent: Component {
        PopoutComponent {
            id: popoutColumn
            headerText: ""
            detailsText: ""
            showCloseButton: false

            onVisibleChanged: {
                if (visible) {
                    focusTimer.restart();
                }
            }

            Item {
                id: mainPopoutItem
                width: parent.width
                implicitHeight: root.popoutHeightSetting
                focus: true

                Component.onCompleted: {
                    root.confirmClearVisible = false;
                    root.loadHistory();
                }

                Timer {
                    id: debugTickTimer
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: {
                        console.warn("[Clipy Debug] timer tick - selectedClipIndex:", root.selectedClipIndex, "filteredItems length:", root.filteredItems.length, "searchBar active:", globalSearchField.activeFocus);
                    }
                }

                Timer {
                    id: focusTimer
                    interval: 100
                    running: true
                    repeat: false
                    onTriggered: {
                        if (Window.window) {
                            Window.window.requestActivate();
                        }
                        mainPopoutItem.forceActiveFocus();
                    }
                }

                Keys.onPressed: event => {
                    console.warn("[Clipy Debug] mainPopoutItem Key pressed - key:", event.key, "text:", event.text);
                    if (!globalSearchField.activeFocus) {
                        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.filteredItems.length > 0 && root.selectedClipIndex >= 0 && root.selectedClipIndex < root.filteredItems.length) {
                                var selectedItem = root.filteredItems[root.selectedClipIndex];
                                if (selectedItem) {
                                    root.copyItem(selectedItem.id, selectedItem.mime, selectedItem.isImage, selectedItem.preview);
                                    root.closePopout();
                                    event.accepted = true;
                                }
                            }
                        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                            root.navigateItems(true);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                            root.navigateItems(false);
                            event.accepted = true;
                        } else if (event.text !== "" && !/[\x00-\x1F\x7F-\x9F]/.test(event.text)) {
                            globalSearchField.forceActiveFocus();
                            globalSearchField.text += event.text;
                            globalSearchField.cursorPosition = globalSearchField.text.length;
                            event.accepted = true;
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: 0

                    // Header container (2-row design)
                    ColumnLayout {
                        id: headerContainer
                        Layout.fillWidth: true
                        Layout.bottomMargin: Theme.spacingM
                        spacing: Theme.spacingS
                        visible: !root.confirmClearVisible

                        // Row 1 (Top row): Actions + Search Bar
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            spacing: Theme.spacingM

                            // Action Buttons (Reload, Clear All, Settings)
                            RowLayout {
                                spacing: Theme.spacingS

                                // Reload Button
                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: height / 2
                                    color: refreshMouseArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "refresh"
                                        size: 18
                                        color: Theme.surfaceText
                                    }

                                    MouseArea {
                                        id: refreshMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.loadHistory()
                                    }
                                }

                                // Clear All Button
                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: height / 2
                                    color: clearMouseArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "delete_sweep"
                                        size: 18
                                        color: Theme.surfaceText
                                    }

                                    MouseArea {
                                        id: clearMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.confirmClearVisible = true
                                    }
                                }

                                // Settings Button
                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: height / 2
                                    color: settingsMouseArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "settings"
                                        size: 18
                                        color: Theme.surfaceText
                                    }

                                    MouseArea {
                                        id: settingsMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: PopoutService.openSettingsWithTab("plugins")
                                    }
                                }
                            }

                            // Search Bar
                            TextField {
                                id: globalSearchField
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignVCenter

                                placeholderText: ""
                                verticalAlignment: TextInput.AlignVCenter
                                leftPadding: Theme.spacingM
                                rightPadding: Theme.spacingM

                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium

                                onTextChanged: {
                                    root.searchText = text;
                                    root.selectedClipIndex = 0;
                                }

                                onAccepted: {
                                    if (root.filteredItems.length > 0 && root.selectedClipIndex >= 0 && root.selectedClipIndex < root.filteredItems.length) {
                                        var selectedItem = root.filteredItems[root.selectedClipIndex];
                                        if (selectedItem) {
                                            root.copyItem(selectedItem.id, selectedItem.mime, selectedItem.isImage, selectedItem.preview);
                                            root.closePopout();
                                        }
                                    }
                                }

                                StyledText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Search clipy..."
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceVariantText
                                    visible: parent.text === ""
                                }

                                background: Rectangle {
                                    radius: height / 2
                                    color: Theme.surfaceContainerHigh
                                    border.width: 0
                                }

                                Keys.onTabPressed: event => {
                                    root.navigateItems(true);
                                    mainPopoutItem.forceActiveFocus();
                                    event.accepted = true;
                                }

                                Keys.onBacktabPressed: event => {
                                    root.navigateItems(false);
                                    mainPopoutItem.forceActiveFocus();
                                    event.accepted = true;
                                }

                                Keys.onPressed: event => {
                                    console.warn("[Clipy Debug] globalSearchField Key pressed - key:", event.key, "text:", event.text);
                                    if (event.key === Qt.Key_Down) {
                                        root.navigateItems(true);
                                        mainPopoutItem.forceActiveFocus();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Up) {
                                        root.navigateItems(false);
                                        mainPopoutItem.forceActiveFocus();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        if (root.filteredItems.length > 0 && root.selectedClipIndex >= 0 && root.selectedClipIndex < root.filteredItems.length) {
                                            var selectedItem = root.filteredItems[root.selectedClipIndex];
                                            if (selectedItem) {
                                                root.copyItem(selectedItem.id, selectedItem.mime, selectedItem.isImage, selectedItem.preview);
                                                root.closePopout();
                                                event.accepted = true;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Row 2 (Bottom row): Category Tabs
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            spacing: Theme.spacingXS

                            Repeater {
                                model: root.categories

                                Rectangle {
                                    id: tabPill
                                    Layout.fillWidth: true
                                    height: 32
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: root.activeTab === modelData ? height / 2 : Theme.cornerRadiusSmall
                                    color: root.activeTab === modelData ? Theme.primary : Theme.surfaceContainerHigh
                                    scale: root.activeTab === modelData ? 1.0 : 0.95
                                    transformOrigin: Item.Center

                                    Behavior on radius { NumberAnimation { duration: 140 } }
                                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                                    Behavior on color { ColorAnimation { duration: 140 } }

                                    StyledText {
                                        id: tabText
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: root.activeTab === modelData ? Font.Bold : Font.Medium
                                        color: root.activeTab === modelData ? Theme.onPrimary : Theme.surfaceText

                                        Behavior on color { ColorAnimation { duration: 140 } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.activeTab = modelData;
                                            root.selectedClipIndex = 0;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Scrollable History / State Content Panel
                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: root.loading ? 1 : (root.filteredItems.length === 0 ? 2 : 0)

                        // 1. Masonry / Column List
                        Flickable {
                            id: flickable
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentHeight: columnsRow.height
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ScrollBar.vertical: ScrollBar {
                                id: verticalScrollBar
                                policy: ScrollBar.AlwaysOn
                                active: true
                                contentItem: Rectangle {
                                    implicitWidth: 6
                                    radius: 3
                                    color: Theme.primary
                                    opacity: verticalScrollBar.active ? 0.8 : 0.4
                                }
                            }

                            Row {
                                id: columnsRow
                                width: flickable.width - 12
                                spacing: Theme.spacingM

                                readonly property int columnsCount: root.popoutWidthSetting > 480 ? 2 : 1
                                height: Math.max(col1.implicitHeight, col2.implicitHeight)

                                // Column 1
                                Column {
                                    id: col1
                                    width: columnsRow.columnsCount === 2 ? (parent.width - Theme.spacingM) / 2 : parent.width
                                    spacing: Theme.spacingM

                                    Repeater {
                                        model: root.col1Model
                                        delegate: ClipyComponents.ClipyCard {
                                            width: col1.width
                                            clipboardItem: modelData
                                            pluginApi: root
                                            enableVariableHeight: root.enableVariableHeight
                                            absoluteIndex: columnsRow.columnsCount === 2 ? index * 2 : index
                                            selected: (columnsRow.columnsCount === 2 ? index * 2 : index) === root.selectedClipIndex
                                            onClicked: {
                                                root.copyItem(clipboardId, mime, isImage, preview);
                                                root.closePopout();
                                            }
                                            onDeleteClicked: {
                                                root.deleteItem(clipboardId);
                                            }
                                        }
                                    }
                                }

                                // Column 2
                                Column {
                                    id: col2
                                    width: (parent.width - Theme.spacingM) / 2
                                    spacing: Theme.spacingM
                                    visible: columnsRow.columnsCount === 2

                                    Repeater {
                                        model: root.col2Model
                                        delegate: ClipyComponents.ClipyCard {
                                            width: col2.width
                                            clipboardItem: modelData
                                            pluginApi: root
                                            enableVariableHeight: root.enableVariableHeight
                                            absoluteIndex: index * 2 + 1
                                            selected: (index * 2 + 1) === root.selectedClipIndex
                                            onClicked: {
                                                root.copyItem(clipboardId, mime, isImage, preview);
                                                root.closePopout();
                                            }
                                            onDeleteClicked: {
                                                root.deleteItem(clipboardId);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 2. Loading state
                        ClipyComponents.LoadingState {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }

                        // 3. Empty state
                        ClipyComponents.EmptyState {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            iconName: root.searchText ? "search_off" : "content_paste"
                            message: root.searchText ? "No search results" : "Clipboard is empty"
                            details: root.searchText ? "Try typing something else." : "Copied text, images, or colors will show up here."
                        }
                    }
                }
            }
        }
    }

    function advanceCategoryTab(forward) {
        var currentIdx = root.categories.indexOf(root.activeTab);
        if (currentIdx !== -1) {
            var step = forward ? 1 : -1;
            var nextIdx = (currentIdx + step + root.categories.length) % root.categories.length;
            root.activeTab = root.categories[nextIdx];
            root.selectedClipIndex = 0;
        }
    }

    function navigateItems(forward) {
        if (root.filteredItems.length > 0) {
            var step = forward ? 1 : -1;
            root.selectedClipIndex = (root.selectedClipIndex + step + root.filteredItems.length) % root.filteredItems.length;
        }
    }

    // ── Clipboard operations ───────────────────────────────────────────────

    function loadHistory() {
        root.loading = true;
        if (root.useDmsClipboard) {
            DMSService.sendRequest("clipboard.getHistory", null, function(response) {
                if (response && Array.isArray(response.result)) {
                    root.items = root.parseBuiltInHistoryEntries(response.result);
                } else {
                    root.items = [];
                }
                root.selectedClipIndex = 0;
                root.loading = false;
            });
        } else {
            if (!listProc.running) {
                listProc.command = ["cliphist", "list"];
                listProc.running = true;
            }
        }
    }

    function parseBuiltInHistoryEntries(entries) {
        return (Array.isArray(entries) ? entries : []).map(function(entry) {
            var id = String(entry.id ?? "");
            var preview = String(entry.preview ?? "");
            var mime = String(entry.mimeType || "text/plain");
            var isImage = Boolean(entry.isImage) || mime.startsWith("image/");
            return {
                id: id,
                preview: preview,
                isImage: isImage,
                mime: mime
            };
        }).filter(function(entry) { return entry.id.length > 0; });
    }

    function parseHistoryItems(output) {
        var lines = String(output || "").split("\n").filter(function(l) { return l.length > 0; });
        return lines.map(function(l) {
            var id = "", preview = "";
            var tab = l.indexOf("\t");
            if (tab > -1) {
                id = l.slice(0, tab);
                preview = l.slice(tab + 1);
            } else {
                var m = l.match(/^(\d+)\s+(.+)$/);
                if (m) {
                    id = m[1];
                    preview = m[2];
                } else {
                    id = l;
                    preview = "";
                }
            }
            var lower = preview.toLowerCase();
            var isImage = lower.indexOf("[image]") === 0 || lower.indexOf(" binary data ") !== -1;
            var mime = "text/plain";
            if (isImage) {
                if (lower.indexOf(" png") !== -1) mime = "image/png";
                else if (lower.indexOf(" jpg") !== -1 || lower.indexOf(" jpeg") !== -1) mime = "image/jpeg";
                else if (lower.indexOf(" webp") !== -1) mime = "image/webp";
                else if (lower.indexOf(" gif") !== -1) mime = "image/gif";
                else mime = "image/*";
            }
            return {
                id: id,
                preview: preview,
                isImage: isImage,
                mime: mime
            };
        }).filter(function(entry) { return entry.id.length > 0; });
    }

    function copyItem(id, mime, isImage, preview) {
        if (root.useDmsClipboard) {
            root.autoPasteAfterNextCopy = true;
            DMSService.sendRequest("clipboard.copyEntry", { id: Number(id) }, function(response) {
                if (response && response.error) {
                    root.autoPasteAfterNextCopy = false;
                    return;
                }
                if (root.autoPasteAfterNextCopy) {
                    root.autoPasteAfterNextCopy = false;
                    root.triggerAutoPaste();
                }
            });
        } else {
            if (isImage) {
                copyImageProc.command = ["sh", "-c", "cliphist decode " + id + " | wl-copy -t " + (mime || "image/png")];
                copyImageProc.running = true;
            } else {
                copyTextProc.command = ["sh", "-c", "cliphist decode " + id + " | wl-copy"];
                copyTextProc.running = true;
            }
        }
    }

    function deleteItem(id) {
        if (root.useDmsClipboard) {
            DMSService.sendRequest("clipboard.deleteEntry", { id: Number(id) }, function(response) {
                root.loadHistory();
            });
        } else {
            deleteProc.command = ["sh", "-c", "cliphist list | grep '^" + id + "\t' | cliphist delete"];
            deleteProc.running = true;
        }
    }

    function clearAll() {
        if (root.useDmsClipboard) {
            DMSService.sendRequest("clipboard.clearHistory", null, function(response) {
                root.imageCache = {};
                root.items = [];
                root.loadHistory();
            });
        } else {
            clearProc.command = ["cliphist", "wipe"];
            clearProc.running = true;
        }
    }

    function decodeImage(id, mime, callback) {
        if (imageCache[id]) {
            callback(imageCache[id]);
            return;
        }
        if (root.useDmsClipboard) {
            DMSService.sendRequest("clipboard.getEntry", { id: Number(id) }, function(response) {
                if (response && response.result) {
                    var entry = response.result;
                    var url = "data:" + (entry.mimeType || mime || "image/png") + ";base64," + entry.data;
                    root.imageCache[id] = url;
                    callback(url);
                }
            });
        } else {
            imageDecodeProc.callback = callback;
            imageDecodeProc.clipId = id;
            imageDecodeProc.mime = mime || "image/png";
            imageDecodeProc.command = ["sh", "-c", "cliphist decode " + id + " | base64 -w 0"];
            imageDecodeProc.running = true;
        }
    }

    // ── Clipboard type classifier ────────────────────────────────────────────

    function getItemType(item) {
        if (!item) return "Text";
        if (item.isImage) return "Image";

        var preview = item.preview || "";
        var trimmed = preview.trim();

        // Color
        if (/^#[A-Fa-f0-9]{6}([A-Fa-f0-9]{2})?$/.test(trimmed)) return "Color";
        if (/^#[A-Fa-f0-9]{3}$/.test(trimmed)) return "Color";
        if (/^[A-Fa-f0-9]{6}$/.test(trimmed)) return "Color";
        if (/^rgba?\s*\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}\s*(,\s*[\d.]+\s*)?\)$/i.test(trimmed)) return "Color";

        // Link
        if (/^https?:\/\//.test(trimmed)) return "Link";

        // Code
        if (/^(\/\/|\/\*|#!|\*|<!--)/.test(trimmed)) return "Code";
        if (/\b(function|import|export|const|let|var|class|def|return|if|else|for|while|async|await)\b/.test(preview)) return "Code";
        if (/^[\{\[\(]/.test(trimmed)) return "Code";

        return "Text";
    }

    // ── Processes & Timers ────────────────────────────────────────────────────

    Process {
        id: listProc
        stdout: StdioCollector {}
        onExited: exitCode => {
            if (exitCode === 0) {
                root.items = root.parseHistoryItems(stdout.text);
            } else {
                root.items = [];
            }
            root.selectedClipIndex = 0;
            root.loading = false;
        }
    }

    Process {
        id: copyTextProc
        onExited: exitCode => {
            if (exitCode === 0) {
                root.triggerAutoPaste();
            }
        }
    }

    Process {
        id: copyImageProc
        onExited: exitCode => {
            if (exitCode === 0) {
                root.triggerAutoPaste();
            }
        }
    }

    Process {
        id: deleteProc
        onExited: exitCode => {
            root.loadHistory();
        }
    }

    Process {
        id: clearProc
        onExited: exitCode => {
            root.loadHistory();
        }
    }

    Process {
        id: imageDecodeProc
        property var callback: null
        property string clipId: ""
        property string mime: "image/png"
        stdout: StdioCollector {}
        onExited: exitCode => {
            if (exitCode === 0 && callback && clipId) {
                var base64 = stdout.text.trim();
                if (base64) {
                    var url = "data:" + mime + ";base64," + base64;
                    root.imageCache[clipId] = url;
                    callback(url);
                }
            }
        }
    }

    Process {
        id: wtypeCheckProc
        command: ["which", "wtype"]
        running: true
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: exitCode => {
            root.wtypeAvailable = (exitCode === 0);
        }
    }

    Timer {
        id: autoPasteTimer
        interval: root.autoPasteDelay
        repeat: false
        onTriggered: {
            if (root.wtypeAvailable) {
                autoPasteProc.running = true;
            }
        }
    }


    Process {
        id: autoPasteProc
        command: ["wtype", "-M", "ctrl", "v"]
    }

    function triggerAutoPaste() {
        if (root.autoPasteOnClick) {
            autoPasteTimer.restart();
        }
    }

    Connections {
        target: DMSService
        enabled: root.useDmsClipboard
        function onClipboardStateUpdate(data) {
            root.items = root.parseBuiltInHistoryEntries(data ? data.history : []);
            root.loading = false;
        }
    }
}
