// Testes da página do Wi-Fi da central (features/central): a senha que está
// sendo digitada, a rede aberta, o cursor e o foco do campo sobrevivem à lista
// de redes refeita, e a senha sai ao deixar a página ou fechar as Ações. O
// WifiState.networks gera itens novos a cada mudança das redes, e o Repeater
// recria as linhas; aqui a lista é falsa (sem NetworkManager no CI),
// com as mesmas linhas (WifiNetworkRow) da página, pelo t.wifiRows().
function run(t) {
    const W = t.WifiState;
    const C = t.CentralState;

    // Um item como os de WifiState.networks, de uma rede protegida e nova.
    function item(network, name, signal) {
        return { network: network, name: name, connected: false, known: false, busy: false, secure: true, needsPassword: true, icon: "", signal: signal };
    }

    // As linhas e o campo de senha de cada uma, na ordem da lista.
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
    function rows(host) {
        return Array.from(host.children).filter(c => c.modelData !== undefined);
    }
    function fields(host) {
        return rows(host).map(row => find(row, "password"));
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
            t.eq([W.expanded, W.password], [null, ""], "a clearWifi (ao abrir as Ações) apaga a senha");
            W.activate(item(other, "Vizinho", 45));
            t.eq(fields(host)[1].text, "", "reaberta, a rede começa sem a senha antiga");
        } finally {
            C.clearWifi();
            host.destroy();
        }
    });

    t.test("wifistate: o cursor volta onde estava na linha recriada", () => {
        const home = t.object();
        const host = t.wifiRows();
        try {
            host.model = [item(home, "Casa", 80)];
            W.activate(item(home, "Casa", 80));
            const field = fields(host)[0];
            field.text = "segredo";
            field.cursorPosition = 3;
            t.eq(W.cursor, 3, "o cursor fica no WifiState");
            host.model = [item(home, "Casa", 60)];
            t.eq([fields(host)[0].text, fields(host)[0].cursorPosition], ["segredo", 3], "a mesma senha, o mesmo cursor");
            W.activate(item(home, "Casa", 60));
            t.eq([W.password, W.cursor], ["", 0], "fechar a rede zera os dois");
        } finally {
            C.clearWifi();
            host.destroy();
        }
    });

    // A página e as Ações, pelo Panels como no central.test.js; no fim, os
    // painéis voltam ao que eram.
    t.test("wifistate: sair da página do Wi-Fi ou fechar as Ações apaga a senha", () => {
        const P = t.Panels;
        const opened0 = P.opened;
        const home = t.object();
        const host = t.wifiRows();
        try {
            host.model = [item(home, "Casa", 80)];
            P.openActions("");
            C.setPage("wifi");
            W.activate(item(home, "Casa", 80));
            fields(host)[0].text = "segredo";
            C.setPage("");
            t.eq([W.expanded, W.password], [null, ""], "voltar da página fecha a rede e apaga a senha");
            t.eq(rows(host)[0].open, false, "a linha volta fechada");

            C.setPage("wifi");
            W.activate(item(home, "Casa", 80));
            fields(host)[0].text = "segredo";
            P.closeActions();
            t.eq([C.page, W.password], ["wifi", ""], "fechar as Ações apaga a senha (a página fica até o card sumir)");
            t.eq(fields(host)[0].text, "segredo", "o campo que ainda aparece na saída fica como está");
        } finally {
            P.close();
            P.opened = opened0;
            C.clearWifi();
            host.destroy();
        }
    });

    t.test("wifistate: a rede aberta que some da lista fecha", () => {
        const home = t.object();
        const other = t.object();
        try {
            W.activate(item(home, "Casa", 80));
            W.dropMissing([item(home, "Casa", 70), item(other, "Vizinho", 40)]);
            t.check(W.expanded === home, "ainda na lista: segue aberta");
            W.password = "segredo";
            W.dropMissing([item(other, "Vizinho", 40)]);
            t.eq([W.expanded, W.password], [null, ""], "fora da lista: fecha e apaga a senha");
            W.dropMissing([]);
            t.eq(W.expanded, null, "sem rede aberta, nada muda");
        } finally {
            C.clearWifi();
        }
    });
}
