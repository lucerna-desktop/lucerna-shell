# Desempenho do desfoque

**Data:** 2026-10-27
**Repositório:** `lucerna-shell`
**Depende de:** a moldura (`docs/superpowers/specs/2026-10-27-paineis-moldura-design.md`, PR #56, já na `main`).
**Hyprland:** 0.56.2 com config em Lua (conferido no container `lucerna-polish`).

## Por quê

O monitor do usuário é de 144 Hz, e o desfoque do Hyprland sempre derrubou o desempenho dele. O Lucerna desfoca as próprias camadas (`lucerna-panel-*`) por uma regra de camada que o shell envia ao Hyprland (`ThemeSwitcherState.blurLua`); com a moldura, a janela da barra ocupa a tela inteira enquanto a moldura aparece, e o papel de parede animado continua rodando por baixo. A cada quadro em que algo muda atrás de uma camada desfocada, o Hyprland refaz o desfoque. A 144 Hz, isso é mais que o dobro do trabalho do container (60 Hz).

## O que existe hoje

- **Regras enviadas pelo shell** (`features/themeSwitcher/state/ThemeSwitcherState.qml`, por `Hypr.evalLua`, que é `hyprctl eval`): `blurLua(enabled)` → `hl.layer_rule({ match = { namespace = "^lucerna-panel-.*" }, blur = …, ignore_alpha = 0.45 })`; `blurConfig` → `hl.config({ decoration = { blur = { size, passes } } })`, com 120 ms de espera para o arrasto dos controles; `noAnimLua()` → `no_anim` na barra e nos `lucerna-frame-*`. Um `hyprctl reload` apaga tudo, e o `reapply()` (pelo `Hypr.configReloaded`) manda de novo. As regras de camada se acumulam no Hyprland: a última que casa vale, por isso cada mudança envia uma regra nova inteira.
- **Quem é desfocado:** os painéis centralizados (`OverlayPanel` fora da moldura, `lucerna-panel-<nome>`), a janela da forma (`lucerna-panel-bar`), os popups de notificação (`lucerna-panel-notifications`) e as janelas de monitores (`lucerna-panel-monitor-confirm`, `lucerna-panel-identify`). Os painéis que saem da moldura (`lucerna-frame-*`) não: o fundo deles é a forma, já desfocada na janela da barra.
- **Tema e preferências:** `ThemeManager.blur` (`enabled`, `size`, `passes`, `customized`), do `hyprland.blur*` do tema e do `Config.blurOverride` (`{ enabled, size, passes }`). Todos os 12 temas trazem `blurSize: 6` e `blurPasses: 2` (gerados pelo `dev/themes.py`). A página "Transparência e desfoque" (`features/settings/ui/GlassPage.qml`, via `SettingsState`) tem o interruptor "Desfocar o fundo", "Intensidade" (size, 1–16) e "Suavidade" (passes, 1–4), e a prévia `GlassPreview`.
- **Papel de parede animado** (`features/wallpaper/`): `WallpaperState.shouldAnimate(screen)` junta as pausas (tela bloqueada, tela cheia, tela apagada, modo estrito); o `EffectView` (shader, `running` e `fps`) e o `VideoWallpaper` (`playing`) só obedecem. Pausado, o último quadro fica e nada redesenha.
- **Hyprland 0.56.2 (padrões conferidos com `hyprctl getoption` no container):** `decoration:blur:new_optimizations` = true, `decoration:blur:popups` = false, `decoration:blur:xray` = false, `decoration:blur:enabled` = true. **`misc:vfr` não existe mais**: virou `debug:vfr` (padrão true, "não desligue a não ser para depurar"). As regras `hl.layer_rule({ …, xray = true })`, `hl.window_rule({ …, no_blur = true })` e `hl.config({ debug = { vfr = true } })` são aceitas pelo `hyprctl eval`.
- **A config do usuário:** neste PC o host é KDE; o Hyprland só existe no container de teste (`dev/hyprland.lua`, que não mexe em desfoque). A máquina de 144 Hz tem o `hyprland.lua` do próprio usuário, que o shell não lê nem escreve. O shell só aplica por cima, em tempo de execução, e reaplica depois de um reload.

## Decisões do usuário

1. **Desfoque só na área da forma.** A moldura já faz isso na aparência: o `ignore_alpha = 0.45` limita o desfoque aos pixels quase opacos da forma (o véu e as sobras transparentes ficam de fora), os painéis da moldura não são desfocados de novo (`lucerna-frame-*`), e só com o OSD a janela da forma encolhe para a coluna da direita (`Frame.compactOn`). **Registro, sem mudança:** o custo, porém, não encolhe com a forma. Pelo funcionamento do Hyprland, o desfoque é calculado sobre a área danificada da superfície inteira e o `ignore_alpha` só recorta o resultado; com a moldura à mostra, a janela da barra é a tela inteira. O ganho de verdade vem dos itens 2 e 3; a medição antes/depois confirma.
2. **Opção "Desfoque" nas Configurações com três níveis:** Desempenho, Completo e Desligado. "Desempenho" = `xray` nas camadas `lucerna-panel-*`. O xray é por superfície (não há xray parcial) e faz a camada desfocar só o fundo (o papel de parede e as camadas de baixo), um desfoque que o Hyprland guarda e reaproveita (`new_optimizations`); o ganho aparece quando há janelas mudando atrás do painel, que deixam de ser desfocadas. Sobre a área de trabalho vazia, os dois níveis custam o mesmo. "Completo" é o de hoje (desfoca o que estiver atrás, janelas incluídas).
3. **Papel de parede animado pausado ou com menos FPS enquanto houver painel aberto.** Com o papel animado, o fundo guardado do xray suja a cada quadro e é refeito na tela inteira; sem pausa, o item 2 quase não rende.
4. **Menos passadas (1–2) e `size` maior (8–12)**, para manter a aparência: o raio do desfoque de Kawase cresce com `size × 2^passes`, e cada passada a menos poupa uma descida e uma subida na tela inteira.
5. **`vfr` e `new_optimizations` garantidos ligados** (sem perda visual). No 0.56, o `vfr` é `debug:vfr`.
6. **Desfoque só onde importa:** `blur.popups` desligado; o desfoque nas janelas vira opcional (o Lucerna desfoca os painéis dele pela regra de camada, que independe do desfoque das janelas).

Fora deste PR: o modo jogo (projeto próprio).

## Objetivos

- Um seletor "Desfoque" com Desempenho, Completo e Desligado, aplicado na hora, guardado nas preferências e reaplicado depois de um `hyprctl reload`.
- Um interruptor "Desfocar as janelas", também reaplicado depois de um reload.
- O papel de parede animado parado enquanto uma camada desfocada do shell cobre aquela tela, e de volta quando ela some, sem salto nem tela preta.
- Os temas com menos passadas e `size` maior, com a aparência equivalente à de hoje nas capturas.
- `debug.vfr`, `decoration.blur.new_optimizations` e `decoration.blur.popups = false` enviados junto com a config de desfoque, e reenviados depois de um reload.
- Um IPC para trocar e ler o nível (`qs -c lucerna ipc call blur set|get`), usado pela medição e pelos atalhos do usuário.
- Medição antes/depois documentada no PR (container a 60 Hz) e um comando para o usuário medir a 144 Hz.

## Não objetivos

- O modo jogo.
- Mudar a forma da moldura, a organização das janelas ou o `Frame` (a janela da barra continua de tela inteira com a moldura à mostra).
- Escrever no `hyprland.lua` do usuário ou em qualquer arquivo de config do Hyprland.
- Xray parcial ou por região (o Hyprland não tem).
- Novo efeito de desfoque feito pelo Qt nas camadas (o `MultiEffect` da tela de bloqueio e da prévia continua só nelas).

## Anti-objetivos

- **A aparência piorar visivelmente** no nível padrão: desfoque granulado, em blocos ou "lavado" com as passadas novas; painel que fica transparente demais. Com o xray, mostrar o papel de parede desfocado em vez das janelas atrás do painel é a troca aceita, não uma piora.
- **Mexer na config real do usuário além do que o shell já gerencia:** nada de `hyprctl keyword`/`eval` em opções que não sejam as do desfoque listadas aqui; nada de desligar `decoration.blur.enabled` (isso mataria também o desfoque das camadas); nada de regra que desfaça as regras de janela do próprio usuário (um `no_blur = false` para todas apagaria um `no_blur` que ele tenha).
- **O papel de parede piscando** ao pausar e voltar (um vídeo que recomeça do zero, um efeito que salta de tempo), ou pausando por um popup de notificação que passa.
- Comandos ao Hyprland a cada quadro ou a cada passo de um arrasto.
- Qualquer teste que toque a sessão real, o D-Bus real, hardware real ou a internet.

## Decisões do construtor

- **Nível padrão: Desempenho.** Fica se a captura no container mostrar a aparência aceitável sobre o papel de parede (é o caso comum: painel sobre a área de trabalho). Se não ficar, o padrão é Completo, e o PR diz por quê.
- **Onde fica a opção:** Configurações → Transparência e desfoque, seção "Desfoque". O interruptor "Desfocar o fundo" vira um `SegmentedControl` com Desligado / Desempenho / Completo (a descrição de cada nível na linha), seguido de "Desfocar as janelas" (interruptor), "Intensidade" e "Suavidade". Desligado apaga as linhas de baixo, como hoje com o interruptor.
- **Onde fica o dado:** `Config.blurOverride.mode` (`"performance"`, `"full"` ou `"off"`), lido por `ThemeManager.blur.mode`; o tema pode trazer `hyprland.blurMode`; sem nada, `"performance"`. Quem tem `blurOverride.enabled: false` gravado continua com `"off"` (migração na leitura, sem reescrever o arquivo). `ThemeManager.blur.enabled` passa a ser `mode !== "off"`, para quem já o lê. O desfoque das janelas fica em `Config.blurWindows` (padrão true), fora do override do tema: é preferência do usuário, não do tema, e o "Restaurar padrões do tema" não o toca.
- **Passadas e size:** `blurPasses: 1` e `blurSize: 12` em todos os temas (pelo `dev/themes.py`), o mesmo raio de hoje (`12 × 2¹ = 6 × 2²`). Se a captura com uma passada mostrar blocos ou granulado visível, fica `blurPasses: 2` e `blurSize: 8`, e o PR registra a comparação. Quem tem `size`/`passes` no override continua com o seu.
- **Pausar, não baixar o FPS.** Menos FPS ainda suja o fundo guardado a cada quadro do papel de parede e refaz o desfoque da tela inteira; pausado, o custo é zero e o último quadro fica. Pausa só quando o desfoque não está desligado e há, naquela tela, uma camada desfocada grande: um painel do `Panels` aberto (centralizado ou da moldura) ou a janela da forma à mostra (barra revelada, OSD, central). Os popups de notificação e as janelas de monitores não pausam (pequenos e passageiros; pausar por eles faria o papel piscar). Volta assim que a última some.
- **Como as regras são montadas:** a regra de camada passa a levar o nível: `blur = <ligado>, xray = <desempenho>, ignore_alpha = 0.45`, numa função pura (`blurLua(mode)`), enviada só quando muda. A config de desfoque vira uma função pura (`blurConfigLua(size, passes)`) que leva também `new_optimizations = true`, `popups = false` e `debug = { vfr = true }`. Tudo continua no `ThemeSwitcherState` (é ele que conversa com o Hyprland), com o `reapply()` cobrindo as regras novas.
- **Janelas sem desfoque:** desligar envia `hl.window_rule({ match = { class = ".*" }, no_blur = true })`. Religar não envia a regra contrária (anti-objetivo); envia `hyprctl reload`, que apaga a regra, e o `reapply()` do shell manda de volta tudo o que é dele. O texto da linha avisa que religar recarrega a config do Hyprland. Na partida com o interruptor desligado, a regra vai junto com as outras.
- **IPC:** `blur set <performance|full|off>` e `blur get`, no `ThemeManager` (como o `theme set/get`). Valor desconhecido não muda nada.
- **Medição:** ver a seção seguinte.

## Critério de medição

O desfoque custa no Hyprland, não no `qs`: os tempos de quadro do Qt (`QSG_RENDER_TIMING`) não bastam. A medição soma o uso de CPU do processo do Hyprland aninhado e, se houver acesso, o uso da GPU (`intel_gpu_top -J`, a GPU Intel repassada ao container).

- **No container (60 Hz), antes e depois, com o desfoque ligado:** um script novo no scratchpad da sessão, derivado do `moldura/fix-bench.py` (mesmas funções `run`, `sample`, `phase` e o `vclick.py`), que amostra também o PID do Hyprland do `lucerna-polish` (`docker top`) e roda, para a `main` (`lucernamain`, o Completo de hoje com 6×2) e para a branch em Completo, Desempenho e Desligado (trocados pelo IPC `blur set`): (a) parado com o painel superior aberto; (b) parado com a central aberta; (c) o launcher aberto; (d) dez aberturas e fechamentos do painel superior; (e) a barra revelada parada. Cada fase em duas situações: área de trabalho com um papel animado (um tema com shader) e uma janela que muda atrás do painel (`kitty` rodando um laço que escreve a hora a cada 16 ms). Resultado esperado no PR: Desempenho com a CPU do Hyprland claramente abaixo do Completo com a janela mudando; com o papel animado, a pausa leva os dois perto do Desligado; nenhuma fase pior que a `main`.
- **Na máquina real (144 Hz), pelo usuário:** `dev/bench-blur.sh` (novo, versionado), rodado pelo próprio usuário dentro da sessão Hyprland dele, por exemplo `dev/bench-blur.sh 20` (segundos por nível). Para cada nível (`full`, `performance`, `off`, trocados por `qs -c lucerna ipc call blur set`), abre o painel superior, espera, mede o uso de CPU do Hyprland e do `qs` pelo `/proc` e o da GPU se houver `intel_gpu_top`, `nvidia-smi` ou o `gpu_busy_percent` da AMD, e imprime uma tabela. No fim, devolve o nível que estava antes (lido por `blur get`) e fecha o painel. Ele não liga o `debug:overlay` nem mexe em nada além do nível do desfoque (que é do shell), e o usuário confere a fluidez a olho durante as fases.

## O que fica para o construtor

- Os textos da interface (rótulos e descrições dos níveis), seguindo o tom das Configurações.
- Se a `GlassPreview` simula o xray (mostra só o papel de parede atrás do vidro no Desempenho) ou só a intensidade.
- O nome exato das funções e propriedades novas, desde que fiquem no lugar indicado acima e as do `core/` tenham 100% de cobertura.
- Os testes de unidade da lógica nova (nível e migração no `ThemeManager`; regras no `ThemeSwitcherState`; a decisão de pausa no `WallpaperState`) e o que a fumaça confere (o IPC `blur get/set` responde e o shell segue vivo).
- O texto do PR com as tabelas da medição e as capturas de antes e depois (painel sobre o papel de parede e sobre uma janela, nos três níveis).
