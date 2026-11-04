pragma Singleton

import Quickshell

// A subida do serviço de um app pelo shell, quando ninguém atende no socket
// dele ("Serviço sem systemd" no spec do protocolo, no lucerna-sdk): roda
// `<programa> serve` solto pelo services/scripts/serve.sh, com a saída no log
// do app ($XDG_STATE_HOME/lucerna/<app>/serve.log, o mesmo caminho do
// lucerna-paths). Comum a todos os LucernaClient: dois clientes do mesmo app
// pedindo juntos sobem um serviço só (o lock do `serve` também resolveria, mas
// o shell não dispara a segunda subida). Uma subida segura a próxima do mesmo
// app por `wait` ms, ou até um cliente conectar (release()).
Singleton {
    id: root

    // Quanto um cliente espera o serviço subido atender (o SPAWN_WAIT do SDK).
    readonly property int wait: 2000
    // App → quando a última subida rodou (Date.now()).
    property var starting: ({})
    // Roda de verdade (solto, numa sessão própria, pelo execDetached); os
    // testes desligam e só ouvem o `launched`.
    property bool live: true

    // Uma subida, com o comando dela (rodado ou não, conforme o `live`).
    signal launched(var argv)

    // $XDG_STATE_HOME/lucerna/<app>/serve.log, com o padrão ~/.local/state
    // quando ele falta ou é relativo; vazio sem nenhuma pasta absoluta.
    function logPath(stateHome: string, home: string, app: string): string {
        const base = stateHome.startsWith("/") ? stateHome : home.startsWith("/") ? `${home}/.local/state` : "";
        return base ? `${base}/lucerna/${app}/serve.log` : "";
    }

    // O comando da subida: o serve.sh com o programa e o log.
    function serveArgs(program: string, log: string): var {
        return [Quickshell.shellPath("services/scripts/serve.sh"), program, log];
    }

    // Sobe o serviço do `app`, se nenhuma subida dele estiver de pé há menos
    // de `wait` ms; diz se subiu. Sem programa ou sem log, não sobe.
    function launch(app: string, program: string, log: string, now: real): bool {
        if (!program || !log)
            return false;
        const last = starting[app];
        if (last !== undefined && now - last < root.wait)
            return false;
        const next = Object.assign({}, starting);
        next[app] = now;
        starting = next;
        console.info(`lucerna: subindo o serviço do ${app} (${program} serve, log em ${log})`);
        const argv = serveArgs(program, log);
        if (root.live)
            Quickshell.execDetached(argv);
        root.launched(argv);
        return true;
    }

    // Um cliente conectou: a próxima queda pode subir o serviço de novo.
    function release(app: string): void {
        if (starting[app] === undefined)
            return;
        const next = Object.assign({}, starting);
        delete next[app];
        starting = next;
    }
}
