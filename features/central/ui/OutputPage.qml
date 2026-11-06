pragma ComponentBehavior: Bound

import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.central.state

// Página da saída de áudio no painel de ações da central: voltar e o título;
// as saídas (a atual acesa; clicar troca) e, embaixo, o volume de cada app
// com áudio aberto (clicar no ícone silencia o app).
Column {
    id: root

    width: parent?.width ?? 0
    spacing: ThemeManager.spacing.small

    PageHeader {
        title: "Saída de áudio"
        onBack: CentralState.setPage("")
    }

    Column {
        width: root.width
        spacing: ThemeManager.px(2)

        Repeater {
            model: SoundState.outputs

            delegate: ListRow {
                id: output

                required property var modelData

                icon: Icons.speaker
                title: output.modelData.name
                lit: output.modelData.current
                onClicked: SoundState.selectOutput(output.modelData)
            }
        }
    }

    Group {
        visible: SoundState.streams.length > 0

        // Uma linha por índice: a lista refeita com o mesmo tamanho não
        // recria as linhas, e o arrasto do volume não se perde. O volume e o
        // mudo vêm do nó.
        Repeater {
            model: SoundState.streams.length

            delegate: LevelRow {
                id: app

                required property int index
                readonly property var stream: SoundState.streams[app.index] ?? null

                icon: Icons.sound
                image: app.stream?.image ?? ""
                // O nome só na falta do ícone do app (a reserva).
                label: app.stream?.image ? "" : app.stream?.name ?? ""
                value: app.stream?.node?.audio?.volume ?? 0
                muted: app.stream?.node?.audio?.muted ?? false
                iconClickable: true
                onMoved: v => SoundState.setStreamVolume(app.stream, v)
                onIconClicked: SoundState.toggleStreamMute(app.stream)
            }
        }
    }
}
