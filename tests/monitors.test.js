// Testes de services/Monitors: normalização do hyprctl, o Lua do arranjo e a tampa.
function run(t) {
    const M = t.Monitors;
    const raw = {
        name: "DP-1", make: "LG", model: "27GL850", serial: "", description: "LG 27GL850 (DP-1)",
        disabled: false, width: 2560, height: 1440, refreshRate: 143.973, x: 0, y: 0, scale: 1.25,
        transform: 5, vrr: true, currentFormat: "XRGB2101010", mirrorOf: "none", focused: true,
        availableModes: ["2560x1440@143.97Hz", "1920x1080@60.00Hz"]
    };
    const spec = { name: "DP-1", enabled: true, width: 2560, height: 1440, refresh: 143.97, x: 0, y: 0, scale: 1.25, transform: 1, vrr: 1, tenBit: true, mirror: "" };

    t.test("monitors: chave estável do monitor", () => {
        t.eq(M.keyOf({ make: "LG", model: "27GL850", serial: "123", name: "DP-1" }), "LG 27GL850 123");
        t.eq(M.keyOf({ make: "", model: "", serial: "", name: "HDMI-A-1" }), "HDMI-A-1");
    });

    t.test("monitors: modo do Hyprland", () => {
        t.eq(M.parseMode("1920x1080@143.99Hz"), { width: 1920, height: 1080, refresh: 143.99 });
        t.eq(M.parseMode("auto"), null);
    });

    t.test("monitors: normaliza o monitor do hyprctl", () => {
        const m = M.normalize(raw, {});
        t.eq([m.name, m.key, m.label, m.enabled, m.width, m.height, m.refresh, m.scale, m.transform, m.vrr, m.tenBit, m.mirror, m.focused],
             ["DP-1", "LG 27GL850", "LG 27GL850", true, 2560, 1440, 143.97, 1.25, 1, 1, true, "", true]);
        t.eq(m.modes.length, 2, "o modo atual já está na lista");
    });

    t.test("monitors: espelho pelo id e modo atual fora da lista", () => {
        const m = M.normalize(Object.assign({}, raw, { mirrorOf: "1", availableModes: [] }), { "1": "HDMI-A-1" });
        t.eq(m.mirror, "HDMI-A-1");
        t.eq(m.modes, [{ width: 2560, height: 1440, refresh: 143.97 }]);
    });

    t.test("monitors: tamanho lógico com rotação e escala", () => {
        t.eq(M.logicalSize(spec), { width: 1152, height: 2048 });
        t.eq(M.logicalSize(Object.assign({}, spec, { transform: 0, scale: 1 })), { width: 2560, height: 1440 });
    });

    t.test("monitors: código Lua do arranjo", () => {
        t.eq(M.luaFor({ name: "DP-1", enabled: false }), 'hl.monitor({ output = "DP-1", disabled = true })');
        const line = 'hl.monitor({ output = "DP-1", disabled = false, mode = "2560x1440@143.97", position = "0x0", scale = 1.25, transform = 1, vrr = 1, bitdepth = 10, mirror = "" })';
        t.eq(M.luaFor(spec), line);
        t.eq(M.lua([spec, { name: "HDMI-A-1", enabled: false }]), `${line}\nhl.monitor({ output = "HDMI-A-1", disabled = true })`);
    });

    // A tampa: o interno casa com eDP/LVDS/DSI; os outros são externos.
    const mon = (name, enabled) => ({ name: name, enabled: enabled });
    const laptop = mon("eDP-1", true);

    t.test("monitors: tampa fechada com externo só desliga o interno", () => {
        t.eq(M.lidPlan(true, [laptop, mon("HDMI-A-1", true)], false), { disable: ["eDP-1"], enable: [], lock: false });
        t.eq(M.lidPlan(true, [mon("eDP-1", false), mon("HDMI-A-1", true)], false), { disable: [], enable: [], lock: false }, "já desligado");
    });

    t.test("monitors: com a opção ligada também bloqueia", () => {
        t.eq(M.lidPlan(true, [laptop, mon("DP-2", true)], true), { disable: ["eDP-1"], enable: [], lock: true });
    });

    t.test("monitors: tampa fechada sem externo não faz nada", () => {
        t.eq(M.lidPlan(true, [laptop], true), { disable: [], enable: [], lock: false });
        t.eq(M.lidPlan(true, [laptop, mon("HDMI-A-1", false)], true), { disable: [], enable: [], lock: false }, "externo desligado não conta");
    });

    t.test("monitors: tampa aberta religa o interno", () => {
        t.eq(M.lidPlan(false, [mon("eDP-1", false), mon("HDMI-A-1", true)], true), { disable: [], enable: ["eDP-1"], lock: false });
        t.eq(M.lidPlan(false, [laptop, mon("HDMI-A-1", true)], true), { disable: [], enable: [], lock: false }, "já ligado");
        t.eq(M.lidPlan(false, [mon("LVDS-1", false)], false), { disable: [], enable: ["LVDS-1"], lock: false });
    });

    t.test("monitors: o externo saiu com a tampa fechada religa o interno", () => {
        t.eq(M.lidPlan(true, [mon("eDP-1", false)], true), { disable: [], enable: ["eDP-1"], lock: false });
        t.eq(M.lidPlan(true, [mon("DSI-1", false), mon("HDMI-A-1", false)], false), { disable: [], enable: ["DSI-1"], lock: false });
    });

    t.test("monitors: desktop sem interno ignora a tampa", () => {
        const none = { disable: [], enable: [], lock: false };
        t.eq(M.lidPlan(true, [mon("WAYLAND-1", true)], true), none);
        t.eq(M.lidPlan(true, [mon("DP-1", true), mon("HDMI-A-1", true)], true), none);
        t.eq(M.lidPlan(false, [mon("DP-1", false), mon("HDMI-A-1", true)], true), none);
        t.eq(M.lidPlan(true, [], true), none);
    });

    // O modo "Escala pelos apps": os monitores em 1, com o arranjo guardado à parte.
    t.test("monitors: o arranjo do modo pelos apps tem chave própria", () => {
        t.eq(M.setupKey("A | B", false), "A | B");
        t.eq(M.setupKey("A | B", true), "apps: A | B");
    });

    t.test("monitors: o arranjo em outra escala segue as bordas encostadas", () => {
        const at = (name, x, y, scale) => ({ name: name, enabled: true, width: 2560, height: 1440, refresh: 60, x: x, y: y, scale: scale, transform: 0, vrr: 0, tenBit: false, mirror: "" });
        const row = M.atScale([at("DP-1", 0, 0, 1.25), at("DP-2", 2048, 0, 1.25)], 1);
        t.eq(row.map(m => [m.x, m.y, m.scale]), [[0, 0, 1], [2560, 0, 1]], "lado a lado");
        const column = M.atScale([at("DP-1", 0, 0, 1.25), at("DP-2", 0, 1152, 1.25)], 1);
        t.eq(column.map(m => [m.x, m.y]), [[0, 0], [0, 1440]], "um em cima do outro");
        const mixed = M.atScale([at("DP-1", 0, 0, 2), at("DP-2", 1280, 0, 1)], 1);
        t.eq(mixed.map(m => m.x), [0, 2560], "escalas diferentes");
        const spare = M.atScale([at("DP-1", 0, 0, 1.25), Object.assign(at("DP-2", 0, 0, 1.5), { enabled: false })], 1);
        t.eq([spare[1].scale, spare[1].x], [1, 0], "o desligado só muda a escala");
        const same = M.atScale([at("DP-1", 0, 0, 1), at("DP-2", 2560, 0, 1)], 1);
        t.eq(same.map(m => m.x), [0, 2560], "já em 1, nada muda");
    });
}
