// Testes de services/LucernaSession: os avisos da sessão (o session.json do
// lucerna-session). Só a função pura: nenhum aviso é mostrado.
function run(t) {
    const L = t.LucernaSession;
    const modeset = {
        summary: "A placa NVIDIA está sem o modeset do DRM",
        body: "Ligue nvidia-drm.modeset=1 nos parâmetros do kernel; sem ele, a placa da NVIDIA pode não funcionar no Lucerna."
    };

    t.test("lucernasession: aviso do modeset só com NVIDIA sem modeset", () => {
        t.eq(L.notices({ gpu: "nvidia", nvidiaModeset: false }), [modeset], "nvidia sem modeset");
        t.eq(L.notices({ gpu: "hybrid", nvidiaModeset: null }), [modeset], "híbrida sem a informação");
        t.eq(L.notices({ gpu: "intel", nvidiaModeset: null }), [], "intel");
        t.eq(L.notices({ gpu: "nvidia", nvidiaModeset: true }), [], "nvidia com modeset");
        t.eq(L.notices({}), [], "sem o session.json");
        t.eq(L.notices(null), [], "nulo");
    });
}
