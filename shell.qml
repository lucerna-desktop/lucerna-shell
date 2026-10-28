import QtQuick
import Quickshell
import qs.core.widgets
import qs.features.bar.ui
import qs.features.capture.ui
import qs.features.central.ui
import qs.features.clipboard.ui
import qs.features.dashboard.ui
import qs.features.displays.ui
import qs.features.energy.ui
import qs.features.idle.ui
import qs.features.input.ui
import qs.features.launcher.ui
import qs.features.lockscreen.ui
import qs.features.nightlight.ui
import qs.features.notifications.ui
import qs.features.osd.ui
import qs.features.powerMenu.ui
import qs.features.settings.ui
import qs.features.themeSwitcher.ui
import qs.features.wallpaper.ui
import qs.features.workspaces.ui

ShellRoot {
    Wallpaper {}
    WorkspacesOverview {}
    Bar {}
    // A janela da forma de cada tela, com o que as features põem nela, de
    // baixo para cima.
    Variants {
        model: Quickshell.screens

        FrameWindow {
            id: frameWindow

            required property var modelData

            targetScreen: modelData
            // Abaixo da forma: os painéis cobrem os popups.
            underlay: NotificationPopups {
                screen: frameWindow.modelData
            }

            Osd {
                screen: frameWindow.modelData
            }

            Central {
                screen: frameWindow.modelData
            }

            BarLayer {
                screen: frameWindow.modelData
            }

            Dashboard {
                screen: frameWindow.modelData
            }
        }
    }
    CaptureOverlay {}
    Clipboard {}
    Displays {}
    Energy {}
    Idle {}
    Input {}
    Launcher {}
    NightLight {}
    PowerMenu {}
    Settings {}
    MonitorConfirm {}
    MonitorIdentify {}
    Lockscreen {}
    ThemeSwitcher {}
}
