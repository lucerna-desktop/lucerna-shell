// Testes da página do Wi-Fi da central (features/central): a senha que está
// sendo digitada, a rede aberta e o foco do campo sobrevivem à lista de redes
// refeita. O WifiState.networks gera itens novos a cada mudança das redes, e o
// Repeater recria as linhas; aqui a lista é falsa (sem NetworkManager no CI),
// com as mesmas linhas (WifiNetworkRow) da página, pelo t.wifiRows().
function run(t) {
    const W = t.WifiState;
    const C = t.CentralState;

    // Um item como os de WifiState.networks, de uma rede protegida e nova.
    function item(network, name, signal) {
        return { network: network, name: name, connected: false, known: false, busy: false, secure: true, needsPassword: true, icon: "", signal: signal };
    }

    // O campo de senha de cada linha, na ordem da lista.
    function find(node, name) {
        if (node.objectName === name)
            return node;
        for (const child of node.children) {
            const found = find(child, name);
            if (found)
                return found;
        }
        return null;
    }
    function fields(host) {
        return Array.from(host.children).filter(c => c.modelData !== undefined).map(row => find(row, "password"));
    }

    t.test("wifistate: a senha digitada sobrevive à lista refeita", () => {
        const home = t.object();
        const other = t.object();
        const host = t.wifiRows();
        try {
            host.model = [item(home, "Casa", 80), item(other, "Vizinho", 40)];
            W.activate(item(home, "Casa", 80));
            t.check(W.expanded === home, "a rede abriu");
            fields(host)[0].text = "segredo";
            t.eq(W.password, "segredo", "a senha fica no WifiState");

            const before = fields(host)[0];
            host.model = [item(home, "Casa", 70), item(other, "Vizinho", 45)];
            const after = fields(host);
            t.check(after[0] !== before, "a linha foi recriada (o caso do bug)");
            t.eq([after[0].text, after[1].text], ["segredo", ""], "a senha volta na linha nova da mesma rede");
            t.check(W.expanded === home, "a mesma rede segue aberta");
            t.eq([after[0].focus, after[1].focus], [true, false], "o campo recriado pega o foco; o da rede fechada, não");

            W.activate(item(other, "Vizinho", 45));
            t.eq([W.password, fields(host)[1].text], ["", ""], "outra rede começa sem senha");
            fields(host)[1].text = "outra";
            C.clearWifi();
            t.eq([W.expanded, W.password], [null, ""], "fechar a página apaga a senha");
            W.activate(item(other, "Vizinho", 45));
            t.eq(fields(host)[1].text, "", "reaberta, a rede começa sem a senha antiga");
        } finally {
            C.clearWifi();
            host.destroy();
        }
    });
}
