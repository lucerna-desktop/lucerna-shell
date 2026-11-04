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
}
