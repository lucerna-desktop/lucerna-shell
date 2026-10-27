import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.settings.state

// Transparência e desfoque: o vidro dos painéis do shell.
Column {
    spacing: ThemeManager.spacing.large

    GlassPreview {
        width: parent.width
        transparency: SettingsState.transparency
        panelOpacity: SettingsState.panelOpacity
        cardOpacity: SettingsState.cardOpacity
        blur: SettingsState.blur
        blurSize: SettingsState.blurSize
        blurPasses: SettingsState.blurPasses
    }

    SettingSection {
        title: "Transparência"

        SettingRow {
            icon: Icons.opacity
            title: "Painéis translúcidos"
            description: "Barra, painel superior, launcher, menus e notificações deixam ver o que está atrás"

            Switch {
                checked: SettingsState.transparency
                onToggled: on => SettingsState.setTransparency(on)
            }
        }

        SettingRow {
            wide: true
            dimmed: !SettingsState.transparency
            title: "Opacidade dos painéis"
            description: "Quanto do fundo aparece através do painel"

            Slider {
                width: parent.width
                from: 0.5
                to: 1
                stepSize: 0.01
                value: SettingsState.panelOpacity
                enabled: SettingsState.transparency
                onMoved: v => SettingsState.setPanelOpacity(v)
            }
        }

        SettingRow {
            wide: true
            dimmed: !SettingsState.transparency
            title: "Opacidade dos cartões"
            description: "Os blocos dentro de um painel, como os do painel superior"

            Slider {
                width: parent.width
                from: 0.2
                to: 1
                stepSize: 0.01
                value: SettingsState.cardOpacity
                enabled: SettingsState.transparency
                onMoved: v => SettingsState.setCardOpacity(v)
            }
        }
    }

    SettingSection {
        title: "Desfoque"

        SettingRow {
            wide: true
            icon: SettingsState.blur ? Icons.blur : Icons.blurOff
            title: "Desfocar o fundo"
            description: SettingsState.blurAvailable ? `${SettingsState.blurModeDescription}. Feito pelo Hyprland; só aparece com os painéis translúcidos` : "Precisa do Hyprland com configuração em Lua"
            dimmed: !SettingsState.transparency || !SettingsState.blurAvailable

            SegmentedControl {
                width: parent.width
                options: SettingsState.blurModeOptions
                value: SettingsState.blurMode
                enabled: SettingsState.transparency && SettingsState.blurAvailable
                onSelected: v => SettingsState.setBlurMode(v)
            }
        }

        SettingRow {
            icon: Icons.blur
            title: "Desfocar as janelas"
            description: "Janelas translúcidas; religar recarrega a config do Hyprland"
            dimmed: !SettingsState.blurAvailable

            Switch {
                checked: SettingsState.blurWindows
                enabled: SettingsState.blurAvailable
                onToggled: on => SettingsState.setBlurWindows(on)
            }
        }

        SettingRow {
            wide: true
            dimmed: !SettingsState.transparency || !SettingsState.blur
            title: "Intensidade"
            description: "Raio do desfoque. Vale para todo o desfoque do Hyprland, inclusive o das janelas"

            Slider {
                width: parent.width
                from: 1
                to: 16
                stepSize: 1
                value: SettingsState.blurSize
                format: v => `${Math.round(v)}`
                enabled: SettingsState.transparency && SettingsState.blur
                onMoved: v => SettingsState.setBlurSize(v)
            }
        }

        SettingRow {
            wide: true
            dimmed: !SettingsState.transparency || !SettingsState.blur
            title: "Suavidade"
            description: "Passadas do desfoque: mais passadas deixam mais liso e custam mais GPU"

            Slider {
                width: parent.width
                from: 1
                to: 4
                stepSize: 1
                value: SettingsState.blurPasses
                format: v => `${Math.round(v)}×`
                enabled: SettingsState.transparency && SettingsState.blur
                onMoved: v => SettingsState.setBlurPasses(v)
            }
        }
    }

    // Voltar aos valores do tema: só aparece quando algo foi mudado.
    TonalButton {
        anchors.right: parent.right
        visible: SettingsState.glassCustomized
        icon: Icons.restore
        text: "Restaurar padrões do tema"
        onClicked: SettingsState.resetGlass()
    }
}
