pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.core.theme
import qs.core.widgets
import qs.features.dashboard.state

// Aba Desempenho: CPU, GPU, disco, rede e memória.
Item {
    id: root

    // Só com o painel aberto nesta aba as bolhas se mexem: o painel carrega
    // todas as abas, e o `visible` delas não muda.
    readonly property bool onScreen: DashboardState.isShowing("performance")

    // Pelo menos a altura comum das abas; a sobra vai para a linha de baixo.
    implicitHeight: PerformanceState.available ? Math.max(layout.implicitHeight, DashboardState.pageHeight) : unavailable.implicitHeight

    // Um relógio só para as bolhas da CPU e da GPU: mudam para a mesma figura
    // e giram juntas. Roda com a aba na tela; a bolha parada (GPU sem dados)
    // congela, e o relógio segue para a outra.
    BlobMorph {
        id: blobClock

        morphing: root.onScreen && PerformanceState.available
        spinning: root.onScreen && PerformanceState.available
        spinDuration: 30000
    }

    AnimatedNumber {
        id: cpuNumber

        value: PerformanceState.cpuUsage
    }

    // O uso da GPU na tela, quando ela tem uso (com clock, os MHz vão direto).
    AnimatedNumber {
        id: gpuNumber

        value: PerformanceState.gpu?.unit === "%" ? PerformanceState.gpu.fraction : 0
    }

    // Sem o lucernad: a forma com o ícone e o motivo, no lugar dos cards.
    EmptyState {
        id: unavailable

        visible: !PerformanceState.available
        icon: Icons.performance
        text: PerformanceState.unavailableText
    }

    ColumnLayout {
        id: layout

        visible: PerformanceState.available
        width: parent.width
        height: root.implicitHeight
        spacing: ThemeManager.spacing.normal

        // CPU e GPU lado a lado, metade cada; sem a GPU, a CPU ocupa a linha.
        RowLayout {
            Layout.fillWidth: true
            spacing: ThemeManager.spacing.normal

            StatCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                icon: Icons.cpu
                title: `CPU - ${PerformanceState.cpuModel}`
                fraction: PerformanceState.cpuUsage
                value: `${Math.round(cpuNumber.shown * 100)}`
                unit: "%"
                hasTemp: PerformanceState.hasTemp
                tempText: PerformanceState.cpuTempText
                tempFraction: PerformanceState.cpuTempFraction
                hot: PerformanceState.cpuHot
                pulse: PerformanceState.cpuUsage
                blobActive: root.onScreen
                blobDriver: blobClock
            }

            // Uma GPU por vez (a dedicada primeiro); o clique passa para a
            // próxima.
            StatCard {
                readonly property var gpu: PerformanceState.gpu

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                visible: PerformanceState.showGpu
                icon: Icons.gpu
                title: `GPU - ${gpu?.name ?? "nenhuma encontrada"}`
                fraction: gpu?.fraction ?? 0
                label: gpu?.label ?? ""
                value: gpu?.unit === "%" ? `${Math.round(gpuNumber.shown * 100)}` : gpu?.value ?? "—"
                unit: gpu?.unit ?? ""
                hasTemp: gpu?.hasTemp ?? false
                tempText: gpu?.tempText ?? ""
                tempFraction: gpu?.tempFraction ?? 0
                hot: gpu?.hot ?? false
                pulse: fraction
                // Parada em repouso ou sem dados (não há o que mostrar).
                blobActive: root.onScreen && (gpu?.hasData ?? false)
                blobDriver: blobClock
                clickable: PerformanceState.gpus.length > 1
                dots: PerformanceState.gpus.length
                dot: PerformanceState.gpuIndex
                onSwapped: PerformanceState.cycleGpu()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: ThemeManager.spacing.normal

            // Um disco físico por vez (o da raiz primeiro); o clique passa
            // para o próximo.
            GaugeCard {
                Layout.preferredWidth: 230
                Layout.fillHeight: true
                icon: Icons.storage
                title: `Disco - ${PerformanceState.disk?.name ?? "nenhum encontrado"}`
                fraction: PerformanceState.disk?.fraction ?? 0
                label: PerformanceState.disk?.text ?? ""
                clickable: PerformanceState.disks.length > 1
                dots: PerformanceState.disks.length
                dot: PerformanceState.diskIndex
                onSwapped: PerformanceState.cycleDisk()
            }

            // Rede
            Surface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 190
                clip: true

                // O título no padrão dos outros cards (o do GaugeCard e do StatCard).
                CardTitle {
                    id: netHeader

                    x: ThemeManager.spacing.normal + 2
                    y: ThemeManager.spacing.normal + 2
                    width: parent.width - 2 * (ThemeManager.spacing.normal + 2)
                    icon: Icons.network
                    text: "Rede"
                }

                Sparkline {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: netHeader.bottom
                    anchors.bottom: rates.top
                    anchors.margins: ThemeManager.spacing.small
                    values: PerformanceState.rxHistory
                    maxValue: PerformanceState.netScale
                }

                Sparkline {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: netHeader.bottom
                    anchors.bottom: rates.top
                    anchors.margins: ThemeManager.spacing.small
                    values: PerformanceState.txHistory
                    maxValue: PerformanceState.netScale
                    color: ThemeManager.colors.textMuted
                }

                Column {
                    id: rates

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: ThemeManager.spacing.normal + 2
                    spacing: 4

                    Repeater {
                        model: [
                            { icon: Icons.download, label: "Download", value: PerformanceState.download, accent: true },
                            { icon: Icons.upload, label: "Upload", value: PerformanceState.upload, accent: false }
                        ]

                        delegate: Row {
                            required property var modelData

                            width: parent.width
                            spacing: ThemeManager.spacing.small

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: parent.modelData.icon
                                size: 16
                                color: parent.modelData.accent ? ThemeManager.colors.accent : ThemeManager.colors.textMuted
                            }

                            Txt {
                                width: parent.width - 16 - rateText.width - parent.spacing * 2
                                text: parent.modelData.label
                                muted: true
                                font.pixelSize: ThemeManager.font.small + 1
                            }

                            Txt {
                                id: rateText

                                text: parent.modelData.value
                                mono: true
                                color: parent.modelData.accent ? ThemeManager.colors.accent : ThemeManager.colors.text
                                font.pixelSize: ThemeManager.font.small + 1
                            }
                        }
                    }

                    Txt {
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        text: PerformanceState.totals
                        faint: true
                        mono: true
                        font.pixelSize: ThemeManager.font.small
                    }
                }
            }

            GaugeCard {
                Layout.preferredWidth: 230
                Layout.fillHeight: true
                icon: Icons.memory
                title: "Memória"
                fraction: PerformanceState.memFraction
                label: PerformanceState.memText
            }
        }
    }
}
