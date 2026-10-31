import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "obsbot4linuxDux"

    SelectionSetting {
        settingKey: "wakeTrackingMode"
        label: "Tracking mode on wake"
        description: "Applied whenever the camera wakes up"
        options: [
            { label: "Keep current", value: "" },
            { label: "Static", value: "static" },
            { label: "Normal Tracking", value: "normal" },
            { label: "Upper Body", value: "upper-body" },
            { label: "Close-up", value: "close-up" },
            { label: "Headless", value: "headless" },
            { label: "Lower Body", value: "lower-body" },
            { label: "Hand", value: "hand" },
            { label: "Group", value: "group" }
        ]
        defaultValue: ""
    }

    ToggleSetting {
        settingKey: "hideWithoutCamera"
        label: "Hide the bar icon without a camera"
        description: "Off: the icon stays, dimmed, while no camera is plugged in"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "statusTextInBar"
        label: "Status text in the bar"
        description: "Shows Static, Tracking, Asleep or Offline next to the icon on a horizontal bar; the pill keeps its width"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "wheelZoom"
        label: "Mouse wheel zooms"
        description: "Scrolling over the bar icon changes the zoom by 0.1 per notch"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "middleClickTracking"
        label: "Middle click toggles tracking"
        description: "Switches between Static and the last tracking mode; right click always wakes or sleeps the camera"
        defaultValue: true
    }

    StyledText {
        width: parent.width
        text: "Popout cards"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: Theme.spacingL
    }

    StyledText {
        width: parent.width
        text: "Choose which cards the popout shows. A card the connected camera does not support stays hidden either way. The bar icon and the Control Center tile are not affected."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    ToggleSetting {
        settingKey: "cardPreview"
        label: "Preview"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "cardFraming"
        label: "Framing"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "cardCamera"
        label: "Camera"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "cardSleep"
        label: "Sleep"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "cardTracking"
        label: "Tracking"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "cardZone"
        label: "Zone"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "cardPresets"
        label: "Presets"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "cardPicture"
        label: "Picture"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "cardImage"
        label: "Image"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "cardAudio"
        label: "Audio"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "cardGestures"
        label: "Gestures"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "cardReset"
        label: "Factory reset"
        defaultValue: true
    }
}
