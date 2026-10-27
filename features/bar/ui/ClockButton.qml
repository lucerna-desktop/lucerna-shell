import QtQuick
import qs.core.theme
import qs.core.widgets
import qs.features.bar.state

// A hora (e a data, ao lado, se ligada), clicável: abre o painel superior.
Clickable {
    id: root

    property bool showDate: BarState.showDate

    width: clock.width + ThemeManager.spacing.normal * 2
    height: ThemeManager.barHeight - 8
    radius: height / 2
    active: BarState.dashboardOpen
    activeColor: ThemeManager.alpha(ThemeManager.colors.accent, 0.16)
    onClicked: BarState.togglePanel("dashboard")
    onHoveredChanged: BarState.clockHovered(hovered)

    Behavior on width { Anim { type: Anim.FastSpatial } }

    Row {
        id: clock

        anchors.centerIn: parent
        spacing: ThemeManager.spacing.small

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: BarState.time
            mono: true
            font.weight: Font.DemiBold
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showDate
            text: BarState.date
            muted: true
        }
    }
}
