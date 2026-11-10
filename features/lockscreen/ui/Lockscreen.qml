import QtQuick
import Quickshell.Wayland
import qs.core.theme
import qs.features.lockscreen.state

// Bloqueio pelo protocolo ext-session-lock: se o shell cair, o compositor
// continua bloqueado.
WlSessionLock {
    locked: LockscreenState.locked
    // O secure (o compositor confirmou o bloqueio) solta o inibidor de sono.
    onSecureChanged: LockscreenState.setSecure(secure)
    // Depois de um reload com a tela bloqueada, o bloqueio já chega seguro
    // (sem mudança, sem o onSecureChanged): sem isto, a Session ficaria com o
    // secure falso e a suspensão seguinte esperaria o prazo do logind.
    Component.onCompleted: LockscreenState.setSecure(secure)

    WlSessionLockSurface {
        color: ThemeManager.colors.base

        LockSurface {
            anchors.fill: parent
        }
    }
}
