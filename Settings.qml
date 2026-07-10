import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "clipy"

    StyledText {
        width: parent.width
        text: "Clipy Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Clean, responsive clipboard history with categories."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.2
    }

    // Layout configuration
    StyledText {
        width: parent.width
        text: "Layout Configuration"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SliderSetting {
        settingKey: "popoutWidth"
        label: "Popout Width"
        description: "Width of the clipboard window. If set higher than 700px, history changes to a 2-column layout."
        defaultValue: 560
        minimum: 380
        maximum: 1100
        unit: "px"
    }

    SliderSetting {
        settingKey: "popoutHeight"
        label: "Popout Height"
        description: "Height of the clipboard window."
        defaultValue: 600
        minimum: 350
        maximum: 900
        unit: "px"
    }

    ToggleSetting {
        settingKey: "enableVariableHeight"
        label: "Variable Height Cards"
        description: "Enable dynamic heights based on content length. If disabled, all cards use a standard uniform height."
        defaultValue: false
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.2
    }

    // Backend configuration
    StyledText {
        width: parent.width
        text: "Pasting & Backend"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "autoPasteOnClick"
        label: "Auto-Paste on Select"
        description: "Simulate pasting automatically when you click a card or press Enter."
        defaultValue: false
    }

    SliderSetting {
        settingKey: "autoPasteDelay"
        label: "Auto-Paste Delay"
        description: "Delay in milliseconds before simulating paste."
        defaultValue: 300
        minimum: 100
        maximum: 1000
        unit: "ms"
    }

    ToggleSetting {
        settingKey: "useDmsClipboard"
        label: "Use DMS Built-in Clipboard"
        description: "Use the shell's internal clipboard service. Disabling falls back to 'cliphist'."
        defaultValue: true
    }
}
