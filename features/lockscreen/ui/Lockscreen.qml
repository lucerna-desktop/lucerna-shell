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

    WlSessionLockSurface {
        color: ThemeManager.colors.base

        LockSurface {
            anchors.fill: parent
        }
    }
}
