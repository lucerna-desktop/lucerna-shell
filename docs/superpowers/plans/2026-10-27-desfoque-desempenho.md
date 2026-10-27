# Desempenho do desfoque — plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIO: use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para implementar este plano tarefa por tarefa. Os passos usam checkbox (`- [ ]`) para acompanhamento.

**Objetivo:** baixar o custo do desfoque do Hyprland nas camadas do Lucerna (monitor de 144 Hz do usuário) sem piorar a aparência: níveis Desempenho (xray) / Completo / Desligado, papel de parede animado pausado sob as camadas desfocadas, menos passadas com `size` maior, `vfr`/`new_optimizations`/`popups` garantidos e desfoque das janelas opcional.

**Arquitetura:** o dado fica no `ThemeManager` (`core/`, no gate de cobertura): `blur.mode` lido do `Config.blurOverride.mode`, do tema ou `"performance"`, com a migração do `enabled: false` antigo, e o IPC `blur`. As regras para o Hyprland continuam no `ThemeSwitcherState` (`features/themeSwitcher/state`), em funções puras testadas, enviadas por `Hypr.evalLua` e reenviadas no `reapply()`. A decisão de pausar o papel de parede entra no `WallpaperState.shouldAnimate` por uma função pura sobre as janelas do `Panels` e do `Frame`. A interface (Configurações → Transparência e desfoque) só lê o `SettingsState`.

**Tecnologia:** Quickshell 0.3.1 (QML/Qt 6), Hyprland 0.56.2 com config em Lua (`hyprctl eval`), harness `tests/runner.qml` no `qs`, `dev/ci.sh` (lint, rules, unit, smoke no `archlinux:latest`) e `dev/test.sh` (container `lucerna-polish`, capturas em 1920×1080, 60 Hz).

**Spec:** `docs/superpowers/specs/2026-10-27-desfoque-desempenho-design.md` (leia inteiro antes da primeira tarefa; este plano argumenta a partir dele).

## Global Constraints

- Níveis e valores guardados: `"performance"` (Desempenho, padrão), `"full"` (Completo), `"off"` (Desligado), em `Config.blurOverride.mode`; o tema pode trazer `hyprland.blurMode`. `blurOverride.enabled === false` antigo vale `"off"`, sem reescrever o arquivo.
- Regra de camada: `hl.layer_rule({ match = { namespace = "^lucerna-panel-.*" }, blur = <mode !== "off" e transparência ligada>, xray = <mode === "performance">, ignore_alpha = 0.45 })`.
- Config de desfoque: `hl.config({ debug = { vfr = true }, decoration = { blur = { size = S, passes = P, new_optimizations = true, popups = false } } })`. No 0.56 o `vfr` é `debug:vfr`; `misc:vfr` não existe.
- Janelas sem desfoque: `hl.window_rule({ match = { class = ".*" }, no_blur = true })`; religar = `hyprctl reload` (o `reapply()` manda o resto de volta). Nunca `no_blur = false`, nunca `decoration.blur.enabled = false`.
- Temas: `blurSize: 12`, `blurPasses: 1` (alternativa, se a captura mostrar blocos: 8 e 2).
- Papel de parede: **pausa** (não baixa o FPS) quando a transparência e o desfoque estão ligados e, naquela tela, há janela do `Panels.surfaces` visível ou janela do `Frame.windows` visível. Popups de notificação e janelas de monitores não pausam.
- IPC: `qs -c lucerna ipc call blur set <performance|full|off>` e `blur get`. Valor desconhecido não muda nada.
- Camadas (`ci/rules.py`): `core/` não importa `qs.features` nem `qs.services`; `features/*/ui` não importa `qs.services`; uma feature não importa outra.
- Lint com `MaxWarnings=0`; nenhuma supressão nova do qmllint; estilo compacto da casa, sem `qmlformat`.
- Funções do `core/` declaradas como `function nome(...) {` numa linha, 100% chamadas pelos testes; IPC do `core/` vai para as `exceções` do `tests/coverage.json` com o motivo.
- Testes: prefira `t.eq`; restaure `Config.blurOverride`, `Config.blurWindows`, `Panels.opened` no fim de cada caso (`try/finally`); nada de `hyprctl` real, D-Bus real, hardware, internet ou espera real.
- Regras sempre por `dev/ci.sh rules` (no container do CI), não por `python3 ci/rules.py` no host.
- Tudo em português do Brasil com acentos (interface, comentários, documentação, commits); mensagens de commit no padrão do log ("Desfoque: …", "Temas: …").
- Conferência visual só no `lucerna-polish` (`dev/test.sh`); nunca mexer no `lucerna-dev` nem na sessão real do usuário. Nenhum `hyprctl` contra o Hyprland do host.
- Empurrar e abrir PR só com a confirmação do usuário; conta do `gh`: `EduardoSA8006`.

## Review Focus

1. **Config antigo com `blurOverride: { enabled: false, size: 10 }`**: o esperado é o nível Desligado e o `size` 10 mantidos, e escolher outro nível gravar `mode` sem perder o `size`. Teste na Tarefa 1 ("theme: o enabled antigo vira o nível desligado").
2. **Modo leve ou transparência desligada com o nível Desempenho**: o esperado é a regra sair com `blur = false` (e o papel de parede não pausar), como hoje. Testes na Tarefa 2 ("themeswitcher: sem transparência, sem desfoque") e na Tarefa 5 ("wallpaper: sem desfoque, não pausa").
3. **`hyprctl reload` feito pelo usuário com as janelas sem desfoque**: o esperado é a regra `no_blur` voltar junto com as outras. Teste na Tarefa 2 ("themeswitcher: o reload reenvia as regras do desfoque").
4. **Painel aberto em outro monitor**: o esperado é só o papel de parede daquela tela pausar. Teste na Tarefa 5 ("wallpaper: pausa só a tela coberta").
5. **IPC `blur set` com valor errado** (`blur set xray`, vazio): o esperado é nada mudar e o `get` devolver o nível anterior. Teste na Tarefa 1 ("theme: nível desconhecido não muda nada") e passo na fumaça (Tarefa 6).

---

## Decisões

- **`enabled` derivado:** `ThemeManager.blur.enabled` passa a ser `mode !== "off"`; quem já lê `enabled` (o `ThemeSwitcherState`, o `SettingsState`) continua certo. `setBlur("enabled", …)` deixa de ser chamado pela interface (vira `setBlurMode`).
- **`Config.blurWindows`** (bool, padrão `true`) fora do `blurOverride`: o "Restaurar padrões do tema" não o toca.
- **O reload só no religar:** desligar envia a regra; religar chama `Hypr.reloadConfig()` (novo, `hyprctl reload`). A partida com `blurWindows` falso envia a regra no `Component.onCompleted`, junto do `frameRule`.
- **A pausa é por tela e lê as janelas**, não `Panels.anyOpen`: um painel em outro monitor não pausa este.

### Task 1: Nível do desfoque no ThemeManager e IPC `blur`

**Files:**
- Modify: `core/theme/ThemeManager.qml` (`BlurTokens`, `blur`, `setBlur` vizinhança, `IpcHandler`)
- Modify: `core/config/Config.qml` (comentário do `blurOverride`; `property bool blurWindows: true` e o alias)
- Modify: `tests/theme.test.js`, `tests/coverage.json`

**Interfaces:**
- Produces: `ThemeManager.blur.mode: string` (`"performance" | "full" | "off"`); `ThemeManager.blur.enabled: bool` (= `mode !== "off"`); `ThemeManager.blurModes: var` = `["performance", "full", "off"]`; `function modeFrom(custom: var, theme: var): string` (pura); `function setBlurMode(mode: string): void` (ignora valor fora de `blurModes`); `IpcHandler { target: "blur" }` com `set(mode: string): void` e `get(): string`; `Config.blurWindows: bool`.

- [ ] **Step 1: Testes que falham** em `tests/theme.test.js`:

```js
t.test("theme: nível do desfoque, do tema e do usuário", () => {
    try {
        t.eq([T.blur.mode, T.blur.enabled], ["performance", true], "padrão");
        T.setBlurMode("full");
        t.eq([T.blur.mode, T.blur.customized], ["full", true]);
        T.setBlurMode("off");
        t.eq([T.blur.mode, T.blur.enabled], ["off", false]);
    } finally { T.resetGlass(); }
});
t.test("theme: o enabled antigo vira o nível desligado", () => {
    t.eq(T.modeFrom({ enabled: false, size: 10 }, {}), "off");
    t.eq(T.modeFrom({ enabled: true }, { blurMode: "full" }), "full");
    t.eq(T.modeFrom({}, { blur: false }), "off");
    t.eq(T.modeFrom({ mode: "full", enabled: false }, {}), "full", "o mode novo vence");
    t.eq(T.modeFrom({}, {}), "performance");
});
t.test("theme: nível desconhecido não muda nada", () => {
    try {
        T.setBlurMode("full");
        T.setBlurMode("xray");
        T.setBlurMode("");
        t.eq(T.blur.mode, "full");
    } finally { T.resetGlass(); }
});
```

- [ ] **Step 2:** `dev/ci.sh unit` — esperado: FAIL (`setBlurMode`/`modeFrom` não existem).
- [ ] **Step 3: Implementar** no `ThemeManager`: `BlurTokens` ganha `property string mode`; `blur.mode: root.modeFrom(custom, root.data.hyprland ?? {})`; `enabled: mode !== "off"`. `modeFrom`: `custom.mode` válido → ele; senão `custom.enabled === false` → `"off"`; senão `theme.blurMode` válido → ele; senão `theme.blur === false` → `"off"`; senão `"performance"`. `setBlurMode` valida e chama `setBlur("mode", mode)`. `IpcHandler` `blur` repassa a `setBlurMode` e devolve `blur.mode`. Em `tests/coverage.json`, `exceções`: `"core/theme/ThemeManager.qml:IpcHandler.set"` já existe para o `theme` — confira como o `coverage.py` nomeia dois `IpcHandler` no mesmo arquivo (pelo `target`, ou pela ordem) e registre os dois do `blur` com o motivo "IPC blur: repassa a setBlurMode(), testada; exercitado pela fumaça". `Config`: comentário `blurOverride: { mode, enabled (antigo), size, passes }` e `blurWindows`.
- [ ] **Step 4:** `dev/ci.sh unit` — esperado: `RESULT passed=N failed=0` e cobertura 100%.
- [ ] **Step 5: Commit** — `git commit -m "Desfoque: o nível (desempenho, completo, desligado) no tema e no IPC"`

### Task 2: Regras do desfoque no ThemeSwitcherState

**Files:**
- Modify: `features/themeSwitcher/state/ThemeSwitcherState.qml` (bloco "Integração com o Hyprland")
- Modify: `services/Hypr.qml` (`function reloadConfig(): void` → `Quickshell.execDetached(["hyprctl", "reload"])`)
- Modify: `tests/themeswitcher.test.js`

**Interfaces:**
- Consumes: `ThemeManager.blur.mode`, `ThemeManager.transparency.enabled`, `Config.blurWindows` (Task 1).
- Produces: `function blurLua(mode: string, transparency: bool): string`; `function blurConfigLua(size: int, passes: int): string`; `function windowBlurLua(): string` (a regra `no_blur = true`); `readonly property string windowRule` (`windowBlurLua()` com `Config.blurWindows` falso e Lua, senão `""`); `reapply()` também com `windowRule`; `onWindowRuleChanged`: não vazia → `evalLua`; vazia depois de ter sido não vazia → `Hypr.reloadConfig()`.

- [ ] **Step 1: Testes que falham** em `tests/themeswitcher.test.js`:

```js
t.test("themeswitcher: desempenho é desfoque com xray", () => {
    const r = S.blurLua("performance", true);
    t.check(r.includes('"^lucerna-panel-.*"') && r.includes("blur = true") && r.includes("xray = true") && r.includes("ignore_alpha = 0.45"));
    t.check(S.blurLua("full", true).includes("xray = false"), "completo sem xray");
    t.check(S.blurLua("off", true).includes("blur = false"), "desligado");
});
t.test("themeswitcher: sem transparência, sem desfoque", () => {
    t.check(S.blurLua("performance", false).includes("blur = false"));
});
t.test("themeswitcher: a config do desfoque garante vfr, otimizações e popups", () => {
    const c = S.blurConfigLua(12, 1);
    for (const part of ["size = 12", "passes = 1", "new_optimizations = true", "popups = false", "debug = { vfr = true }"])
        t.check(c.includes(part), part);
    t.check(!c.includes("misc"), "misc:vfr não existe no 0.56");
});
t.test("themeswitcher: janelas sem desfoque nunca desfazem regra do usuário", () => {
    t.check(S.windowBlurLua().includes("no_blur = true") && S.windowBlurLua().includes('class = ".*"'));
    t.check(!S.windowBlurLua().includes("no_blur = false"));
});
t.test("themeswitcher: o reload reenvia as regras do desfoque", () => {
    // Troque Hypr.evalLua por um coletor no caso (restaure no finally),
    // com Config.blurWindows = false, chame S.reapply() e confira que a lista
    // coletada contém blurRule, blurConfig e windowRule.
});
```

(O último caso: o implementador escreve o coletor; se `Hypr.evalLua` não puder ser trocado no runner, extraia `function rules(): var` — a lista que o `reapply()` envia — e teste ela.)

- [ ] **Step 2:** `dev/ci.sh unit` — esperado: FAIL.
- [ ] **Step 3: Implementar** as funções; `blurRule` = `Hypr.usingLua ? blurLua(ThemeManager.blur.mode, ThemeManager.transparency.enabled) : ""`; `blurConfig` = `blurConfigLua(ThemeManager.blur.size, ThemeManager.blur.passes)` (o `blurDelay` de 120 ms fica). Atualize o comentário do `blurLua` (xray: só o fundo, reaproveitado pelo Hyprland).
- [ ] **Step 4:** `dev/ci.sh unit` e `dev/ci.sh lint` — esperado: passam.
- [ ] **Step 5: Conferir no container** (`dev/test.sh`): `hyprctl getoption decoration:blur:passes` e `debug:vfr` refletem o enviado; `hyprctl layers` mostra as camadas; com `blur set full` e `performance` (IPC da Task 1) o painel superior aparece desfocado nos dois.
- [ ] **Step 6: Commit** — `git commit -m "Desfoque: xray no nível desempenho, vfr e otimizações garantidos, janelas opcionais"`

### Task 3: Temas com uma passada e size maior

**Files:**
- Modify: `dev/themes.py` (`"blurSize": 12`, `"blurPasses": 1`)
- Modify: `themes/*.json` (regenerados pelo `dev/themes.py`, nunca à mão)
- Modify: `tests/theme.test.js` (o caso "desfoque ajustado pelo usuário" passa a esperar `[12, 1]` e restaurar para 12)
- Modify: `README.md` só se citar números de desfoque

- [ ] **Step 1:** Ajuste o teste para `[12, 1]`; `dev/ci.sh unit` — esperado: FAIL.
- [ ] **Step 2:** Altere o `dev/themes.py`, regenere os 12 temas como o próprio script manda e rode `dev/ci.sh rules` (confere o gerado contra o versionado) e `dev/ci.sh unit` — esperado: passam.
- [ ] **Step 3: Comparação visual** no `lucerna-polish`: capturas do painel superior e do launcher sobre o papel de parede e sobre uma janela `kitty` com texto, com 6×2 (a `main`) e 12×1. Se 12×1 mostrar blocos ou granulado visível, troque para 8×2 e repita. Guarde as capturas no scratchpad para o PR.
- [ ] **Step 4: Commit** — `git commit -m "Temas: desfoque com uma passada e raio maior, a mesma aparência"`

### Task 4: Seletor "Desfoque" e "Desfocar as janelas" nas Configurações

**Files:**
- Modify: `features/settings/state/SettingsState.qml` (perto de `blur`/`setBlur`)
- Modify: `features/settings/ui/GlassPage.qml` (seção "Desfoque")
- Modify: `features/settings/ui/GlassPreview.qml` (se o construtor decidir simular o xray)
- Modify: `features/launcher/state/LauncherState.qml` (palavras-chave da ação "Configurações": `xray desempenho`)
- Modify: `README.md` (linha da tabela "Transparência e desfoque")

**Interfaces:**
- Consumes: `ThemeManager.blur.mode`, `ThemeManager.setBlurMode`, `Config.blurWindows`.
- Produces: `SettingsState.blurMode: string`, `SettingsState.blurModeOptions: var` (`[{ value: "off", label: "Desligado" }, { value: "performance", label: "Desempenho" }, { value: "full", label: "Completo" }]`, no formato do `animationOptions`), `function setBlurMode(mode: string): void`, `SettingsState.blurWindows: bool`, `function setBlurWindows(on: bool): void`.

- [ ] **Step 1:** Implementar o `SettingsState` e trocar o `Switch` "Desfocar o fundo" por um `SettingRow` `wide` com `SegmentedControl` (como "Animações" na `AppearancePage`), descrição que muda com o nível (Desempenho: "Desfoca só o papel de parede atrás dos painéis; mais leve com janelas se mexendo"; Completo: "Desfoca tudo o que está atrás, janelas incluídas"; Desligado: "Painéis translúcidos sem desfoque"). Depois, `SettingRow` "Desfocar as janelas" com `Switch` e a descrição "Janelas translúcidas; religar recarrega a config do Hyprland". "Intensidade" e "Suavidade" ficam, apagadas com o nível Desligado. Sem Lua (`blurAvailable` falso), tudo apagado como hoje.
- [ ] **Step 2:** `dev/ci.sh lint` e `dev/ci.sh unit` — esperado: passam.
- [ ] **Step 3: Conferir no container:** abrir Configurações → Transparência e desfoque (`dev/test.sh run 'qs -c lucerna ipc call panels open settings'`), capturar com cada nível escolhido pelo IPC `blur set`; o seletor acompanha o IPC.
- [ ] **Step 4: Commit** — `git commit -m "Configurações: o nível do desfoque e o desfoque das janelas"`

### Task 5: Papel de parede pausado sob as camadas desfocadas

**Files:**
- Modify: `features/wallpaper/state/WallpaperState.qml` (perto de `shouldAnimate`; imports `qs.core.panels` e `qs.core.frame`)
- Create: `tests/wallpaper.test.js`
- Modify: `tests/runner.qml` (`import qs.features.wallpaper.state`, `import "wallpaper.test.js" as WallpaperTest`, `["wallpaper", WallpaperTest]` em `suites`, getter `WallpaperState`)

**Interfaces:**
- Consumes: `Panels.surfaces` (janelas com `screen` e `visible`), `Frame.windows` (com `targetScreen` e `visible`), `ThemeManager.blur.enabled`, `ThemeManager.transparency.enabled`.
- Produces: `function blurCovers(screen: var, blurOn: bool, surfaces: var, windows: var): bool` (pura); `shouldAnimate(screen)` devolve `false` quando `blurCovers(screen, ThemeManager.transparency.enabled && ThemeManager.blur.enabled, Panels.surfaces, Frame.windows)`.

- [ ] **Step 1: Testes que falham** em `tests/wallpaper.test.js`:

```js
function run(t) {
    const W = t.WallpaperState;
    const a = { name: "A" }, b = { name: "B" };
    t.test("wallpaper: painel aberto pausa a tela dele", () => {
        t.eq(W.blurCovers(a, true, [{ screen: a, visible: true }], []), true);
    });
    t.test("wallpaper: a forma da moldura à mostra pausa", () => {
        t.eq(W.blurCovers(a, true, [], [{ targetScreen: a, visible: true }]), true);
    });
    t.test("wallpaper: pausa só a tela coberta", () => {
        t.eq(W.blurCovers(b, true, [{ screen: a, visible: true }], [{ targetScreen: a, visible: true }]), false);
    });
    t.test("wallpaper: janela escondida não pausa", () => {
        t.eq(W.blurCovers(a, true, [{ screen: a, visible: false }], [{ targetScreen: a, visible: false }]), false);
    });
    t.test("wallpaper: sem desfoque, não pausa", () => {
        t.eq(W.blurCovers(a, false, [{ screen: a, visible: true }], []), false);
    });
}
```

- [ ] **Step 2:** `dev/ci.sh unit` — esperado: FAIL (`blurCovers` não existe; a suíte nova aparece).
- [ ] **Step 3: Implementar** `blurCovers` e a chamada no `shouldAnimate`; comentário: pausar, não baixar o FPS, porque cada quadro do papel suja o fundo guardado do xray. Os popups de notificação não registram no `Panels`, então não pausam (confira; se registrarem, filtre).
- [ ] **Step 4:** `dev/ci.sh unit` e `dev/ci.sh lint` — esperado: passam.
- [ ] **Step 5: Conferir no container** com um tema de papel animado: abrir e fechar o painel superior e o launcher, revelar a barra; o efeito para e volta sem salto nem tela preta; com um papel em vídeo (se houver no container), o vídeo retoma de onde parou.
- [ ] **Step 6: Commit** — `git commit -m "Papel de parede: pausado enquanto um painel desfocado cobre a tela"`

### Task 6: Fumaça do IPC `blur`

**Files:**
- Modify: `ci/smoke.sh` (depois dos passos dos painéis)

- [ ] **Step 1:** Acrescentar: `ipc blur get` devolve `performance`; `ipc blur set full` e o `get` devolve `full`; `ipc blur set xray` não muda (`full`); `ipc blur set performance` volta; `alive` depois de cada um; uma captura com o painel superior aberto em cada nível (com o `shot` da casa). Linhas na tabela do resumo pelo `row`.
- [ ] **Step 2:** `dev/ci.sh smoke` — esperado: passa, com as linhas novas no resumo.
- [ ] **Step 3: Commit** — `git commit -m "Fumaça: o IPC do nível do desfoque"`

### Task 7: Medição (container e 144 Hz)

**Files:**
- Create: `dev/bench-blur.sh` (para o usuário, na sessão Hyprland dele)
- Create (fora do repo): `<scratchpad>/desfoque/bench-blur.py`, derivado de `/tmp/claude-1000/-home-eduardo8006-Documentos-projetos-lucerna-shell/bca4d024-af35-4f42-8c6a-2cb307b38bd9/scratchpad/moldura/fix-bench.py`
- Modify: `README.md` (uma linha em "Desenvolvimento" sobre o `dev/bench-blur.sh`)

- [ ] **Step 1: `dev/bench-blur.sh [segundos]`** (padrão 20): exige `HYPRLAND_INSTANCE_SIGNATURE` e o `qs -c lucerna` vivo; guarda `blur get`; para `full`, `performance` e `off`: `blur set`, `panels open dashboard`, espera 2 s, amostra por N segundos o uso de CPU do `Hyprland` e do `qs` (de `/proc/<pid>/stat`) e da GPU se houver (`intel_gpu_top -J -s 1000`, `nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits` ou `/sys/class/drm/card*/device/gpu_busy_percent`), `panels close`; imprime a tabela; `trap` devolve o nível guardado e fecha o painel mesmo com Ctrl+C. Não chama `hyprctl keyword`/`eval`. Passa no `shellcheck` do lint.
- [ ] **Step 2:** `dev/ci.sh lint` e `dev/ci.sh rules` — esperado: passam.
- [ ] **Step 3: Bench no container:** o script do scratchpad amostra também o PID do Hyprland do `lucerna-polish` (`docker top`) e roda as fases do spec (painel superior parado, central parada, launcher aberto, dez aberturas, barra revelada), cada uma com papel animado e com um `kitty` escrevendo a hora a cada 16 ms atrás, para `lucernamain` (a `main` copiada no container, como no `fix-bench.py`) e para a branch em `full`, `performance` e `off`. Esperado: Desempenho abaixo do Completo com a janela mudando; com o papel animado, os dois perto do Desligado; nenhuma fase pior que a `main`. Se não, pare e reporte antes de seguir.
- [ ] **Step 4: Commit** — `git commit -m "Medição: o dev/bench-blur.sh para comparar os níveis do desfoque"`

### Task 8: Verificação final

- [ ] **Step 1:** `dev/ci.sh` inteiro (lint, rules, unit, smoke) — esperado: tudo passa.
- [ ] **Step 2:** Rascunho do texto do PR no scratchpad: o que muda, as tabelas da Task 7, as capturas das Tasks 3 a 5 e o comando `dev/bench-blur.sh 20` para o usuário rodar a 144 Hz. Não empurrar nem abrir o PR sem a confirmação do usuário.
