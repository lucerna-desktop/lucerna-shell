import QtQuick
import QtQuick.Shapes
import qs.core.shapes
import qs.core.theme

// Forma orgânica de "lobos" (tipo biscoito ou flor), desenhada com curva polar:
// r(θ) = raio · (1 + amplitude · cos(lobos · θ)). Substitui o qt6-m3shapes com
// recursos do próprio Qt. `pulse` (0 a 1) infla os lobos, para reagir ao áudio;
// `spinning` gira devagar. Com `morphing`, ignora `lobes` e `amplitude`: a cada
// ~6 s vira outra forma de BlobShapes.shapes, misturando as duas curvas em
// ~1,2 s. O relógio (BlobMorph) é próprio ou, com `driver`, compartilhado com
// outras bolhas, que então mudam e giram juntas: aí valem o giro e a troca de
// forma do `driver`, e `spinning`, `spinDuration` e `morphing` desta são
// ignorados (ela sempre segue a lista de formas). `active` falso (ou a bolha
// escondida) congela a forma e o ângulo: o relógio próprio pausa; o
// compartilhado segue para as outras, e esta volta já em sincronia com ele.
Item {
    id: root

    property int lobes: 8
    property real amplitude: 0.06
    property real pulse: 0
    property color color: ThemeManager.colors.raised
    property bool spinning: false
    property real spinDuration: 24000
    property bool morphing: false
    property bool active: true
    property BlobMorph driver: null
    // Pontos do contorno: menos numa bolha pequena.
    property int steps: 144
    // Numa bolha pequena (menos de 48 px na escala 1), os lobos ficam mais
    // suaves, na proporção do tamanho; de 48 px para cima, nada muda.
    readonly property real softness: Math.min(1, Math.min(width, height) / ThemeManager.px(48))

    readonly property bool live: visible && active
    readonly property BlobMorph clock: root.driver ?? own
    // Formas da lista: com `morphing` ou com um relógio compartilhado.
    readonly property bool shaped: morphing || driver !== null
    // O que está na tela: segue o relógio enquanto viva; parada, fica no último.
    property int shapeFrom: 0
    property int shapeTo: 0
    property real morph: 0
    property real angle: 0

    property real animatedPulse: pulse

    Behavior on animatedPulse { Anim { type: Anim.FastEffects } }

    implicitWidth: ThemeManager.px(100)
    implicitHeight: ThemeManager.px(100)

    readonly property var points: {
        const extra = animatedPulse * 0.08;
        const grow = s => ({ lobes: s.lobes, amplitude: s.amplitude * softness + extra });
        const a = shaped ? BlobShapes.shapes[shapeFrom] : { lobes: lobes, amplitude: amplitude };
        const b = shaped ? BlobShapes.shapes[shapeTo] : a;
        return BlobShapes.outline(width, height, grow(a), grow(b), shaped ? morph : 0, steps);
    }

    BlobMorph {
        id: own

        morphing: root.morphing && root.live && root.driver === null
        spinning: root.spinning && root.live && root.driver === null
        spinDuration: root.spinDuration
    }

    Binding {
        root.shapeFrom: root.clock.shapeFrom
        root.shapeTo: root.clock.shapeTo
        root.morph: root.clock.morph
        root.angle: root.clock.angle
        when: root.live
        restoreMode: Binding.RestoreNone
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        rotation: root.angle

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.color

            PathPolyline {
                path: root.points
            }
        }
    }
}
