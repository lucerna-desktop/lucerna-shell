# Cores sobre o destaque e barras de porcentagem — design

Data: 2026-11-06. Branch: `feat/cores-barras`. Item do Marco 1 nas Pendências ("Cores dos blocos ativos").

## Por quê

O usuário acha estranho o texto escuro (`accentText`) sobre o fundo cheio na cor de destaque (`accent`), e isso aparece em quase todos os temas: blocos ligados da central, botões primários, chips e itens selecionados, dia de hoje no calendário, sliders. O Volume desativado fica cinza sobre azul, quase ilegível, porque "desativado" hoje é só opacidade. As barras de porcentagem (pílula de 40 px, cheia no destaque, texto dentro) parecem exageradas.

## Objetivos

1. **Superfícies grandes com texto sobre o destaque** passam a usar um **tom de contêiner** (o "primary container" do Material 3), calculado a partir do destaque de cada tema: nos temas escuros, um tom escuro do destaque com texto claro; nos claros, um tom claro tingido com texto escuro. O ícone fica na cor de destaque.
2. **Uma barra de porcentagem só, em todo o sistema** (central, volume por app, Configurações), na opção B escolhida pelo usuário.
3. **Desativado/mudo legível**, sem depender de opacidade sobre o texto.

## Fora do escopo

- O modelo de cores ampliado do item 17 (temas por papel de parede). Este trabalho segue o molde dele (tokens derivados do destaque, com sobrescrita opcional no JSON do tema), e ele depois o absorve.
- A barra rebalanceada, a visão geral e o papel de parede por área, que vêm na fila depois.

## Anti-objetivos

- Trocar o problema de lugar: nenhum texto pode ficar com contraste abaixo de 4.5:1 (WCAG AA) com o seu fundo, em nenhum dos 12 temas.
- Apagar a identidade de cada tema: o contêiner precisa continuar com cara de destaque daquele tema, não um cinza.
- Mexer nos indicadores pequenos que hoje funcionam bem (ver a regra abaixo).

## Tokens novos (ThemeManager)

Em `ColorTokens`, com `Behavior` de cor como os outros:

- `accentContainer`: o fundo das superfícies grandes ativas. Escuro: o destaque misturado ao `base`, na faixa do tom 30 do M3 (escuro, mas reconhecivelmente da cor do destaque). Claro: o destaque misturado ao `base`, na faixa do tom 90.
- `onAccentContainer`: o texto sobre o contêiner. Parte de `text` (claro nos escuros, escuro nos claros) e garante ≥ 4.5:1; se não der, escurece/clareia o contêiner até dar.
- `accentFill`: o preenchimento das barras, "um pouco mais suave que o destaque puro" (o destaque levemente misturado ao `surface`), mantendo ≥ 3:1 com o `track` para a barra se ler.
- Uma função `container(c)` / `onContainer(c)` para fazer o mesmo com as cores de estado (`danger`, `success`, `warning`): pílula de gravação, cartão da bateria.
- Os três tokens podem vir do JSON do tema (`colors.accentContainer` etc.), como o `track` já faz; sem eles, calculados. A proporção exata da mistura fica com o implementador, validada pelas capturas e pelos testes de contraste.

`accentText` continua existindo para os indicadores pequenos com accent cheio (ver regra).

## A regra

- **Grande, com texto ou ícone por cima** → `accentContainer` + `onAccentContainer`, ícone em `accent`. Hover/pressionado escurecem ou clareiam o contêiner, nunca voltam ao accent cheio.
- **Pequeno, só indicador, sem texto** → continua `accent` cheio: ponto do workspace ativo, alça do `Switch`, sublinhado da aba, alças da captura, barra de tempo da notificação, blobs decorativos, gauges.
- **Véus translúcidos do destaque com texto por cima** (ex.: `ClockButton.qml:16`, accent a 0.16 com `accentText`) → texto em `text`, não `accentText`.

## Onde aplicar (auditoria de 2026-11-06)

Grandes, para o contêiner:

1. Base: `core/widgets/Clickable.qml` (`active`) e `core/widgets/IconButton.qml`. Isso cobre a barra (`Actions.qml`, `ClockButton.qml`), `ClipboardItem.qml`, `OverviewPage.qml`, `MediaCard.qml`.
2. Botões primários: `DetailsPanel.qml`, `WeatherPage.qml`, `CaptureToolbar.qml`, `MediaPage.qml` (tocar/pausar).
3. Central: `features/central/ui/Tile.qml` (fundo, texto, subtítulo, chevron), `ToggleButton.qml`.
4. Chips e itens selecionados: `GridLauncher.qml`, `Settings.qml` (menu lateral), `ListRow.qml`, `AppearancePage.qml`.
5. Pílula do tamanho da captura: `CaptureOverlay.qml`.
6. Pílula de gravação (`Actions.qml`, hoje `accentText` sobre `danger`) → `container(danger)`.
7. Dia de hoje no `Calendar.qml`.
8. Cartão de bateria (`BatteryPage.qml`, hoje `onColor()` sobre o estado cheio) → `container(estado)`.
9. Véu do `ClockButton.qml` → texto `text`.

O implementador confere os caminhos e procura outros usos de `accentText`/`onColor()` sobre fundo cheio que a auditoria tenha deixado passar, aplicando a mesma regra.

## A barra de porcentagem (opção B)

Um componente só em `core/widgets/` (substitui `features/central/ui/PillSlider.qml` e o `core/widgets/Slider.qml`; quem usa os dois passa a usar o novo):

- **Nome e valor fora da barra**, numa linha acima: nome à esquerda, valor à direita, texto normal (`text`/`textMuted`) sobre o fundo do painel. O nome é opcional (nas Configurações o rótulo da linha já existe; aí só o valor, ou nada, conforme a página).
- **Barra média de ~20 px**, totalmente arredondada, trilho em `track`, preenchimento em `accentFill`. **Ícone opcional dentro da barra**, à esquerda, sobre o preenchimento, com contraste ≥ 3:1 (ícone, não texto).
- **Cresce 2–3 px** ao passar o mouse e ao arrastar, com animação.
- Sem alça e sem balão: o valor já está à vista na linha de cima.
- **Mudo/desativado:** preenchimento cinza (`textFaint` ou equivalente com contraste com o trilho) e ícone em `danger`; nome e valor continuam legíveis (sem opacidade sobre o texto). Ícone clicável para mudo, quando a página pedir (como o `iconClickable` atual).
- Mantém o que os dois atuais já fazem: `from`/`to`/`value`/`stepSize`, sinal `moved`, controlado por quem usa, teclado (setas, foco por Tab), arrastar e clicar, animação do valor quando não está arrastando, função de formato do valor.
- Escala pelo `ThemeManager.px()` como o resto.

Usos: central (volume, brilho, `InputPage.qml`), volume por app (`LevelRow.qml`, que perde o `opacity` de mudo e passa a usar o estado mudo da barra), todas as páginas de Configurações que usam `Slider`.

`core/widgets/LinearGauge.qml` (só medidor) não vira slider, mas usa `accentFill` e o mesmo arredondamento, para o sistema ler como uma coisa só.

## Testes e verificação

- Unitários (`tests/*.test.js`, `ci/run.sh unit`, cobertura de 100% das funções no escopo): o cálculo de `accentContainer`, `onAccentContainer`, `accentFill`, `container()` e `onContainer()`; **para cada um dos 12 temas**, contraste ≥ 4.5 entre o texto e o contêiner (accent e as três cores de estado) e ≥ 3 entre `accentFill` e `track`; sobrescrita pelo JSON. A lógica do novo slider (snap, fração, teclado) testada como os atuais.
- `ci/run.sh lint`, `rules`, `smoke` passando.
- **Capturas nos 12 temas** (os 2 claros e os 10 escuros) pelo `dev/test.sh` (comando `shot`): central com blocos ligados e desligados, volume mudo, volume por app, uma página de Configurações com slider, lançador com item selecionado, calendário. Comparar com as de antes.

## Pendências

Ao concluir: marcar o item "Cores dos blocos ativos" (e corrigir "13 temas" para 12), registrar sobras na seção do trabalho, conforme o padrão do arquivo.
