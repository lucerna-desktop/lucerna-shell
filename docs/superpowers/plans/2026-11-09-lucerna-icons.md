# lucerna-icons — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** criar o pacote de ícones próprio do Lucerna (contorno + preenchido, 4 pesos, a partir do Lucide), aprovar os ícones com o usuário em lotes e migrar o shell do Material Symbols para ele.

**Architecture:** SVGs aprovados em `lucerna-icons` são a fonte da verdade; um build em Python gera a fonte "Lucerna Icons" (ligaduras `<nome>` / `<nome>-fill`, 4 pesos) publicada como release; uma galeria HTML estática mostra cada lote ao usuário. O shell consome a release, ganha tokens de tamanho e o peso automático, e o `Icon.qml` passa a duas camadas.

**Tech Stack:** Python 3 (`picosvg` para traço → contorno, `fontTools` FontBuilder + feaLib para a fonte e as ligaduras, `pytest`), HTML/CSS/JS estático para a galeria, GitHub Actions; no shell, Quickshell/QML e os testes de `ci/run.sh`.

**Spec:** `docs/superpowers/specs/2026-11-09-lucerna-icons-design.md` (leia antes de cada tarefa).

**Começa depois do merge de `feat/cores-barras`** (o contêiner de cor da galeria e do shell vem de lá).

## Global Constraints

- Repositório `lucerna-desktop/lucerna-icons` (público, main só por PR com merge commit), clone em `/home/eduardo8006/Documentos/projetos/lucerna-icons`; o shell em `/home/eduardo8006/Documentos/projetos/lucerna-shell`. Remote pelo alias SSH `github-pessoal`; `gh` na conta `EduardoSA8006`.
- Licença: `LICENSE` MIT + `LICENSE-LUCIDE` intacto; todo SVG derivado tem `origin: "lucide:<nome>"` no manifesto.
- Grade 24×24, `viewBox="0 0 24 24"`, `stroke="currentColor"`/`fill="currentColor"` (sem cor fixa), pontas e junções redondas.
- Pesos (traço → `usWeightClass`): **1 → 200, 1,5 → 300, 2 → 400, 2,5 → 600**. Família "Lucerna Icons", um TTF por peso: `LucernaIcons-ExtraLight/Light/Regular/SemiBold.ttf`.
- Peso automático pelo tamanho: **≤16 px → 2,5; 17–24 → 2; 25–40 → 1,5; >40 → 1**; ênfase (`weight: 600`) sobe um degrau (máximo 2,5).
- Tokens de tamanho: **xs 14, sm 16, md 20, lg 24, xl 32, empty 40, display 64**.
- Sem área para preencher → `"filled": "outline"` (a ligadura `-fill` aponta para o contorno).
- Lucide fixado numa versão (tag) registrada no manifesto (`lucideVersion`).
- Nenhum ícone vira `"aprovado"` sem o usuário ver na galeria.
- Comentários, README, mensagens de commit e textos em português.

## Review Focus

1. Nome com hífen e dígito na ligadura (`battery-3`, `wifi-2-fill`): a ligadura mais longa tem de vencer a mais curta (`wifi-2-fill` não pode virar `wifi-2` + "-fill") → teste na Tarefa 1.
2. Preenchido que mistura área cheia e traço interno (sino com badalo, pasta com aba): o traço interno precisa ficar recortado/visível depois da conversão → fixture na Tarefa 1 e conferência na galeria.
3. Ícone no tamanho 14 com traço 2,5: detalhes se fundindo → a galeria mostra 14 px em todos os lotes (Tarefa 3).
4. Troca de tema/escala com ícone animando o preenchimento: sem piscar nem ficar a meio caminho → Tarefa 5 (fumaça e captura).
5. Nome de `Icons.qml` sem ícone aprovado no manifesto (inclusive as listas de estados): o shell mostraria um quadrado vazio → teste na Tarefa 6.

---

## Parte A — o repositório lucerna-icons (branch `feat/base`, um PR ao fim da Tarefa 3)

### Task 1: Build da fonte e validação

**Files:**
- Create: `tools/lucerna_icons/{manifest.py,svgcheck.py,build.py,__main__.py}`, `tests/test_manifest.py`, `tests/test_build.py`, `tests/fixtures/` (3–4 SVGs de teste: um só de traço, um preenchido com traço interno, um de nome com hífen e dígito), `Makefile`, `requirements.txt`, `.github/workflows/ci.yml`
- Modify: `manifest.json` (esquema), `README.md` (comandos reais), `lucerna-icons — Pendências.md`

**Interfaces:**
- Produces:
  - Esquema do manifesto: `{"lucideVersion": "<tag>", "icons": [{"name", "origin", "material": [<ligaduras do Material>], "filled": "own"|"outline", "family": "<nome da família>"|null, "status": "pendente"|"aprovado"}]}`.
  - `python -m lucerna_icons check` (valida manifesto + SVGs; sai ≠ 0 com a lista de erros), `python -m lucerna_icons build [--all] --out dist/` (só aprovados; `--all` inclui pendentes, para a galeria).
  - `make check`, `make build`, `make install PREFIX=/usr` (TTFs em `$(PREFIX)/share/fonts/lucerna-icons/`, SVGs aprovados em `$(PREFIX)/share/lucerna-icons/svg/{outline,filled}/`, `manifest.json` em `$(PREFIX)/share/lucerna-icons/`).

- [ ] **Step 1: Testes que falham.** `test_manifest.py`: nome duplicado, `origin` inválido, falta `svg/outline/<nome>.svg`, falta o preenchido com `filled: "own"`, SVG com cor fixa ou viewBox ≠ 24 → cada um gera erro nomeado. `test_build.py` (sobre as fixtures): gera 4 TTFs com `usWeightClass` 200/300/400/600 e família "Lucerna Icons"; para cada ícone, shaping (fontTools `hb-shape` via `uharfbuzz`, ou o próprio GSUB lido) de `<nome>` e `<nome>-fill` resulta em **um** glifo; `wifi-2-fill` não é `wifi-2` + resto; o glifo do traço 2,5 tem área maior que o do 1; `filled: "outline"` → `-fill` e `<nome>` dão o mesmo glifo; o preenchido com traço interno tem um contorno interno (furo) no glifo.
- [ ] **Step 2:** `make check-tests` (pytest) → falha.
- [ ] **Step 3: Implementar.** Para cada peso: reescrever `stroke-width` do SVG, `picosvg` para contornos, glifo a partir do caminho (TTGlyphPen, unitsPerEm 1200 = 24×50), cmap para `a–z 0–9 -` (glifos vazios de largura 0) e GSUB `liga` gerado (feaLib), em ordem de comprimento decrescente.
- [ ] **Step 4:** `make check-tests` passa; `make check` passa com o manifesto vazio.
- [ ] **Step 5: CI** (`ci.yml`): em PR e na main, `make check` + testes + `make build --all`; em tag `v*`, `make build` e anexar os 4 TTFs + `manifest.json` + um `.tar.gz` dos SVGs à release. Depois do primeiro verde, acrescentar `check`/`build` como status obrigatórios no ruleset `main` (como `lint/rules/unit/smoke` no shell).
- [ ] **Step 6: Commit** `Build: a fonte gerada dos SVGs, a validação e o CI`.

### Task 2: Inventário e busca no Lucide

**Files:**
- Create: `tools/lucerna_icons/fetch.py`, `tests/test_fetch.py`, `inventario.md`
- Modify: `manifest.json`

**Interfaces:**
- Consumes: esquema da Tarefa 1.
- Produces: `python -m lucerna_icons fetch <lucide-name> [--as <nome>]` (baixa `icons/<nome>.svg` da tag `lucideVersion` do repositório do Lucide para `svg/outline/`, normaliza atributos, cria a entrada `pendente` com `origin`); `manifest.json` com **todos** os ícones que o shell usa.

- [ ] **Step 1:** Teste do `fetch` com um servidor/arquivo local falso (sem rede no teste): normaliza atributos, não sobrescreve um SVG aprovado, registra `origin`.
- [ ] **Step 2:** Implementar o `fetch`; fixar `lucideVersion` na tag estável mais recente.
- [ ] **Step 3: Inventário.** Ler `core/widgets/Icons.qml` do shell (131 nomes; listas de estados como `wifi`, bateria, volume) e montar `inventario.md`: para cada ligadura do Material, o nome Lucerna, o ícone Lucide correspondente (ou "desenhar"), `filled` (`own`/`outline`, pela regra do spec: tem área para preencher?) e a família. Estados que o Material tem a mais que o Lucide entram como "desenhar" na família (ex.: bateria com 8 níveis).
- [ ] **Step 4:** `fetch` de todos os que existem no Lucide; entradas `pendente` para os "desenhar" (sem SVG ainda; o `check` aceita `pendente` sem SVG, e o `build` normal ignora pendentes).
- [ ] **Step 5:** `make check` passa. **Commit** `Inventário: os ícones do shell e os do Lucide`.

### Task 3: Galeria de revisão

**Files:**
- Create: `tools/gallery/{template.html,gallery.css,gallery.js}`, `tools/lucerna_icons/gallery.py`, `tools/gallery/temas.json` (retrato de catppuccin-mocha e catppuccin-latte do shell, com `accentContainer`/`onAccentContainer`/`accentIcon` já calculados pela `feat/cores-barras`), `tests/test_gallery.py`

**Interfaces:**
- Produces: `python -m lucerna_icons gallery <nome>... --out <dir>` (ou `--lote <n>` lendo `lotes.json`) → `index.html` autocontido (fontes em `@font-face` relativo aos TTFs de `build --all`).

- [ ] **Step 1:** Teste: a página gerada contém, para cada ícone pedido, as células esperadas (ids previsíveis) e falha com nome inexistente.
- [ ] **Step 2:** Implementar. Por ícone (e por estado da família): original do Lucide (quando derivado), contorno e preenchido nos 4 pesos; tamanhos **14, 16, 20, 24, 32, 40, 64** com o peso automático; temas escuro e claro; um bloco ativo (contêiner + `accentIcon`) e um inativo; botão que anima o preenchimento (transição de opacidade e escala, a curva da Tarefa 5); o Material Symbols ao lado (fonte local do sistema, `local("Material Symbols Rounded")`, com `FILL` 0/1). Status e origem visíveis.
- [ ] **Step 3:** Abrir `tools/gallery` com 2–3 ícones de teste e conferir no navegador (captura no relatório).
- [ ] **Step 4: Commit** `Galeria: a página de revisão dos lotes`; abrir o PR `feat/base` → main e mergear depois do CI verde (o usuário já aprovou este plano; o merge é por PR, como no padrão da org).

## Parte B — os lotes com o usuário

### Task 4: Revisão em lotes (repete até o inventário inteiro estar aprovado)

Esta tarefa é conduzida pelo **controlador com o usuário**, não por um implementador sozinho.

**Files:** `svg/outline/*`, `svg/filled/*`, `manifest.json`, `lotes.json` (registro: lote, ícones, data, decisão), branch `lote/<n>` por lote, PR por lote.

- [ ] **Step 1:** Montar `lotes.json` na ordem do spec (bateria, Wi-Fi, volume, Bluetooth, blocos da central, barra, resto), 10–15 ícones por lote, famílias inteiras no mesmo lote.
- [ ] **Step 2 (por lote):** um subagente desenha os preenchidos (`own`), os estados que faltam e os "desenhar", na linguagem do Lucide; `make check`; gera a galeria do lote.
- [ ] **Step 3 (por lote):** o controlador mostra a galeria ao usuário (abrir no navegador e/ou capturas) e registra a resposta. Aprovados → `"aprovado"`; os separados voltam ajustados no lote seguinte.
- [ ] **Step 4 (por lote):** PR `lote/<n>` com os aprovados, merge após CI verde.
- [ ] **Step 5 (fim):** com o inventário todo aprovado, tag `v0.1.0` (release com os TTFs pelo CI) e atualizar o README/Pendências.

## Parte C — a migração do shell (branch `feat/lucerna-icons` no shell)

### Task 5: Tamanhos, peso automático e o Icon em duas camadas

**Files:**
- Modify: `core/theme/ThemeManager.qml` (token `icon` com xs…display escalados por `px()`, e `iconWeight(size: real, emphasis: bool): int`), `core/widgets/Icon.qml`, `tests/theme.test.js`
- Modify: `dev/Dockerfile` e `ci/packages/*.txt`/scripts do CI: instalar a release `v0.1.0` do lucerna-icons (baixar os TTFs e o `manifest.json` da release fixada) no lugar de `ttf-material-symbols-variable`

**Interfaces:**
- Produces: `ThemeManager.icon.{xs,sm,md,lg,xl,empty,display}: int`; `ThemeManager.iconWeight(size, emphasis)` → `Font.ExtraLight|Light|Normal|DemiBold` pela tabela das Global Constraints; `Icon` com a mesma API (`icon`, `size`, `filled`, `fill`, `weight` — `weight >= 600` = ênfase).

- [ ] **Step 1:** Testes: `T.icon.md == 20` na escala 1 e escala com `shellScale`; `iconWeight` nos limites 16/17/24/25/40/41 e com ênfase (16 + ênfase continua 2,5).
- [ ] **Step 2:** Implementar os tokens e `iconWeight`; `Icon.qml` com duas `Text` sobrepostas (`icon` e `icon + "-fill"`), opacidade/escala pelo `fill` com o `Anim` existente, `font.weight` por `iconWeight`; tirar `variableAxes`.
- [ ] **Step 3:** `dev/ci.sh lint rules unit smoke` passam.
- [ ] **Step 4: Commit** `Ícones: os tamanhos do tema, o peso pelo tamanho e o Icon em duas camadas`.

### Task 6: Os nomes, os tamanhos nos usos e a saída do Material

**Files:**
- Modify: `core/widgets/Icons.qml`, todos os usos de `Icon`/`IconButton` com `size`/`iconSize` (`grep -rn "Icon {\|IconButton {\|iconSize" --include='*.qml' .`), `themes/*.json` (`font.icon: "Lucerna Icons"`), página de créditos e `tests/credits.test.js`, `README.md`, `Lucerna — Pendências.md`
- Create: `tests/icons.test.js` (todo nome em `Icons.qml`, inclusive dentro de listas, existe como `aprovado` no `manifest.json` instalado em `/usr/share/lucerna-icons/manifest.json`)

- [ ] **Step 1:** Teste `icons.test.js` → falha com os nomes do Material.
- [ ] **Step 2:** `Icons.qml` com os nomes Lucerna; todo `size: px(N)` de ícone vira o token pela tabela do spec (13/14/16 → xs ou sm conforme a função; 18/20 → md; 22/24 → lg; 26–32 → xl; 36/40 → empty; 52–76 → display); `font.icon` nos 12 temas; créditos (lucerna-icons + Lucide/Feather) e README.
- [ ] **Step 3: As duas decisões em aberto.** Capturas pelo `dev/test.sh` da barra com `md` (20) e com um token `bar: 18`, e do clima/mídia com `display` (64) e com 72; o controlador leva ao usuário e aplica a escolha.
- [ ] **Step 4:** Capturas antes/depois (barra, central, Configurações, lançador, notificações, mídia, clima, bloqueio) num tema escuro e no catppuccin-latte; `dev/ci.sh lint rules unit smoke` passam; `grep -rn "Material Symbols" .` só em histórico (specs/planos antigos).
- [ ] **Step 5:** Pendências do shell (item marcado, sobras) e a correção pendente no lucerna-files: PR lá trocando "Material Symbols" por "lucerna-icons" no spec do explorador e registrando nas Pendências dele.
- [ ] **Step 6: Commit(s)** `Ícones: o shell no lucerna-icons`, `Pendências: o lucerna-icons`.
