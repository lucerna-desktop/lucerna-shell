# Cores sobre o destaque e barras — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** tirar o texto escuro de cima do destaque cheio (tom de contêiner nas superfícies grandes) e unificar as barras de porcentagem na opção B.

**Architecture:** tokens derivados do destaque no `ThemeManager` (funções puras testáveis, sobrescrita opcional pelo JSON do tema), aplicados pela regra grande/pequeno do spec; um componente de barra único em `core/widgets/` substitui `PillSlider` e `Slider`.

**Tech Stack:** Quickshell/QML (Qt 6), testes JS em `tests/*.test.js` pelo `tests/runner.qml`, `ci/run.sh`.

**Spec:** `docs/superpowers/specs/2026-11-06-cores-barras-design.md` (leia antes; a lista de arquivos e a regra estão lá).

## Global Constraints

- Contraste texto/fundo ≥ 4.5:1 em todos os 12 temas (`themes/*.json`, 2 claros: `catppuccin-latte`, `rose-pine-dawn`); ícone/preenchimento ≥ 3:1.
- Indicadores pequenos sem texto continuam em `accent` cheio (lista no spec).
- Medidas sempre por `ThemeManager.px()`; animações pelo `Anim` existente.
- Comentários e textos em português, no tom dos arquivos vizinhos.
- `ci/run.sh lint`, `rules`, `unit` (cobertura 100% das funções de `core/` fora de `core/widgets/`) e `smoke` passando ao fim de cada tarefa.
- Commits pequenos, mensagem em português no padrão do `git log` ("Cores: ...", "Barras: ...").

## Review Focus

1. Tema com sobrescrita parcial no JSON (só `accentContainer`, sem `onAccentContainer`): o texto ainda tem de passar de 4.5:1 → teste na Tarefa 1.
2. Destaque muito claro ou quase cinza (`matte-black`, `#d0d0d0`): o contêiner não pode virar um cinza indistinguível do `raised` → teste na Tarefa 1 (contêiner ≠ `raised` com contraste mínimo de 1.2 entre eles).
3. Troca de tema em tempo real: os tokens novos animam com os outros (`Behavior`) e os componentes não guardam cor antiga → conferido nas capturas da Tarefa 4 (trocar de tema com a central aberta).
4. Barra no valor 0 e 1, e `from`/`to` diferentes de 0–1 (brilho por monitor, Configurações em ms): preenchimento e ícone não somem nem vazam → Tarefa 3, fumaça e capturas.
5. Mudo com valor alto: o preenchimento cinza ainda mostra o nível, e o ícone em `danger` tem contraste com o trilho e com o preenchimento → Tarefa 1 (contraste `danger` × `track`) e capturas.

---

### Task 1: Tokens derivados do destaque

**Files:**
- Modify: `core/theme/ThemeManager.qml` (`ColorTokens`, preenchimento de `colors`, funções perto de `onColor`)
- Test: `tests/theme.test.js`

**Interfaces:**
- Produces:
  - `ThemeManager.colors.accentContainer: color`, `colors.onAccentContainer: color`, `colors.accentFill: color` (com `Behavior on ...` como os outros).
  - `ThemeManager.mix(a: color, b: color, t: real): color` — `t` = peso de `b` (0 → `a`).
  - `ThemeManager.containerOf(c: color, base: color, text: color, dark: bool): color` e `ThemeManager.onContainerOf(bg: color, text: color, base: color): color` — puras, para testar com os 12 temas sem trocar o tema ativo.
  - `ThemeManager.container(c: color): color` e `ThemeManager.onContainer(c: color): color` — atalhos com o tema ativo, para `danger`/`success`/`warning`.
  - `ThemeManager.fillOf(accent: color, surface: color, track: color): color`.
  - JSON: `colors.accentContainer`, `colors.onAccentContainer`, `colors.accentFill` opcionais (como `track`).

- [ ] **Step 1: Testes que falham** em `tests/theme.test.js`:
  - `"theme: contêiner do destaque em todos os temas"`: para cada um dos 12 temas (iterar como `tests/themeswitcher.test.js` lista os temas; se o runner não lê arquivos, embutir a tabela `accent/base/surface/raised/text/danger/success/warning/track` dos 12 JSONs no teste), com `c = containerOf(accent, base, text, dark)` e `on = onContainerOf(c, text, base)`: `contrast(on, c) >= 4.5`; `contrast(c, raised) >= 1.2`; nos escuros `luminance(c) < luminance(accent)`, nos claros `luminance(c) > luminance(accent)`. O mesmo para `danger`, `success`, `warning`.
  - `"theme: preenchimento das barras"`: para cada tema, `contrast(fillOf(accent, surface, track), track) >= 3` e `contrast(danger, track) >= 3`.
  - `"theme: tokens do contêiner do tema padrão"`: `T.colors.accentContainer`, `onAccentContainer`, `accentFill` iguais aos de `containerOf/onContainerOf/fillOf` com os valores do mocha.
  - `"theme: sobrescrita pelo JSON"`: com `colors.accentContainer` dado e `onAccentContainer` ausente, o contêiner é o do JSON e o texto é calculado e passa 4.5:1 (exercitar pela função que monta os tokens a partir de `data`, isolada para teste se preciso).
  - `mix` nos extremos: `mix(a, b, 0) == a`, `mix(a, b, 1) == b`.
- [ ] **Step 2:** `ci/run.sh unit` → falha (funções não existem).
- [ ] **Step 3: Implementar.** `containerOf`: misturar `c` ao `base` (escuro: pouco destaque, faixa do tom 30 do M3; claro: faixa do tom 90) e, se `contrast(text, resultado) < 4.5`, empurrar em direção ao `base` em passos até passar. `onContainerOf`: `text` se passa de 4.5, senão o melhor entre `text`/`base`/preto/branco. `fillOf`: `accent` levemente misturado ao `surface`, voltando ao `accent` se cair abaixo de 3:1 com o `track`. Proporções finais pelos testes e pelas capturas da Tarefa 4.
- [ ] **Step 4:** `ci/run.sh unit` → `RESULT passed=N failed=0`, cobertura 100%.
- [ ] **Step 5: Commit** `Cores: o tom de contêiner e o preenchimento derivados do destaque`.

### Task 2: A regra nas superfícies grandes

**Files (conferir caminhos com `grep`; lista e regra no spec, seção "Onde aplicar"):**
- Modify: `core/widgets/Clickable.qml`, `core/widgets/IconButton.qml`, `features/central/ui/Tile.qml`, `ToggleButton.qml`, `DetailsPanel.qml`, `WeatherPage.qml`, `CaptureToolbar.qml`, `MediaPage.qml`, `GridLauncher.qml`, `Settings.qml`, `ListRow.qml`, `AppearancePage.qml`, `CaptureOverlay.qml`, `Actions.qml` (gravação), `Calendar.qml`, `BatteryPage.qml`, `ClockButton.qml`.

**Interfaces:**
- Consumes: Tarefa 1 (`colors.accentContainer`, `colors.onAccentContainer`, `container()`, `onContainer()`).

- [ ] **Step 1:** Grandes com texto → fundo `accentContainer`, texto `onAccentContainer`, ícone `accent`; subtítulos com `onAccentContainer` a ≥ 0.75 de opacidade só se mantiverem 4.5:1 (senão `onAccentContainer` cheio). Hover/pressionado: `mix` do contêiner com o texto (poucos %), nunca `accent` cheio.
- [ ] **Step 2:** Gravação → `container(danger)`/`onContainer(danger)`, ícone em `danger`; bateria → `container(estado)`/`onContainer(estado)`; véu do `ClockButton` → texto `text`.
- [ ] **Step 3:** `grep -rn "accentText\|onColor(" --include='*.qml' .` e decidir cada ocorrência que sobrar pela regra (indicador pequeno fica; o resto muda). Registrar as que ficaram e por quê no relatório.
- [ ] **Step 4:** `ci/run.sh lint && ci/run.sh rules && ci/run.sh unit && ci/run.sh smoke` passam.
- [ ] **Step 5: Commit(s)** por grupo (`Cores: os blocos da central no tom de contêiner`, `Cores: botões e itens selecionados ...` etc.).

### Task 3: A barra única (opção B)

**Files:**
- Create: `core/widgets/LevelSlider.qml`
- Delete: `features/central/ui/PillSlider.qml`, `core/widgets/Slider.qml`
- Modify: usos (`grep -rn "PillSlider\|Slider {" --include='*.qml' .`): `features/central/ui/ActionsPanel.qml`, `InputPage.qml`, `LevelRow.qml`, as páginas de Configurações (Notifications, Power, Glass, Mouse, Idle, NightLight, Keyboard e outras que aparecerem); `core/widgets/LinearGauge.qml`; `ci/smoke.sh` se ele procura os componentes antigos.

**Interfaces:**
- Consumes: Tarefa 1 (`colors.accentFill`, `colors.track`).
- Produces: `LevelSlider { property real from: 0; property real to: 1; property real value; property real stepSize: 0; property var format: v => \`${Math.round(v * 100)}%\`; property string label: ""; property bool showValue: true; property string icon: ""; property bool iconClickable: false; property bool muted: false; signal moved(real value); signal iconClicked() }` (use os nomes exatos de sinal que `PillSlider` já usa para o ícone, se existirem, para não reescrever quem chama).

- [ ] **Step 1:** Implementar pelo spec ("A barra de porcentagem (opção B)"): linha de cima com `label` à esquerda e `format(value)` à direita (`text`/`textMuted`, escondida se ambos vazios); barra de `px(20)` que cresce `px(3)` com hover/arraste (animado); trilho `track`, preenchimento `accentFill`, ícone dentro à esquerda; mudo/`!enabled`: preenchimento `textFaint`, ícone `danger`, sem `opacity` no conjunto. Herdar de `Slider`/`PillSlider` o comportamento de teclado, arraste, clique, `snap` e animação quando não arrasta.
- [ ] **Step 2:** Migrar todos os usos. `LevelRow` perde o `opacity` de mudo e passa `muted`; Configurações que já têm rótulo na linha usam `label: ""`.
- [ ] **Step 3:** `LinearGauge`: preenchimento `accentFill`, mesmo arredondamento total.
- [ ] **Step 4:** `ci/run.sh lint && ci/run.sh rules && ci/run.sh unit && ci/run.sh smoke` passam; `grep -rn "PillSlider\|\bSlider {" --include='*.qml' .` vazio.
- [ ] **Step 5: Commit(s)** `Barras: a barra única com nome e valor fora`, `Barras: a central, o volume por app e as Configurações na barra nova`.

### Task 4: Conferência visual e Pendências

**Files:**
- Modify: `Lucerna — Pendências.md`
- Capturas: `docs/screenshots/cores-barras/` (só as finais, uma por tema, compactadas como as existentes) ; o resto no scratchpad.

- [ ] **Step 1:** Pelo `dev/test.sh` (comando `shot`), nos 12 temas: central com blocos ligados/desligados e volume mudo, volume por app, uma página de Configurações com barra, lançador com item selecionado, calendário, pílula de gravação se der; e uma troca de tema com a central aberta. Antes/depois do `main` para comparar.
- [ ] **Step 2:** Ajustar as proporções da Tarefa 1 se algum tema ficar ruim (contêiner sem cara de destaque, barra apagada), com os testes ainda passando.
- [ ] **Step 3:** Pendências: marcar "Cores dos blocos ativos" (corrigir "13 temas" → 12), descrever o feito no padrão do arquivo e registrar sobras.
- [ ] **Step 4: Commit** `Pendências: as cores e as barras`.
