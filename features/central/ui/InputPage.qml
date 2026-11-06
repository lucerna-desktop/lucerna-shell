pragma ComponentBehavior: Bound

import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.central.state

// Página do microfone no painel de ações da central: voltar e o título; o
// volume do microfone (clicar no ícone silencia) e as entradas (a atual
// acesa; clicar troca).
Column {
    id: root

    width: parent?.width ?? 0
    spacing: ThemeManager.spacing.small

    PageHeader {
        title: "Microfone"
        onBack: CentralState.setPage("")
    }

    PillSlider {
        icon: SoundState.micIcon
        label: "Volume"
        value: SoundState.micVolume
        muted: SoundState.micMuted
        iconClickable: true
        onMoved: v => SoundState.setMicVolume(v)
        onIconClicked: SoundState.toggleMicMute()
    }

    Column {
        width: root.width
        spacing: ThemeManager.px(2)

        Repeater {
            model: SoundState.inputs

            delegate: ListRow {
                id: input

                required property var modelData

                icon: Icons.mic
                title: input.modelData.name
                lit: input.modelData.current
                onClicked: SoundState.selectInput(input.modelData)
            }
        }
    }
}
