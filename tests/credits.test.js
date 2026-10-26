// Testes dos créditos nas Configurações: o tópico antes do Sobre e as três
// seções (inspiração, dados e base), todas com link https.
function run(t) {
    const S = t.SettingsState;

    t.test("créditos: o tópico vem antes do Sobre", () => {
        const ids = S.topics.map(topic => topic.id);
        t.eq(ids.indexOf("credits"), ids.indexOf("about") - 1);
        t.check(ids.indexOf("credits") >= 0);
    });

    t.test("créditos: as três seções e os links", () => {
        const sections = Array.from(S.credits);
        t.eq(sections.map(s => s.title), ["Inspiração", "Dados", "Base"]);
        const items = [];
        for (const s of sections)
            items.push(...Array.from(s.items));
        const names = items.map(i => i.name);
        for (const name of ["Caelestia Shell", "Open-Meteo", "LRCLIB", "Vagalume", "Quickshell", "Hyprland", "Material Symbols"])
            t.check(names.includes(name), name);
        for (const item of items)
            t.check(item.url.startsWith("https://"), item.url);
        t.check(items.find(i => i.name === "Open-Meteo").detail.includes("CC BY 4.0"));
    });
}
