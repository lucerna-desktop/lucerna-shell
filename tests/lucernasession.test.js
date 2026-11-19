// Testes de services/LucernaSession: os avisos da sessão (o session.json do
// lucerna-session). Só a função pura: nenhum aviso é mostrado.
function run(t) {
    const L = t.LucernaSession;
    const modeset = {
        summary: "A placa NVIDIA está sem o modeset do DRM",
        body: "Ligue nvidia-drm.modeset=1 nos parâmetros do kernel; sem ele, a placa da NVIDIA pode não funcionar no Lucerna."
    };

    t.test("lucernasession: aviso do modeset só com NVIDIA sem modeset", () => {
        t.eq(L.notices({ gpu: "nvidia", nvidiaModeset: false }, null), [modeset], "nvidia sem modeset");
        t.eq(L.notices({ gpu: "hybrid", nvidiaModeset: null }, null), [modeset], "híbrida sem a informação");
        t.eq(L.notices({ gpu: "intel", nvidiaModeset: null }, null), [], "intel");
        t.eq(L.notices({ gpu: "nvidia", nvidiaModeset: true }, null), [], "nvidia com modeset");
        t.eq(L.notices({}, null), [], "sem o session.json");
        t.eq(L.notices(null, null), [], "nulo");
    });

    // Um qs dentro da sessão Lucerna sem o supervisor (o exec_cmd do README
    // antigo, um bind `pkill -x qs; qs -c lucerna`) sai: senão seriam dois.
    t.test("lucernasession: só o qs do supervisor sobe na sessão Lucerna", () => {
        t.eq(L.unsupervised("1", ""), true, "na sessão, sem o supervisor: sai");
        t.eq(L.unsupervised("1", "1"), false, "na sessão, o do supervisor");
        t.eq(L.unsupervised("", ""), false, "fora da sessão Lucerna, sobe");
        t.eq(L.unsupervised("", "1"), false, "fora da sessão, com a variável, sobe");
    });

    t.test("lucernasession: aviso da queda e do modo de segurança", () => {
        const log = "/home/x/.local/state/lucerna/shell/qs-20261104-101010.log";
        t.eq(L.notices({}, { time: "2026-11-04T10:10:10-03:00", log, count: 1, safe: false }), [{
                summary: "O Lucerna reiniciou depois de uma falha",
                body: `O registro está em ${log}.`
            }], "uma queda");
        t.eq(L.notices({}, { time: "2026-11-04T10:10:10-03:00", log, count: 4, safe: true }), [{
                summary: "O Lucerna está no modo de segurança",
                body: `O registro está em ${log}. Ele caiu várias vezes seguidas; as suas personalizações estão desligadas até reiniciar normalmente.`
            }], "o modo de segurança");
        t.eq(L.notices({ gpu: "nvidia", nvidiaModeset: false }, { log, count: 2, safe: false }).map(n => n.summary), ["O Lucerna reiniciou depois de uma falha", modeset.summary], "a queda e o modeset");
        t.eq(L.notices({}, {}), [], "um crash.json vazio não avisa");
    });

    // Os apps padrão: o JSON do `lucerna-session detect-apps` e o apps.conf
    // que o shell grava (vazio = automático: a linha não entra).
    t.test("lucernasession: os apps instalados do detect-apps", () => {
        t.eq(L.parseApps('{"terminal": ["foot", "kitty"], "browser": [], "files": ["thunar"]}\n'), { terminal: ["foot", "kitty"], browser: [], files: ["thunar"] });
        t.eq(L.parseApps('{"terminal": "foot"}'), { terminal: [], browser: [], files: [] }, "formato estranho");
        t.eq(L.parseApps("lixo"), { terminal: [], browser: [], files: [] }, "JSON inválido");
    });

    t.test("lucernasession: o apps.conf dos apps padrão", () => {
        t.eq(L.appsConf({ terminal: "foot", browser: "", files: "thunar" }), "# Gerado pelo Lucerna (Configurações → Atalhos). Vazio = automático.\nterminal=foot\nfiles=thunar\n");
        t.eq(L.appsConf({}), "# Gerado pelo Lucerna (Configurações → Atalhos). Vazio = automático.\n", "tudo automático");
        t.eq(L.appsConf({ terminal: "foot\nbrowser=x" }), "# Gerado pelo Lucerna (Configurações → Atalhos). Vazio = automático.\nterminal=foot browser=x\n", "uma quebra de linha não vira outra chave");
    });

    // Uma escolha feita com a gravação anterior ainda rodando espera a vez
    // (como no HyprFile), em vez de se perder. A pasta vai para o /tmp e vai
    // na fila junto com o texto: o teste não grava no ~/.config. No fim, a
    // fila fica vazia.
    t.test("lucernasession: o apps.conf com uma gravação em curso espera a vez", () => {
        const dir0 = L.appsDir;
        try {
            L.appsDir = "/tmp/lucerna-test-apps";
            L.writeApps({ terminal: "foot" });
            t.eq([L.appsQueued, L.appsWriting], ["", true], "a primeira grava na hora");
            L.writeApps({ terminal: "kitty" });
            L.writeApps({ terminal: "alacritty" });
            t.eq(L.appsQueued, L.appsConf({ terminal: "alacritty" }), "a seguinte espera; só a mais nova");
            L.appsDir = dir0;
            t.eq(L.appsQueuedDir, "/tmp/lucerna-test-apps", "a pasta do pedido, não a de agora");
            // O fim da gravação (ou um sh que nem iniciou: só o running muda)
            // solta a marca e grava a da fila; o segundo sinal não repete.
            L.appsWriterStopped();
            t.eq([L.appsQueued, L.appsWriting], ["", true], "a da fila começa");
            L.appsWriterStopped();
            t.eq(L.appsWriting, false, "o segundo sinal só solta a marca");
            L.appsWriterStopped();
            t.eq([L.appsQueued, L.appsWriting], ["", false], "sem gravação, nada a fazer");
        } finally {
            L.appsQueued = "";
            L.appsDir = dir0;
        }
    });
}
