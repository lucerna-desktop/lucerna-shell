import QtQuick
import QtQuick.Shapes
import qs.core.theme

// Medidor em arco (270°, aberto embaixo). `value` vai de 0 a 1.
Item {
    id: root

    property real value: 0
    property real thickness: ThemeManager.px(8)
    property color color: ThemeManager.colors.accent
    property color trackColor: ThemeManager.colors.track
    property real animatedValue: Math.max(0, Math.min(1, value))
    default property alias content: center.data

    readonly property real sweep: 270
    readonly property real start: 135

    Behavior on animatedValue { Anim { type: Anim.StandardLarge } }

    implicitWidth: ThemeManager.px(120)
    implicitHeight: ThemeManager.px(120)

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (Math.min(root.width, root.height) - root.thickness) / 2
                radiusY: radiusX
                startAngle: root.start
                sweepAngle: root.sweep
            }
        }

        ShapePath {
            strokeColor: root.animatedValue > 0.001 ? root.color : "transparent"
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (Math.min(root.width, root.height) - root.thickness) / 2
                radiusY: radiusX
                startAngle: root.start
                sweepAngle: root.sweep * root.animatedValue
            }
        }
    }

    Item {
        id: center

        anchors.fill: parent
    }
}
