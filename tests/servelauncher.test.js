// Testes de services/lucerna/ServeLauncher: o comando da subida, o caminho do
// log e uma subida só por app de cada vez. Com o `live` desligado, só o
// `launched` anota o comando: nenhum processo é rodado.
function run(t) {
    const L = t.ServeLauncher;

    // Um caso com o `live` desligado, o `launched` anotando em `runs` e as
    // subidas zeradas, desfeitos no fim (mesmo com exceção).
    function withLauncher(name, body) {
        t.test(name, () => {
            const runs = [];
            const note = argv => runs.push(argv);
            L.live = false;
            L.launched.connect(note);
            L.starting = ({});
            try {
                body(runs);
            } finally {
                L.launched.disconnect(note);
                L.live = true;
                L.starting = ({});
            }
        });
    }

    withLauncher("servelauncher: o log no lugar do SDK", () => {
        t.eq(L.logPath("/x/state", "/home/u", "hello"), "/x/state/lucerna/hello/serve.log");
        t.eq(L.logPath("", "/home/u", "hello"), "/home/u/.local/state/lucerna/hello/serve.log", "sem XDG_STATE_HOME, o padrão");
        t.eq(L.logPath("rel/state", "/home/u", "hello"), "/home/u/.local/state/lucerna/hello/serve.log", "relativo não vale");
        t.eq(L.logPath("", "", "hello"), "", "sem pasta nenhuma, sem log");
        t.eq(L.logPath("", "rel", "hello"), "", "HOME relativo não vale");
    });

    withLauncher("servelauncher: o comando roda o serve.sh com o programa e o log", () => {
        const argv = L.serveArgs("lucerna-hello", "/s/serve.log");
        t.eq(argv.length, 3);
        t.check(argv[0].endsWith("/services/scripts/serve.sh"), argv[0]);
        t.eq(argv.slice(1), ["lucerna-hello", "/s/serve.log"]);
    });

    withLauncher("servelauncher: uma subida por app a cada 2 s", runs => {
        t.check(L.launch("hello", "lucerna-hello", "/s/h.log", 1000), "a primeira sobe");
        t.check(!L.launch("hello", "lucerna-hello", "/s/h.log", 2999), "a segunda, dentro dos 2 s, não");
        t.check(L.launch("notes", "lucerna-notes", "/s/n.log", 1500), "outro app sobe");
        t.check(L.launch("hello", "lucerna-hello", "/s/h.log", 3000), "passados os 2 s, sobe de novo");
        t.eq(runs.map(argv => argv[1]), ["lucerna-hello", "lucerna-notes", "lucerna-hello"]);
    });

    withLauncher("servelauncher: conectar libera a próxima subida", runs => {
        t.check(L.launch("hello", "lucerna-hello", "/s/h.log", 1000));
        L.release("hello");
        L.release("outro");
        t.check(L.launch("hello", "lucerna-hello", "/s/h.log", 1100), "depois de conectar, a queda sobe de novo");
        t.eq(runs.length, 2);
    });

    withLauncher("servelauncher: sem programa ou sem log, não sobe", runs => {
        t.check(!L.launch("hello", "", "/s/h.log", 1000));
        t.check(!L.launch("hello", "lucerna-hello", "", 1000));
        t.eq([runs, L.starting], [[], {}]);
    });
}
