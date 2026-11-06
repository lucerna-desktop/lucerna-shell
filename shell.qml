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
import qs.features.safeMode.ui
import qs.features.settings.ui
import qs.features.themeSwitcher.ui
import qs.features.wallpaper.ui
import qs.features.workspaces.ui
import qs.services as Services

ShellRoot {
    id: root

    // Na sessão Lucerna, o shell é o do supervisor (lucerna-session supervise,
    // que exporta LUCERNA_SUPERVISED=1). Um qs subido por fora, como um
    // hl.exec_cmd("qs -c lucerna") ou um bind antigo no hyprland.lua da
    // pessoa, sai logo, sem abrir nenhuma janela: senão seriam dois shells.
    readonly property bool unsupervised: Services.LucernaSession.unsupervised(Quickshell.env("LUCERNA_SESSION") ?? "", Quickshell.env("LUCERNA_SUPERVISED") ?? "")

    // Cria o serviço da sessão já no começo: ele lê o session.json e o
    // crash.json do lucerna-session e mostra os avisos (a queda, o modo de
    // segurança, o modeset da NVIDIA).
    Component.onCompleted: {
        if (unsupervised) {
            console.warn("lucerna: na sessão Lucerna, o shell é o do supervisor; este qs sai (tire o exec_cmd do qs do seu hyprland.lua; para reiniciar, lucerna-session shell restart)");
            // O Quickshell só liga o Qt.exit (o Qt.quit não tem quem o
            // receba), e no onCompleted ele é ignorado: depois do evento.
            Qt.callLater(() => Qt.exit(0));
            return;
        }
        Services.LucernaSession.start();
    }

    LazyLoader {
        active: !root.unsupervised

        Scope {
            // O bloqueio antes de qualquer janela: o Session (criado aqui) lê a marca
            // do bloqueio e, se o shell caiu bloqueado, volta bloqueado.
            Lockscreen {}
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
            SafeModeBanner {}
            ThemeSwitcher {}
        }
    }
}
