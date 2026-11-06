import QtQuick
import QtQuick.Shapes
import qs.core.theme

// Gráfico de linha de um histórico curto, com preenchimento suave embaixo.
// A escala se ajusta ao maior valor (ou a `maxValue`, se definido). Para uma
// série com tempo irregular, `normalized` traz os pontos já na escala ({ x, y }
// de 0 a 1, y de baixo para cima) e `values` fica de lado.
Item {
    id: root

    property var values: []
    property var normalized: []
    property real maxValue: 0
    property color color: ThemeManager.colors.accent
    readonly property real ceiling: maxValue > 0 ? maxValue : Math.max(1, ...values)

    function point(i: int, v: real): point {
        const n = Math.max(1, values.length - 1);
        return Qt.point(i / n * width, height - ThemeManager.px(2) - (v / ceiling) * (height - ThemeManager.px(4)));
    }

    readonly property var points: normalized.length > 0 ? normalized.map(p => Qt.point(p.x * width, height - ThemeManager.px(2) - p.y * (height - ThemeManager.px(4)))) : values.map((v, i) => point(i, v))

    Shape {
        anchors.fill: parent
        visible: root.points.length > 1
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                y1: 0
                y2: root.height

                GradientStop { position: 0; color: ThemeManager.alpha(root.color, 0.28) }
                GradientStop { position: 1; color: ThemeManager.alpha(root.color, 0) }
            }

            PathPolyline {
                path: root.points.length > 1 ? [Qt.point(root.points[0].x, root.height), ...root.points, Qt.point(root.points[root.points.length - 1].x, root.height)] : []
            }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: ThemeManager.px(2)
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap

            PathPolyline {
                path: root.points
            }
        }
    }
}
