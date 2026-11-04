# A base robusta — plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIO: use superpowers:subagent-driven-development (o método já escolhido) para implementar este plano tarefa por tarefa. Os passos usam checkbox (`- [ ]`) para acompanhamento.

**Objetivo:** entrar numa sessão Lucerna pronta em qualquer máquina (`lucerna-session` + a base do Hyprland), com o shell que volta sozinho (reinício com pausa crescente, modo de segurança, tela de emergência), bloqueio confiável pelo logind (antes de dormir, tampa, `loginctl`) e escala fracionária de primeira classe (shell alinhado ao pixel, escala interna e o modo "Escala pelos apps"), tudo medido e conferido no container.

**Arquitetura:**
- **Sessão:** o `lucerna-session` (bash, `session/bin/`) é a entrada da sessão: detecta GPU, teclado e init, exporta o ambiente e roda o `start-hyprland` com a base (`session/hypr/hyprland.lua`). A base carrega, nesta ordem, os padrões, o arquivo controlado pelo shell (`~/.config/lucerna/hypr/settings.lua`) e o `~/.config/hypr/hyprland.lua` do usuário. No `hyprland.start`, a base chama `lucerna-session ready`, que sobe o shell pelo systemd do usuário (`lucerna-session.target` → `lucerna-shell.service`) ou, sem systemd, direto.
- **Supervisor:** nos dois caminhos o processo supervisionado é o mesmo `lucerna-session supervise`, que aplica a política de quedas (1/2/4 s, modo de segurança, emergência). O systemd só reinicia o supervisor. **Decisão de desenho:** a política fica num lugar só e é testável no container, que não tem systemd. O spec pede "serviço do usuário que reinicia em ~1 s": o shell volta em ~1 s pelo supervisor, dentro do serviço.
- **Bloqueio pelo logind:** fica **no shell** (`services/Logind.qml`), pelo `gdbus monitor` (glib2, presente com o Qt) e pelo `systemd-inhibit`/`elogind-inhibit` (inibidor de atraso). Não fica no `lucernad`: um só caminho de código, e o shell bloqueia sem o daemon (o `lucernad` também não pode depender do shell para dormir). O inibidor é solto quando o `WlSessionLock.secure` confirma o bloqueio na tela.
- **Escala:** `core/pixel/Pixel.qml` alinha bordas e posições ao pixel físico. A escala interna multiplica as medidas do tema (`ThemeManager.px`). O modo "Escala pelos apps" deixa os monitores em 1 e escreve o ambiente e os arquivos de cada toolkit. **Não** usamos `QT_SCALE_FACTOR` no próprio shell: ele mudaria o sistema de coordenadas do Qt em relação ao do Hyprland (camadas, `hyprctl`, captura, visão geral).

**Tecnologia:** QML do Quickshell 0.3.2 e Qt 6; bash; Lua do Hyprland 0.56.2; Python 3 (testes `unittest` em `ci/tests/`, o logind falso com `python-gobject`); testes QML em `tests/*.test.js`; fumaça no `sway` headless; conferência no container `lucerna-polish` (`dev/test.sh`).

**Spec:** `docs/superpowers/specs/2026-11-04-base-robusta-design.md`. Leia inteiro, inclusive "Decisões minhas", a seção 6 e "Duas formas de escala".

## Global Constraints

- **Branch:** `feat/base-robusta` (spec em `077f5e1`/`796e073` sobre a `main` `f7af95b`), no checkout principal (o `dev/test.sh` monta o checkout de onde é chamado). Merge pelo controlador, por merge commit, depois da revisão final (Opus) e do CI verde.
- **Nunca tocar** o container `lucerna-dev` nem o repositório `caelestia-lab`. A conferência é no `lucerna-polish`, pelo `dev/test.sh`. **Sem `hyprctl reload`** no container.
- **Testes:**
  - sem hardware real, sem o D-Bus real do host (o logind inclusive) e sem a sessão real do usuário (KDE); sem áudio;
  - nada instalado no host: os testes rodam o `lucerna-session` do repositório com raízes falsas (`LUCERNA_SYSFS`, `LUCERNA_ETC`, `LUCERNA_USR_SHARE`, `LUCERNA_RUN`) e programas falsos no `PATH`.
- **Logind só falso no desenvolvimento:** com `LUCERNA_DEV=1`, o `services/Logind.qml` só liga com `LUCERNA_LOGIND_BUS` (o barramento privado do logind falso). Sem ela, fica desligado e avisa uma vez no log. O container monta o barramento do sistema do host: um inibidor ou um `gdbus monitor` ali seria no logind de verdade.
- **Energia simulada no desenvolvimento:** `lucerna-session poweroff|reboot` e a tela de emergência, com `LUCERNA_DEV=1`, só registram e avisam (como o `DevMode.simulate`).
- **Nomes:** comandos, subcomandos, funções e propriedades novos em inglês (`lucerna-session supervise`, `shell restart`, `Logind.parseLine`). Textos, comentários e logs em pt-BR com acentos (regra `acentos` do `ci/rules.py`).
- **Regras do shell:**
  - `qmllint` com 0 avisos; camadas do `ci/rules.py`;
  - funções numa linha `function nome(...) {`;
  - 100% das funções do escopo do `tests/coverage.json` chamadas (os serviços novos entram na lista `serviços`);
  - um teste que muda um singleton restaura o estado.
- **O shell nunca escreve** no `~/.config/hypr/hyprland.lua`. Ele só escreve em `~/.config/lucerna/` e nos arquivos de toolkit do modo "Escala pelos apps" (Tarefa 14), sempre com cópia `.lucerna-bak` antes da primeira mudança e devolução ao sair do modo. **No modo de segurança, nada é escrito.**
- **Caminhos instalados** (o pacote é do marco 6; aqui só ficam definidos). O `lucerna-session` acha a pasta `session/` do repositório pelo próprio caminho (`realpath`), e senão usa estes:

  | No repositório | Instalado em |
  |---|---|
  | `session/bin/lucerna-session` | `/usr/bin/lucerna-session` |
  | `session/lib/*.sh` | `/usr/lib/lucerna/session/` |
  | `session/hypr/` | `/usr/share/lucerna/hypr/` |
  | `session/emergency/` | `/usr/share/lucerna/emergency/` |
  | `session/systemd/*` | `/usr/lib/systemd/user/` |
  | `session/wayland-sessions/lucerna.desktop` | `/usr/share/wayland-sessions/` |
- **Arquivos de estado:**
  - em `$XDG_RUNTIME_DIR/lucerna/`: `session.json`, `crash.json`, `locked`, `supervisor.pid`, `qs.pid`, `hold`;
  - em `~/.local/state/lucerna/`: `session.log` e `shell/qs-<data>.log` (os 5 últimos);
  - em `~/.config/lucerna/`: `hypr/settings.lua`, `apps.conf`, `session.env`, `Xresources`.
- Commits no estilo `Sessão: o supervisor com o modo de segurança`. Verificação de toda tarefa: `dev/ci.sh lint rules unit` verde; nas tarefas que mexem na fumaça, também `smoke`.

## Review Focus

1. **O shell cai com a tela bloqueada** (uma vez, ou várias até o modo de segurança e a emergência): a área de trabalho nunca aparece e o shell volta bloqueado. Testes:
   - `session: a marca do bloqueio volta a bloquear` (Tarefa 6);
   - a conferência `kill -SEGV` bloqueado e em sequência (Tarefa 6, passo 6).
2. **Suspender com o shell lento ou morto:** com o shell vivo, a máquina não dorme antes de o bloqueio estar na tela. Com o shell morto, a suspensão não fica presa (o logind dorme depois do prazo). Testes:
   - `session: dormir espera o bloqueio na tela` (Tarefa 9);
   - a fumaça `logind` (Tarefa 9);
   - a conferência com o `qs` parado (Tarefa 9, passo 6).
3. **O Hyprland sai** (sair da sessão, compositor caído): o supervisor para, sem reinício, modo de segurança nem tela de emergência. Teste: `test_compositor_gone_stops_without_restart` (Tarefa 6).
4. **O usuário já tem regras de monitor no próprio `hyprland.lua`** (ou o include antigo do `lucerna-monitors.lua`): as regras dele valem, a escala automática não as atropela, e o arquivo antigo gerado vira um aviso inofensivo. Testes:
   - `claims: regra do usuário vence a automática` (Tarefa 4);
   - `hyprfile: o arquivo antigo gerado é neutralizado e o do usuário não` (Tarefa 3).
5. **Super sozinho e Super+tecla:** soltar o Super depois de Super+1 (ou de Super+arrastar) não abre o lançador; o Super sozinho abre. Teste: a conferência com o `wtype` (Tarefa 11, passo 5).

---

### Task 1: O bench com escala e a medição de base (1 e 1,25)

**Files:**
- Modify: `dev/bench-paineis.sh`, `dev/bench-blur.sh`
- Create: `docs/superpowers/bench/2026-11-04-escala-base.txt`, capturas em `docs/superpowers/bench/2026-11-04-escala-base/`

**Interfaces:**
- Produces: `BENCH_SCALE=<s>` nos dois benches. No começo, `hyprctl eval 'hl.monitor({ output = "<1º monitor>", scale = <s> })'`; no fim e no Ctrl+C, devolve a escala lida antes (no `trap` que já existe). É a única exceção ao "nenhum `hyprctl eval`" dos cabeçalhos: atualize o comentário. Sem `BENCH_SCALE`, nada muda.
- Produces: no `bench-paineis.sh`, o caso novo `janela-x11`, logo depois do `janela`. É igual a ele, com o kitty em X11 (`KITTY_DISABLE_WAYLAND=1`, pelo XWayland). Mede o custo de um app X11 ampliado.
- Produces (no `.txt`):
  - as tabelas dos dois benches em escala 1 e 1,25 (duas rodadas cada);
  - se o `qs` e o kitty usam o `wp_fractional_scale_v1`: `WAYLAND_DEBUG=1` num `qs` e num kitty de teste, `grep -c wp_fractional_scale`;
  - uma conclusão de 3 a 5 linhas sobre de onde vem o custo de 1,25 (shell, Hyprland, app X11).

- [ ] **Step 1:** implementar o `BENCH_SCALE` e o caso `janela-x11`. `bash -n`, `shellcheck` sem aviso, `python3 -I dev/bench-paineis.py --self-test` passa (o caso novo usa o mesmo leitor).
- [ ] **Step 2:** `dev/test.sh up`, depois `dev/test.sh run 'BENCH_SCALE=1 bash ~/.config/quickshell/lucerna/dev/bench-paineis.sh 10 10'` e o mesmo com `1.25`, duas vezes cada. Depois o `bench-blur.sh 20` nas duas escalas. Esperado: tabelas completas, e a escala do monitor de volta a 1 no fim (`hyprctl monitors -j`).
- [ ] **Step 3: Capturas de base** em 1,25 e 1,5 (`dev/test.sh shot`): a barra, o painel superior, a central, as Configurações e a tela de bloqueio. Recortes ampliados (`ffmpeg -vf crop,scale=iw*4:ih*4:flags=neighbor`) de uma borda de 1 px e de um texto. São a referência das Tarefas 12 e 13.
- [ ] **Step 4:** escrever o `.txt` com a conclusão e, se o custo do Hyprland em 1,25 passar de 1,5x o de 1, uma linha "orienta o padrão: …" para a Tarefa 14.
- [ ] **Step 5: Commit** `Bench: a escala nos benches e a medição de base em 1 e 1,25`.

### Task 2: O logind falso e a imagem do container

**Files:**
- Create: `ci/logind-fake.py`, `ci/logind-fake.sh`
- Modify: `dev/Dockerfile` (`python-gobject lua`), `dev/test.sh` (rebuild pelo hash do Dockerfile, `LUCERNA_LOGIND_BUS`, subcomando `logind`), `dev/run.sh` (o mesmo rebuild), `dev/hyprland.lua` (sobe o logind falso)

**Interfaces:**
- Produces (`ci/logind-fake.sh start <pasta>`): sobe um `dbus-daemon --session --address=unix:path=<pasta>/lucerna-fake-system` e o `ci/logind-fake.py` nele, espera o nome `org.freedesktop.login1` e imprime o endereço. Um segundo `start` com o falso de pé não faz nada. `stop` derruba os dois.
- Produces (`ci/logind-fake.py --address ADDR`, Gio, só o `python-gobject`):
  - `/org/freedesktop/login1`, `org.freedesktop.login1.Manager`:
    - `GetSession(s) → o` (sempre `/org/freedesktop/login1/session/_31`);
    - `Inhibit(ssss) → h` (guarda o fd e o `mode`);
    - as propriedades `LidClosed` (b, com `PropertiesChanged`), `Docked` (b) e `InhibitDelayMaxUSec` (t, 5000000);
    - o sinal `PrepareForSleep(b)`.
  - `/org/freedesktop/login1/session/_31`, `org.freedesktop.login1.Session`: os sinais `Lock` e `Unlock`, o `SetLockedHint(b)` e a propriedade `LockedHint`.
  - `/org/lucerna/Test`, `org.lucerna.Test` (o controle):
    - `Suspend()`: emite `PrepareForSleep(true)` e espera os inibidores `delay` fecharem (POLLHUP no fd), até 5 s. Registra `{releasedMs, timedOut, lockedHintAtSleep}`, espera 1 s e emite `PrepareForSleep(false)`.
    - `LockSession()`, `UnlockSession()`, `SetLid(b)`;
    - `Status() → s` (JSON: `delayHeld`, `lockedHint`, `lid`, `lastSleep`).
- Produces (`dev/test.sh`):
  - no `up`, `-e LUCERNA_LOGIND_BUS=unix:path=/run/user/1000/lucerna-fake-system`;
  - `dev/test.sh logind suspend|lock|unlock|lid on|lid off|status`, pelo `gdbus call --address … --dest org.freedesktop.login1 --object-path /org/lucerna/Test --method org.lucerna.Test.<X>`;
  - a imagem é refeita quando a etiqueta `dockerfile.sha` (sha256 do `dev/Dockerfile`) difere, além do `lucernad.rev`. O `dev/run.sh` usa a mesma regra.
- `dev/hyprland.lua`: no `hyprland.start`, `bash ~/.config/quickshell/lucerna/ci/logind-fake.sh start /run/user/1000` antes do shell.

- [ ] **Step 1:** escrever os dois arquivos e as mudanças. `ruff` e `shellcheck` sem aviso.
- [ ] **Step 2:** `dev/test.sh up` (refaz a imagem). Depois `dev/test.sh logind status` → JSON com `delayHeld: 0`.
- [ ] **Step 3:** no container, `systemd-inhibit --what=sleep --mode=delay sleep 30 &` com `DBUS_SYSTEM_BUS_ADDRESS` do falso. Depois `logind status` → `delayHeld: 1`. Em seguida `logind suspend` → `lastSleep.timedOut: true` depois de ~5 s; matar o inibidor antes do prazo → `timedOut: false`.
- [ ] **Step 4:** `gdbus monitor --address <falso> --dest org.freedesktop.login1` durante um `logind lock`, `suspend` e `lid on`. Guarde as linhas no relatório: são o formato que a Tarefa 9 lê (o mesmo do logind real, porque quem formata é o `gdbus`).
- [ ] **Step 5: Commit** `Teste: o logind falso no container`.

### Task 3: O arquivo controlado pelo shell (`settings.lua`)

**Files:**
- Create: `services/HyprFile.qml`, `tests/hyprfile.test.js`
- Modify:
  - `services/Input.qml`: as funções puras `optionsLua`, `deviceLua` e `layoutLua`, usadas pelo eval e pelo arquivo;
  - `features/input/state/InputState.qml`, `features/displays/state/DisplaysState.qml`, `features/themeSwitcher/state/ThemeSwitcherState.qml`;
  - `features/settings/state/MonitorsState.qml`, `features/settings/ui/MonitorsPage.qml`;
  - `tests/coverage.json`, `tests/input.test.js`

**Interfaces:**
- Produces (`HyprFile`, singleton):
  - `readonly property bool layered: Quickshell.env("LUCERNA_SESSION") === "1"` (posto pelo `lucerna-session`);
  - `readonly property string path` (`$XDG_CONFIG_HOME/lucerna/hypr/settings.lua`);
  - `setSection(name: string, lua: string): void`: guarda e grava depois de 300 ms, só se o texto mudou, por escrita atômica. Com `Config.safeMode`, não faz nada (a Tarefa 6 cria o `safeMode`; até lá, considere falso);
  - `compose(sections: var): string`: o cabeçalho (`-- Gerado pelo Lucerna (Configurações). Não edite: é reescrito. O seu arquivo é o ~/.config/hypr/hyprland.lua.`) e as seções em ordem alfabética, cada uma com `-- [nome]` e o Lua dela. Seções vazias saem;
  - `isLegacyGenerated(text: string): bool`: a primeira linha começa com `-- Gerado pelo Lucerna`;
  - `migrateLegacy(): void`: se o `~/.config/hypr/lucerna-monitors.lua` existe e `isLegacyGenerated`, regrava com `-- Gerado pelo Lucerna: o arranjo de monitores agora fica em ~/.config/lucerna/hypr/settings.lua.`. Um arquivo que não é gerado fica intocado.
- Seções:
  - `theme`: `ThemeSwitcherState.rules(true)` juntas;
  - `input`: as opções e os dispositivos;
  - `keyboard`: os layouts, ou o `kb_file` com os remapeamentos;
  - `binds`: a `bindLua` dos binds efetivos;
  - `monitors`: a mesma lista de regras por `desc:` do `DisplaysState.writeLogin` de hoje, sempre com `layered` (sem a opção).
- Com `layered`, o `InputState`, o `DisplaysState` e o `ThemeSwitcherState` **não reaplicam no `configreloaded`** (o arquivo já vale, e o do usuário, carregado depois, vence). Sem `layered`, o comportamento de hoje fica igual.
- Com `layered`, a `MonitorsPage` esconde o bloco "Usar o arranjo desde o login" e a linha do include.

- [ ] **Step 1: Testes que falham** (`tests/hyprfile.test.js`):
  - `hyprfile: as seções em ordem, sem as vazias`: o `compose({ monitors: "a", binds: "", input: "b" })` dá o cabeçalho, `-- [input]` com `b` e `-- [monitors]` com `a`, e nenhum `-- [binds]`.
  - `hyprfile: o arquivo antigo gerado é neutralizado e o do usuário não`: `isLegacyGenerated("-- Gerado pelo Lucerna (Configurações → Monitores)…")` verdadeiro; `"hl.monitor(...)"` e `""` falsos.
  - Em `tests/input.test.js`, `input: o mesmo Lua no eval e no arquivo`: `optionsLua({ "input.touchpad.tap_to_click": true })` = `hl.config({ input = { touchpad = { tap_to_click = true } } })`; `layoutLua({ layouts: "br,us", variants: ",intl", options: "" })` com as três etapas da `applyLayouts`.
- [ ] **Step 2:** `dev/ci.sh unit` → falha.
- [ ] **Step 3:** implementar. Entram em `tests/coverage.json`: `HyprFile`: `["compose", "isLegacyGenerated"]`, e `optionsLua`, `deviceLua`, `layoutLua` em `services/Input.qml`.
- [ ] **Step 4:** `dev/ci.sh lint rules unit` → verde.
- [ ] **Step 5: Conferir no container** com `LUCERNA_SESSION=1` no `qs` (`dev/test.sh run 'pkill -x qs; LUCERNA_SESSION=1 setsid -f qs -c lucerna'`):
  - mudar a sensibilidade do mouse e um atalho → `~/.config/lucerna/hypr/settings.lua` com as seções `input`, `binds` e `theme`;
  - um `lucerna-monitors.lua` gerado de teste é neutralizado;
  - um escrito à mão fica igual.
- [ ] **Step 6: Commit** `Sessão: o arquivo do Hyprland controlado pelo shell`.

### Task 4: A base do Hyprland

**Files:**
- Create:
  - `session/hypr/hyprland.lua`;
  - `session/hypr/lucerna/scale.lua` (puro, sem `hl`), `session/hypr/lucerna/claims.lua`;
  - `session/hypr/tests/scale_test.lua`, `session/hypr/tests/claims_test.lua`;
  - `ci/tests/test_hypr_lua.py`
- Modify: `ci/packages/rules.txt` e `ci/packages/lint.txt` (`lua`), `ci/lint.sh` (parte `luac`: `luac -p` em todo `session/**/*.lua`)

**Interfaces:**
- Produces (`scale.lua`): `M.scale_for(width_px, height_px, width_mm, height_mm) → number`.
  - Sem tamanho físico (mm ≤ 0, ou a razão de aspecto do mm diferindo mais de 20% da dos pixels: EDID de projetor/TV falso), dá 1.
  - Senão, `ppi = width_px / (width_mm / 25.4)`, alvo `ppi / 110`, e o passo de 0,25 mais próximo entre 1 e 3 em que `width_px / s` e `height_px / s` são inteiros (o mais próximo para baixo em empate, 1 se nenhum).
- Produces (`claims.lua`):
  - `M.install(hl) → claims`: troca `hl.monitor` por um envoltório que anota `spec.output` em `claims` e chama o original. Devolve também `claims.original` (o `hl.monitor` de antes).
  - `M.claimed(claims, monitor) → boolean`: verdadeiro se `claims[monitor.name]`, `claims["desc:" .. monitor.description]` ou `claims[""]` (uma regra genérica de outra camada).
- Produces (`hyprland.lua`, a base):
  1. Guarda `LUCERNA_BASE_LOADED` (se já carregada, retorna). Acha a pasta pelo `LUCERNA_DATA_DIR` e põe `<pasta>/hypr/?.lua` no `package.path`.
  2. `hl.monitor({ output = "", mode = "highrr", position = "auto", scale = 1 })` pelo original. Depois, `claims.install(hl)`.
  3. `hl.config`:
     - `input`: `kb_layout`/`kb_variant`/`kb_model`/`kb_options` dos `LUCERNA_KB_*` (padrão `us`), `touchpad = { tap_to_click = true, natural_scroll = true }`;
     - `general = { gaps_in = 4, gaps_out = 10, border_size = 2 }`;
     - `misc = { allow_session_lock_restore = true, disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0, key_press_enables_dpms = true, mouse_move_enables_dpms = true }`;
     - `xwayland = { force_zero_scaling = true }`;
     - `ecosystem = { no_update_news = true, no_donation_nag = true }`.
  4. `hl.env` (confira a assinatura no stub `/usr/share/hypr/stubs/hl.meta.lua`):
     - `QT_QPA_PLATFORM=wayland;xcb`, `QT_WAYLAND_DISABLE_WINDOWDECORATION=1`;
     - `GDK_BACKEND=wayland,x11,*`, `SDL_VIDEODRIVER=wayland,x11`;
     - `ELECTRON_OZONE_PLATFORM_HINT=auto`, `MOZ_ENABLE_WAYLAND=1`, `_JAVA_AWT_WM_NONREPARENTING=1`.
  5. Os binds fixos, com `local mod = os.getenv("LUCERNA_DEV") == "1" and "ALT" or "SUPER"`:
     - `mod + Return` → `lucerna-session open terminal`;
     - `CTRL + ALT + Delete` → `lucerna-session power`;
     - `CTRL + ALT + SHIFT + Escape` → `lucerna-session logout`.
  6. `pcall(dofile, <XDG_CONFIG_HOME>/lucerna/hypr/settings.lua)`, depois `pcall(dofile, <XDG_CONFIG_HOME>/hypr/hyprland.lua)`. Um erro vira `hl.notification.create({ text = "Lucerna: erro em <arquivo>: <erro>", timeout = 15000 })`, e a sessão segue.
  7. A escala automática, no `hyprland.start`, no `monitor.added` e no `config.reloaded`: para cada monitor não reivindicado, `claims.original({ output = m.name, mode = "highrr", position = "auto", scale = s })`. O `s` vem de `scale.scale_for(m.width, m.height, m.physical_width, m.physical_height)`, ou 1 com `lucerna_scale_mode == "apps"` (global posto pela seção `scale` da Tarefa 14).
  8. No `hyprland.start`, `hl.exec_cmd("lucerna-session ready")`.

- [ ] **Step 1: Testes que falham** (`session/hypr/tests/*.lua`, rodados pelo `ci/tests/test_hypr_lua.py` com `lua`; cada `assert` com mensagem):
  - `scale: 15,6" 1920x1080 (344x194 mm) dá 1,25`;
  - `scale: 27" 2560x1440 (597x336) dá 1`;
  - `scale: 27" 3840x2160 (597x336) dá 1,5`;
  - `scale: 14" 2880x1800 (302x189) dá 2,25`;
  - `scale: ultrawide 2560x1080 (673x284) dá 1`;
  - `scale: sem mm ou mm absurdo (160x90 numa 1920x1080 de 0x0, 1600x900 mm de TV) dá 1`;
  - `claims: regra do usuário vence a automática` (`hl.monitor({ output = "desc:AU Optronics 0x1234" })` reivindica o monitor com essa descrição; `{ output = "eDP-1" }` reivindica pelo nome; a regra genérica `""` da base é anotada **antes** do `install` e não reivindica);
  - `claims: o original continua sendo chamado`.
- [ ] **Step 2:** `dev/ci.sh rules` → falha.
- [ ] **Step 3:** implementar.
- [ ] **Step 4:** `dev/ci.sh lint rules` → verde.
- [ ] **Step 5:** no container, `dev/test.sh run 'LUCERNA_DATA_DIR=~/.config/quickshell/lucerna/session Hyprland --verify-config -c ~/.config/quickshell/lucerna/session/hypr/hyprland.lua'` → sem erros. Se o `--verify-config` não carregar Lua, registre e confira na Tarefa 5, que passa a usar a base.
- [ ] **Step 6: Commit** `Sessão: a base do Hyprland, com a escala pelo tamanho físico`.

### Task 5: O `lucerna-session` (entrada, detecção, `ready`, `open`, `logout`, `unlock`) e o container pela entrada real

**Files:**
- Create:
  - `session/bin/lucerna-session`, `session/lib/common.sh`, `session/lib/detect.sh`;
  - `services/LucernaSession.qml`, `tests/lucernasession.test.js`, `ci/tests/test_session.py`
- Modify:
  - `ci/lint.sh` (o `shellcheck` também em `session/`, inclusive o `lucerna-session` sem extensão);
  - `dev/test.sh` (o `docker run` termina com `dbus-run-session lucerna-session`, com `-e PATH=/home/dev/.config/quickshell/lucerna/session/bin:/usr/local/sbin:/usr/local/bin:/usr/bin`);
  - `dev/hyprland.lua` (vira a camada do usuário do container: sai o `exec_cmd("qs -c lucerna")` e o include do `lucerna-monitors.lua`; ficam o `lucernad`, o logind falso, o monitor 1920x1080 em escala 1, o `kb_layout = "br"` e os binds com Alt de volume e brilho; o `ALT + SHIFT + R` passa a `lucerna-session shell restart`);
  - `shell.qml` (instancia o `LucernaSession` para os avisos), `tests/coverage.json`

**Interfaces:**
- Produces (`lucerna-session`), subcomandos em inglês; os das Tarefas 6 e 7 entram depois:
  - **sem argumento:** a sessão.
    - Cria `$XDG_RUNTIME_DIR/lucerna` e roda o `detect`.
    - Exporta o ambiente:
      - o da GPU;
      - `LUCERNA_KB_*`;
      - `XDG_SESSION_TYPE=wayland`, `XDG_CURRENT_DESKTOP=Hyprland`, `XDG_SESSION_DESKTOP=lucerna`;
      - `LUCERNA_SESSION=1`, `LUCERNA_DATA_DIR`;
      - as linhas `^[A-Z_][A-Z0-9_]*=` do `~/.config/lucerna/session.env` (Tarefa 14; outras linhas são ignoradas).
    - Roda `start-hyprland -- --config $LUCERNA_DATA_DIR/hypr/hyprland.lua` (o `Hyprland --config …` sem o `start-hyprland`) e espera.
    - No fim: `systemctl --user stop lucerna-session.target` (systemd) ou TERM no supervisor (pelo `supervisor.pid`).
    - Tudo vai para `~/.local/state/lucerna/session.log`.
  - **`detect`:** imprime e grava o `session.json`: `{"gpu": "intel|amd|nvidia|hybrid|other|none", "drm": ["/dev/dri/cardN", ...], "nvidiaModeset": true|false|null, "keyboard": {"layout", "variant", "model", "options"}, "init": "systemd|other"}`.
    - **GPU:** os `card[0-9]*` sem hífen de `$LUCERNA_SYSFS/class/drm`, pelo `device/vendor`: `0x10de` NVIDIA, `0x8086` Intel, `0x1002` AMD.
      - Só NVIDIA: `nvidia`, com `LIBVA_DRIVER_NAME=nvidia`, `__GLX_VENDOR_LIBRARY_NAME=nvidia` e `NVD_BACKEND=direct`.
      - NVIDIA com outra: `hybrid`, com `AQ_DRM_DEVICES=<integrada>:<nvidia>`. A integrada é a não NVIDIA com `device/boot_vga` = 1, senão a primeira. Sem as variáveis da NVIDIA (a integrada desenha).
    - **`nvidiaModeset`:** `$SYSFS/module/nvidia_drm/parameters/modeset` = `Y` → true, `N` → false, sem o arquivo com NVIDIA → false; sem NVIDIA → null.
    - **Teclado**, nesta ordem:
      1. `$LUCERNA_ETC/X11/xorg.conf.d/00-keyboard.conf` (`Option "XkbLayout"`, `XkbVariant`, `XkbModel`, `XkbOptions`);
      2. `$LUCERNA_ETC/default/keyboard` (`XKBLAYOUT=`…);
      3. o `KEYMAP=` do `$LUCERNA_ETC/vconsole.conf`, traduzido pelo `$LUCERNA_USR_SHARE/systemd/kbd-model-map` (coluna 1 → layout, modelo, variante, opções);
      4. `us`.
      Nunca o `localectl` (é D-Bus).
    - **Init:** `systemd` se `$LUCERNA_RUN/systemd/system` existe e `systemctl --user show-environment` responde; senão `other`.
  - **`ready`** (chamado pela base):
    - com systemd, `dbus-update-activation-environment --systemd` (ou `systemctl --user import-environment`) com `WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_ID LUCERNA_SESSION LUCERNA_DATA_DIR` e as variáveis da GPU e do `session.env`, depois `systemctl --user start lucerna-session.target`;
    - sem systemd, `setsid -f lucerna-session supervise`. Nesta tarefa, o `supervise` provisório é só `exec qs -c "${LUCERNA_SHELL_CONFIG:-lucerna}"`; a Tarefa 6 o troca.
    - Com `~/.config/lucerna/Xresources` e o `xrdb`, `xrdb -merge` (Tarefa 14).
  - **`open terminal|browser|files`:**
    - o valor de `terminal=`/`browser=`/`files=` no `~/.config/lucerna/apps.conf`, se estiver instalado;
    - senão o primeiro instalado destas listas:
      - terminal: `kitty foot alacritty wezterm ghostty konsole gnome-terminal xfce4-terminal xterm`;
      - navegador: `firefox chromium google-chrome-stable brave vivaldi-stable librewolf zen-browser`;
      - arquivos: `dolphin nautilus thunar nemo pcmanfm-qt pcmanfm`.
    - Nenhum: `notify-send "Lucerna" "Nenhum <terminal> instalado"` e saída 1.
  - **`detect-apps`:** JSON `{"terminal": [instalados...], "browser": [...], "files": [...]}`.
  - **`logout`:** `hyprctl dispatch 'hl.dsp.exit()'`.
  - **`unlock`** (do TTY, depois de entrar com a senha): `hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'`. O efeito é conferido na Tarefa 6; se não desbloquear, troque pelo caminho que funcionar e documente no cabeçalho.
- Produces (`LucernaSession`, serviço):
  - lê `session.json` e `crash.json` (este e o modo de segurança, na Tarefa 6);
  - `notices(info: var): var` (puro) → `[{ summary, body }]`. Com `gpu` `nvidia`/`hybrid` e `nvidiaModeset !== true`: `{ summary: "A placa NVIDIA está sem o modeset do DRM", body: "Ligue nvidia-drm.modeset=1 nos parâmetros do kernel; sem ele, a placa da NVIDIA pode não funcionar no Lucerna." }`. A Tarefa 6 acrescenta o da queda;
  - mostra cada aviso uma vez por sessão (`notify-send -a Lucerna`), guardando no `PersistentProperties`.

- [ ] **Step 1: Testes que falham:**
  - `ci/tests/test_session.py` (roda o script do repositório com raízes falsas numa pasta temporária e falsos de `systemctl`, `hyprctl` e `notify-send` no `PATH`):
    - `test_detect_intel_only`;
    - `test_detect_nvidia_only_sets_env_and_modeset`;
    - `test_detect_hybrid_integrated_first` (Intel `boot_vga=1` + NVIDIA → `AQ_DRM_DEVICES` com a Intel antes; sem `__GLX_VENDOR_LIBRARY_NAME`);
    - `test_detect_modeset_off_and_missing`;
    - `test_keyboard_from_xorg_conf`;
    - `test_keyboard_from_vconsole_via_kbd_model_map` (`KEYMAP=br-abnt2` → `br`, modelo `abnt2`);
    - `test_keyboard_falls_back_to_us`;
    - `test_init_without_systemd_is_other`;
    - `test_open_uses_apps_conf_then_list` e `test_open_without_any_notifies`;
    - `test_session_env_only_allowlisted_lines` (uma linha `rm -rf /` ou `export X=1; y` não entra);
    - `test_logout_calls_exit`.
  - `tests/lucernasession.test.js`:
    - `lucernasession: aviso do modeset só com NVIDIA sem modeset` (`nvidia`/false, `hybrid`/null e `intel`/null).
- [ ] **Step 2:** `dev/ci.sh rules unit` → falha.
- [ ] **Step 3:** implementar o script, o serviço e as mudanças do container. Entra em `tests/coverage.json`: `LucernaSession`: `["notices"]`.
- [ ] **Step 4:** `dev/ci.sh lint rules unit` → verde.
- [ ] **Step 5: Conferir no container** (`dev/test.sh up`, agora pela entrada real):
  - o shell sobe (`wait_loaded`);
  - `dev/test.sh run 'cat $XDG_RUNTIME_DIR/lucerna/session.json'` → `gpu: intel`, `init: other`;
  - `hyprctl getoption misc:allow_session_lock_restore` → 1;
  - `hyprctl binds -j` com `ALT + Return`;
  - Alt+Enter (`wtype`, como no cabeçalho do `dev/test.sh`) abre o kitty;
  - um `session.json` de teste com `nvidia`/false e `dev/test.sh restart` → a notificação do modeset (captura).
- [ ] **Step 6: Commit** `Sessão: o lucerna-session, com a detecção de GPU, teclado e init`.

### Task 6: O supervisor, o modo de segurança e a volta bloqueada

**Files:**
- Create: `session/lib/supervise.sh`, `features/safeMode/state/SafeModeState.qml`, `features/safeMode/ui/SafeModeBanner.qml`
- Modify:
  - `session/bin/lucerna-session` (`supervise`, `shell`);
  - `core/config/Config.qml` (`safeMode` e o caminho do arquivo);
  - `services/Session.qml` (a marca do bloqueio), `services/LucernaSession.qml` (a queda e o modo de segurança);
  - `features/wallpaper/state/WallpaperState.qml` (estático no modo de segurança), `features/input/state/InputState.qml` (não aplica nada no modo de segurança);
  - `shell.qml`;
  - `dev/test.sh` (`restart` e `start_shell` pelo supervisor), `dev/bench-paineis.sh` (`shell stop`/`start`);
  - `ci/tests/test_session.py`, `tests/session.test.js`, `tests/lucernasession.test.js`, `tests/coverage.json`

**Interfaces:**
- Produces (`lucerna-session supervise`). A política, com variáveis só para os testes: `LUCERNA_CRASH_WINDOW=30`, `LUCERNA_CRASH_DELAYS="1 2 4"`, `LUCERNA_SAFE_TRIES=2`.
  - Grava `supervisor.pid` e roda `env -u QT_SCALE_FACTOR qs -c "${LUCERNA_SHELL_CONFIG:-lucerna}"` (no modo de segurança, com `LUCERNA_SAFE_MODE=1`). A saída vai para `~/.local/state/lucerna/shell/qs-<AAAAMMDD-HHMMSS>.log` (ficam os 5 últimos) e o pid para `qs.pid`.
  - O `qs` saiu:
    - **com `hold`:** espera o `SIGUSR1` do `shell start` e volta ao modo normal, com o contador zerado;
    - **sem o compositor** (o `hyprctl -j version` falha): sai com 0;
    - **senão é uma queda:** guarda o horário e descarta as quedas de fora da janela. Com n quedas na janela:
      - normal com n ≤ 3: espera o n-ésimo atraso, grava `crash.json` (`{"time", "log", "count": n, "safe": false}`) e reinicia;
      - normal com n = 4: passa ao modo de segurança, zera o contador, apaga o `$XDG_RUNTIME_DIR/lucerna/config.safe.json` e grava `crash.json` com `safe: true`;
      - no modo de segurança, `LUCERNA_SAFE_TRIES` quedas na janela: `lucerna-session emergency --mode crashed` (Tarefa 7; até lá, um `hyprctl notify` provisório) e espera o `shell start`.
  - `shell stop` (cria `hold`, TERM no `qs.pid`, espera ele sair), `shell start` (apaga `hold`, `SIGUSR1`), `shell restart` (os dois) e `shell status`. O status imprime `supervised running|held|safe|emergency` ou `unsupervised` (sem supervisor vivo). `shell start` com o modo de segurança ou a emergência volta ao normal.
- Produces (`Config`):
  - `readonly property bool safeMode: Quickshell.env("LUCERNA_SAFE_MODE") === "1"`;
  - o `FileView` lê e grava `Quickshell.statePath("config.json")`, ou, com `safeMode`, `$XDG_RUNTIME_DIR/lucerna/config.safe.json` (que o supervisor apaga ao entrar no modo): no modo de segurança, os padrões, sem tocar a config da pessoa.
- No modo de segurança:
  - o `WallpaperState` usa `"static"`;
  - o `InputState` não aplica nada;
  - o `HyprFile` não grava.
  O que fica desligado: o tema da pessoa (vale o padrão), o fundo animado, os ajustes de entrada, monitores e atalhos aplicados pelo shell, e a escrita no `settings.lua`. O Hyprland segue com o `settings.lua` que já existia.
- Produces (`SafeModeBanner`): uma pílula `WlrLayer.Overlay` no topo de cada tela, namespace `lucerna-safe-mode`. Diz "O Lucerna está no modo de segurança" e tem os botões "Reiniciar normalmente" (`lucerna-session shell restart`) e "Ver o registro" (abre o terminal com `less` no último log). Só com `Config.safeMode`.
- Produces (`Session`):
  - `lockMarker` (`$XDG_RUNTIME_DIR/lucerna/locked`): criado no `lock()` e apagado no `unlock()`;
  - `restoreLock(markerExists: bool): void`, chamada ao iniciar: com a marca, `lock()`.
- Produces (`LucernaSession.notices`), com `crash.json`:
  - `{ summary: "O Lucerna reiniciou depois de uma falha", body: "O registro está em <log>." }`;
  - com `safe`, o resumo vira "O Lucerna está no modo de segurança" e o corpo acrescenta "Ele caiu várias vezes seguidas; as suas personalizações estão desligadas até reiniciar normalmente.".
  - O `crash.json` é apagado depois de lido.

- [ ] **Step 1: Testes que falham:**
  - `ci/tests/test_session.py`, com um `qs` falso que lê de um arquivo o código de saída de cada partida e grava o ambiente, e um `hyprctl` falso controlado por arquivo:
    - `test_isolated_crash_restarts_after_first_delay`;
    - `test_delays_grow_1_2_4` (atrasos de teste `0.1 0.2 0.4`, conferidos pelas linhas do log do supervisor);
    - `test_fourth_crash_in_window_goes_safe` (a 5ª partida tem `LUCERNA_SAFE_MODE=1`);
    - `test_crashes_outside_window_do_not_accumulate`;
    - `test_safe_mode_crashes_open_emergency`;
    - `test_compositor_gone_stops_without_restart`;
    - `test_hold_does_not_count_as_crash` (`shell stop` e depois `shell start`: o contador continua 0);
    - `test_crash_json_written`;
    - `test_reports_keep_last_five`;
    - `test_qs_runs_without_qt_scale_factor`;
    - `test_status_unsupervised_without_pid`.
  - `tests/session.test.js`: `session: a marca do bloqueio volta a bloquear` (`restoreLock(true)` → `locked`; `restoreLock(false)` não muda; restaura).
  - `tests/lucernasession.test.js`: `lucernasession: aviso da queda e do modo de segurança`.
- [ ] **Step 2:** `dev/ci.sh rules unit` → falha.
- [ ] **Step 3:** implementar e atualizar o `tests/coverage.json` (`Session`: `restoreLock`).
- [ ] **Step 4:** `dev/test.sh` e o bench passam pelo supervisor:
  - `start_shell` e `restart` usam `lucerna-session shell restart` quando o `shell status` diz `supervised`;
  - no modo `LUCERNA_TEST_HOST_BUS=1`, `shell stop` e o `qs` à mão, como hoje;
  - o `bench-paineis.sh` faz `shell stop` antes do `qs` com o log e `shell start` no `trap`, em vez do `setsid -f qs`.
- [ ] **Step 5:** `dev/ci.sh lint rules unit` → verde.
- [ ] **Step 6: Conferir no container:**
  - um `pkill -SEGV -x qs` → o shell volta em ~1 s, com a notificação da queda (captura);
  - quatro quedas seguidas (um laço que espera o `qs` novo e o mata) → a pílula do modo de segurança (captura). "Reiniciar normalmente" volta ao normal, e o `config.json` da pessoa continua intacto (`md5sum` antes e depois);
  - `ipc session lock`, captura, `pkill -SEGV -x qs` e captura durante e depois da volta. **Esperado:** em nenhum quadro a área de trabalho aparece (a tela do Hyprland "lockdead" no intervalo, depois o bloqueio do shell), e `ipc session isLocked` → true;
  - bloqueado, `shell stop` e `lucerna-session unlock`: anote se desbloqueia (e corrija a Tarefa 5 se não). Depois, `shell start`.
  - **Se a sessão aparecer desbloqueada em algum quadro, pare e reporte ao controlador.**
- [ ] **Step 7: Commit** `Sessão: o supervisor com pausa crescente, modo de segurança e volta bloqueada`.

### Task 7: A tela de emergência e o Ctrl+Alt+Delete

**Files:**
- Create: `session/emergency/shell.qml`
- Modify: `session/bin/lucerna-session` (`emergency`, `power`, `poweroff`, `reboot`), `session/lib/supervise.sh` (chama a emergência de verdade), `ci/tests/test_session.py`, `ci/lint.sh` (o `qmllint` também nesse arquivo, sem os módulos do shell)

**Interfaces:**
- Produces (`session/emergency/shell.qml`): config própria do Quickshell, rodada com `qs -p`. Importa só `QtQuick`, `QtQuick.Layouts`, `Quickshell`, `Quickshell.Io` e `Quickshell.Wayland`; nada do shell, nem tema, fontes de ícone ou serviços.
  - Um `PanelWindow` por tela, em `WlrLayer.Overlay`, véu escuro e `keyboardFocus: Exclusive`, com um cartão no centro.
  - O modo vem de `LUCERNA_EMERGENCY_MODE`:
    - `crashed`: título "O Lucerna não conseguiu iniciar", texto "O shell caiu várias vezes seguidas, também no modo de segurança.", e as últimas 30 linhas do último log num texto rolável;
    - `power`: título "Energia e sessão".
  - Botões, cada um por `lucerna-session <subcomando>` em `execDetached`:
    - Tentar de novo (`shell start`; só no `crashed`; fecha a janela);
    - Abrir um terminal (`open terminal`);
    - Ver o registro (o terminal com `less` no log);
    - Desligar (`poweroff`), Reiniciar (`reboot`), Sair da sessão (`logout`);
    - Fechar (só no `power`).
  - Esc fecha no `power`. Setas e Enter navegam (funciona sem mouse).
  - `IpcHandler { target: "emergency" }` com `press(id: string)` (`retry|terminal|log|poweroff|reboot|logout|close`) e `state(): string` (o modo), para a conferência.
- Produces (`lucerna-session`):
  - `emergency [--mode crashed|power]`: `qs -p $DATA/emergency/shell.qml`, com o modo no ambiente. Se ele sair em menos de 2 s, o recurso é `hyprctl eval 'hl.notification.create({ text = "O Lucerna não conseguiu iniciar. <Mod>+Enter abre um terminal; Ctrl+Alt+Shift+Esc sai da sessão. Registro: <log>", timeout = 0 })'`;
  - `power`: `timeout 2 qs -c lucerna ipc call panels open power`; se falhar (shell morto ou travado), `emergency --mode power`;
  - `poweroff|reboot`: com `LUCERNA_DEV=1`, só registra e manda `notify-send` ("…: ação simulada."). Senão, `systemctl poweroff|reboot` com systemd, ou `loginctl poweroff|reboot` sem.

- [ ] **Step 1: Testes que falham** (`ci/tests/test_session.py`):
  - `test_power_uses_shell_menu_when_alive`;
  - `test_power_falls_back_to_emergency` (o `qs ipc` falso sai com 1 → o `qs -p …emergency…` falso é chamado com `LUCERNA_EMERGENCY_MODE=power`);
  - `test_emergency_falls_back_to_notification` (o `qs` falso sai na hora → `hyprctl eval` com `hl.notification.create`);
  - `test_poweroff_simulated_in_dev`;
  - `test_poweroff_without_systemd_uses_loginctl`.
- [ ] **Step 2:** `dev/ci.sh rules` → falha.
- [ ] **Step 3:** implementar.
- [ ] **Step 4:** `dev/ci.sh lint rules unit` → verde.
- [ ] **Step 5: Conferir no container:**
  - `lucerna-session power` com o shell vivo → o menu de energia do shell;
  - com `shell stop`, a tela de emergência de energia (captura), e `ipc` da emergência `press close`;
  - o laço de quedas da Tarefa 6 até passar do modo de segurança → a tela "O Lucerna não conseguiu iniciar" (captura). "Tentar de novo" (`press retry`) volta ao shell normal; "Desligar" só simula (notificação);
  - com `qs -p` quebrado de propósito (`LUCERNA_DATA_DIR` apontando para uma pasta sem a emergência), a notificação do Hyprland (captura).
- [ ] **Step 6: Commit** `Sessão: a tela de emergência sem o shell e o Ctrl+Alt+Delete`.

### Task 8: As unidades do systemd e a entrada no gerenciador de login

**Files:**
- Create: `session/systemd/lucerna-shell.service`, `session/systemd/lucerna-session.target`, `session/wayland-sessions/lucerna.desktop`, `ci/tests/test_units.py`

**Interfaces:**
- `lucerna-session.target`: `[Unit] Description=Lucerna: a sessão gráfica`, `BindsTo=graphical-session.target`, `Wants=graphical-session-pre.target lucerna-shell.service`, `After=graphical-session-pre.target`.
- `lucerna-shell.service`:
  - `[Unit]`: `Description=Lucerna: o shell`, `PartOf=graphical-session.target`, `After=graphical-session.target`, `Requisite=graphical-session.target`;
  - `[Service]`: `ExecStart=/usr/bin/lucerna-session supervise`, `Restart=on-failure`, `RestartSec=1`, `Slice=session.slice`.
  - A política de quedas é do supervisor (Arquitetura); o systemd só cobre a queda do próprio supervisor.
- `lucerna.desktop`: `[Desktop Entry] Name=Lucerna`, `Comment=A sessão do Lucerna sobre o Hyprland`, `Exec=lucerna-session`, `Type=Application`, `DesktopNames=Hyprland`.

- [ ] **Step 1: Teste que falha** (`ci/tests/test_units.py`, `configparser` com `strict=False` e `interpolation=None`):
  - `test_shell_service_restarts_the_supervisor`;
  - `test_target_binds_graphical_session`;
  - `test_desktop_entry_runs_lucerna_session`;
  - `test_exec_paths_match_install_layout` (o `ExecStart` aponta para `/usr/bin/lucerna-session`, que é o destino de `session/bin/lucerna-session` na tabela das Global Constraints, repetida como constante no teste).
- [ ] **Step 2:** `dev/ci.sh rules` → falha, depois implementar e → verde.
- [ ] **Step 3:** no container, `systemd-analyze verify --user` nos dois arquivos, com um `lucerna-session` falso em `/tmp` (`--root`, se a versão aceitar). Anote o resultado; o teste de verdade fica para a máquina real (Pendências, Tarefa 15).
- [ ] **Step 4: Commit** `Sessão: a unidade do shell no systemd do usuário e a entrada no login`.

### Task 9: O bloqueio pelo logind (antes de dormir, `loginctl`, inibidor)

**Files:**
- Create: `services/Logind.qml`, `tests/logind.test.js`
- Modify:
  - `services/Session.qml`, `features/lockscreen/state/LockscreenState.qml`, `features/lockscreen/ui/Lockscreen.qml`;
  - `ci/smoke.sh` (fase `logind`), `ci/packages/smoke.txt` (`python-gobject`);
  - `tests/session.test.js`, `tests/coverage.json`

**Interfaces:**
- Produces (`Logind`, serviço):
  - `readonly property string busOverride: Quickshell.env("LUCERNA_LOGIND_BUS") ?? ""`;
  - `readonly property bool enabled: !DevMode.active || busOverride !== ""` (desligado, um `console.info` uma vez);
  - `property string sessionPath`: do `gdbus call … --method org.freedesktop.login1.Manager.GetSession "${XDG_SESSION_ID:-auto}"`, lido pela `parseObjectPath`;
  - `property bool lidClosed`, `property bool holding`;
  - `signal lockRequested()`, `signal unlockRequested()`, `signal prepareForSleep(start: bool)`;
  - `parseLine(line: string, sessionPath: string): var`: `null` ou `{ kind: "lock"|"unlock"|"sleep"|"lid", value: bool }`. Lê o formato do `gdbus monitor`, guardado na Tarefa 2;
  - `parseObjectPath(text: string): string` (de `(objectpath '/org/…',)`);
  - `holdSleep(): void`: liga o `Process` do inibidor, `[<systemd-inhibit|elogind-inhibit>, "--what=sleep", "--mode=delay", "--who=Lucerna", "--why=Bloquear a tela antes de dormir", "sleep", "infinity"]`, com `DBUS_SYSTEM_BUS_ADDRESS` = `busOverride` quando há. A ferramenta é achada uma vez por `command -v`; sem nenhuma, avisa e segue sem inibidor;
  - `releaseSleep(): void`: para o processo; `holding` falso;
  - `setLockedHint(on: bool): void` (`gdbus call … SetLockedHint`).
  - O `gdbus monitor` (`--address` ou `--system`, `--dest org.freedesktop.login1`) passa por um `SplitParser` para a `parseLine`. Se sair, volta com espera de 1 s dobrando até 30 s.
- Produces (`Session`):
  - `property bool secure` e `setSecure(on: bool): void`, chamada pelo `LockscreenState` a partir do `WlSessionLock.secure` do `Lockscreen.qml`;
  - `onSleep(start: bool): void`. Com `start`: `lock()` e, se já `secure`, `Logind.releaseSleep()`; senão marca `sleepPending`, e o `secure` verdadeiro solta. Sem `start`: `Logind.holdSleep()`;
  - `lockRequested` → `lock()`; `unlockRequested` → `unlock()`. O `loginctl unlock-session` desbloqueia, como no GNOME e no KDE: não é uma falha, e serve de saída pelo TTY com o shell vivo;
  - `secure` verdadeiro → `setLockedHint(true)`; `unlock()` → `setLockedHint(false)`;
  - ao iniciar, com `Logind.enabled`, `holdSleep()`. O `suspend()` fica como está: o inibidor faz a espera em qualquer caminho.

- [ ] **Step 1: Testes que falham:**
  - `tests/logind.test.js`, com as linhas guardadas na Tarefa 2:
    - `logind: Lock da nossa sessão bloqueia e de outra não`;
    - `logind: Unlock`;
    - `logind: PrepareForSleep true e false`;
    - `logind: LidClosed no PropertiesChanged` (com `<true>` e `<false>`; um `PropertiesChanged` sem `LidClosed` → null);
    - `logind: lixo e linha vazia dão null`;
    - `logind: o caminho do GetSession`.
  - `tests/session.test.js`:
    - `session: dormir espera o bloqueio na tela`: `onSleep(true)` com `secure` falso deixa `Logind.holding` verdadeiro; `setSecure(true)` → `holding` falso. Começa com `Logind.holding = true` à mão e restaura;
    - `session: acordar pega o inibidor de novo`;
    - `session: Unlock do logind desbloqueia`.
- [ ] **Step 2:** `dev/ci.sh unit` → falha.
- [ ] **Step 3:** implementar. Entram em `tests/coverage.json`: `Logind`: `["parseLine", "parseObjectPath", "holdSleep", "releaseSleep"]`; `Session`: `setSecure`, `onSleep`.
- [ ] **Step 4: A fase `logind` da fumaça:**
  - `ci/logind-fake.sh start` e o `qs` com `LUCERNA_LOGIND_BUS`;
  - `org.lucerna.Test.Suspend` → `Status` com `lastSleep.timedOut: false` e `lockedHintAtSleep: true`, e `session isLocked` → `true`;
  - `UnlockSession` → `false`; `LockSession` → `true`.
- [ ] **Step 5:** `dev/ci.sh lint rules unit smoke` → verde.
- [ ] **Step 6: Conferir no container:**
  - `logind suspend` com a área de trabalho à mostra: a captura logo depois do `PrepareForSleep` mostra o bloqueio, e `logind status` dá `timedOut: false` com `releasedMs` menor que 2000;
  - `logind lock` e `logind unlock`;
  - com `shell stop`, `logind suspend` → o falso "dorme" em até ~5 s (`timedOut: true` ou nenhum inibidor);
  - `dev/test.sh errs` sem avisos novos.
- [ ] **Step 7: Commit** `Bloqueio: o logind no shell, com o inibidor até o bloqueio estar na tela`.

### Task 10: A tampa com e sem monitor externo

**Files:**
- Modify:
  - `services/Monitors.qml` (`lidPlan`, `setEnabled`), `features/displays/state/DisplaysState.qml`;
  - `core/config/Config.qml` (`lockOnLidDocked: false`);
  - `features/settings/state/SettingsState.qml` ou o estado da página de Energia (onde o `PowerPage` lê os seus), `features/settings/ui/PowerPage.qml`;
  - `tests/monitors.test.js`, `tests/coverage.json`

**Interfaces:**
- Produces (`Monitors.lidPlan(lidClosed: bool, monitors: var, lockOnDocked: bool): var`) → `{ disable: [nomes], enable: [nomes], lock: bool }`.
  - Interno é o nome que casa com `/^(eDP|LVDS|DSI)-/`.
  - Tampa fechada com outro monitor ativo: desliga o interno, e `lock` = `lockOnDocked`.
  - Tampa fechada sem outro: nada (o logind decide e, ao suspender, a Tarefa 9 bloqueia).
  - Tampa aberta, ou nenhum monitor ativo sobrando com o interno desligado (o externo saiu com a tampa fechada): `enable` com o interno.
- Produces (`Monitors.setEnabled(name: string, on: bool): void`): `hl.monitor({ output, disabled = !on })` pelo `hyprctl eval`. Ligando, em seguida o `DisplaysState.restore()`.
- O `DisplaysState` reage ao `Logind.lidClosed` e ao `Monitors.monitors` com o `lidPlan`, e chama `Session.lock()` quando `lock`.
- `PowerPage`: um `SettingRow` com `Switch`, "Bloquear ao fechar a tampa com monitor externo", descrição "Desligado, fechar a tampa com um monitor externo ligado só apaga a tela do notebook.". Só aparece com bateria (`Battery.available`), como as outras opções de notebook da página.

- [ ] **Step 1: Testes que falham** (`tests/monitors.test.js`):
  - `monitors: tampa fechada com externo só desliga o interno`;
  - `monitors: com a opção ligada também bloqueia`;
  - `monitors: tampa fechada sem externo não faz nada`;
  - `monitors: tampa aberta religa o interno`;
  - `monitors: o externo saiu com a tampa fechada religa o interno`;
  - `monitors: desktop sem interno ignora a tampa`.
- [ ] **Step 2:** `dev/ci.sh unit` → falha.
- [ ] **Step 3:** implementar (`lidPlan` em `services/Monitors.qml` no `tests/coverage.json`).
- [ ] **Step 4:** `dev/ci.sh lint rules unit` → verde.
- [ ] **Step 5: Conferir no container:**
  - `logind lid on` com o único `WAYLAND-1` (não é interno) → nada muda e a tela não bloqueia;
  - a opção aparece na página de Energia com a bateria falsa do `lucernad` (captura), ou, sem bateria no container, fica registrado que está escondida.
- [ ] **Step 6: Commit** `Bloqueio: a tampa com monitor externo só apaga a tela do notebook`.

### Task 11: Os atalhos padrão com Super e os apps padrão

**Files:**
- Modify:
  - `core/input/ShellShortcuts.qml`, `core/input/InputActions.qml`;
  - `services/Input.qml` (`release` na `bindLua`; `setBinds(list, alsoUnbind)`), `features/input/state/InputState.qml`;
  - `features/settings/state/ShortcutsState.qml`, `features/settings/ui/ShortcutsPage.qml`;
  - `services/LucernaSession.qml` (`detect-apps`, `writeApps`), `core/config/Config.qml` (`defaultApps`);
  - `tests/shellshortcuts.test.js`, `tests/input.test.js`, `tests/inputactions.test.js`

**Interfaces:**
- `ShellShortcuts.defaults` (com `mod` = SUPER, ou ALT no desenvolvimento). Cada tecla ganha o campo opcional `release: bool`, e cada entrada o opcional `base: bool` (a tecla padrão também está na base do Hyprland).
  - **Mudam:**
    - `launcher`: `[{ mods: mod, trigger: mod === "SUPER" ? "SUPER_L" : "ALT_L", release: true }, { mods: mod, trigger: "space" }]`;
    - `settings`: `[{ mods: mod, trigger: "comma" }]`.
  - **Novas, na ordem:**
    - `terminal` (`mod`+`Return`, `base: true`);
    - `close` (`mod`+`q`), `fullscreen` (`mod`+`f`);
    - `workspace-1` … `workspace-9` (`mod`+N), `move-to-1` … `move-to-9` (`mod SHIFT`+N);
    - `focus-left|right|up|down` (`mod`+`left`…), `move-left|right|up|down` (`mod SHIFT`+`left`…);
    - `drag` (`mod`+`mouse:272`), `resize` (`mod`+`mouse:273`).
- `InputActions`, as ações novas:
  - `terminal` (`kind: "hypr"`, `hl.dsp.exec_cmd("lucerna-session open terminal")`, grupo "Apps");
  - `workspace-N` e `move-to-N` (grupo "Áreas de trabalho");
  - `focus-*`, `move-*`, `drag` e `resize` (grupo "Janelas").
  - O Lua de cada uma sai do stub (`hl.dsp.focus({ direction = … })`, `hl.dsp.window.move(...)`, `hl.dsp.window.drag()`/`resize()` com as opções `drag`/`click` do `HL.BindOptions`). Confira a sintaxe no `/usr/share/hypr/stubs/hl.meta.lua` antes de escrever.
- `Input.bindLua`: `release = true` quando o bind tem `release`.
- `Input.setBinds(list: var, alsoUnbind: var)`: desfaz também as teclas de `alsoUnbind`. O `InputState` passa as teclas padrão das entradas com `base: true` que a pessoa mudou.
- `ShortcutsPage`:
  - os grupos acima, e uma seção "Fixos (funcionam sem o shell)" só de leitura: "Ctrl+Alt+Delete: energia e sessão" e "Ctrl+Alt+Shift+Esc: sair da sessão";
  - uma seção "Apps padrão", com três `Select` (Terminal, Navegador, Arquivos). Cada um tem "Automático (<o detectado>)" e os instalados do `lucerna-session detect-apps`. Grava `Config.defaultApps` (`{ terminal: "", browser: "", files: "" }`, "" = automático), e o `LucernaSession.writeApps` escreve o `~/.config/lucerna/apps.conf` (fora do modo de segurança).
- Os atalhos que a pessoa já mudou continuam (o `effective` de hoje). Só os padrões mudam.

- [ ] **Step 1: Testes que falham:**
  - `shellshortcuts: o lançador no Super sozinho, ao soltar` (`defaultKeys("launcher")[0]` tem `release` e `trigger` `SUPER_L` fora do desenvolvimento);
  - `shellshortcuts: Configurações na vírgula, e a mudança antiga em Super+S fica` (`effective({ settings: [{ mods: "SUPER", trigger: "s" }] })` mantém o S com `custom`);
  - `shellshortcuts: as nove áreas de trabalho e as setas`;
  - `input: bind de soltar` (`bindLua([{ key: "SUPER + SUPER_L", lua: "x", release: true }])` contém `release = true`);
  - `input: a tecla da base sai quando o atalho muda` (a `unbindLua` do `alsoUnbind`);
  - `inputactions: as ações novas existem`.
- [ ] **Step 2:** `dev/ci.sh unit` → falha.
- [ ] **Step 3:** implementar.
- [ ] **Step 4:** `dev/ci.sh lint rules unit smoke` → verde (a fumaça usa atalhos? se algum passo quebrar pela troca de padrão, ajuste o passo, explicando).
- [ ] **Step 5: Conferir no container** (`wtype`, com o enchimento do cabeçalho do `dev/test.sh`):
  - Alt sozinho (aperta e solta) → `panels get` com o lançador;
  - Alt+1 e soltar → muda de área e **não** abre o lançador;
  - Alt+vírgula → Configurações;
  - Alt+Q fecha um kitty;
  - mudar o terminal para `foot` nas Configurações → Alt+Enter abre o `foot`;
  - mudar o atalho do terminal para Alt+T → Alt+Enter não abre mais nada (a tecla da base saiu).
  - **Se o soltar do Alt disparar depois de Alt+1, pare e reporte ao controlador** com o que o Hyprland faz (opções de bind possíveis), sem trocar o padrão.
- [ ] **Step 6: Commit** `Atalhos: os padrões com Super, o lançador no Super sozinho e os apps padrão`.

### Task 12: O shell alinhado ao pixel na escala fracionária

**Files:**
- Create: `core/pixel/Pixel.qml`, `tests/pixel.test.js`
- Modify:
  - `core/widgets/shaders/frame.frag` (`fwidth`) e o `.qsb` regerado (`dev/shaders.sh`);
  - os componentes de `core/widgets/` com borda de 1 px (`Surface`, `FrameShape`, `NotificationCard`, `SearchBox` e o que o `grep -rn "border.width" core features` achar);
  - as posições dos painéis da moldura e dos centralizados (`Frame.qml`, `OverlayPanel.qml`);
  - `Lucerna — Pendências.md` (marca o item da borda borrada)

**Interfaces:**
- Produces (`Pixel`, singleton em `core/pixel`):
  - `snap(v: real, dpr: real): real` = `Math.round(v * dpr) / dpr`;
  - `hairline(dpr: real): real` = `Math.max(1, Math.round(dpr)) / dpr` (exatamente 1 px físico em 1,25, e 2 em 2).
- O `dpr` de cada janela vem do que o Quickshell 0.3.2 expõe (`QsWindow.devicePixelRatio` ou `Screen.devicePixelRatio`). Confira com um `console.log` no container em 1,25 antes de espalhar.
- Bordas de 1 px viram `Pixel.hairline(dpr)`. O `x`/`y` de painéis e da moldura passam pelo `Pixel.snap`.
- `frame.frag`: a suavização usa `fwidth(d)` no lugar da largura fixa de 1 px lógico.

- [ ] **Step 1: Testes que falham** (`tests/pixel.test.js`):
  - `pixel: snap em 1,25` (`snap(10, 1.25)` = 10.4, `snap(10.4, 1.25)` = 10.4, `snap(7, 1)` = 7);
  - `pixel: linha de um pixel físico` (`hairline(1)` = 1, `hairline(1.25)` = 0.8, `hairline(1.5)` = 2/1.5, `hairline(2)` = 1).
- [ ] **Step 2:** `dev/ci.sh unit` → falha.
- [ ] **Step 3:** implementar e aplicar.
- [ ] **Step 4:** `dev/ci.sh lint rules unit smoke` → verde (`rules` confere o `.qsb` regerado).
- [ ] **Step 5: Conferir no container:**
  - as capturas e os recortes da Tarefa 1 em 1,25 e 1,5, comparados lado a lado: a borda da forma e a do cartão com 1 px físico nítido, e o texto sem meio pixel;
  - o `bench-paineis.sh` em 1,25 não piora em relação à base de 1,25 (tolerância de ±1 ponto de CPU e de FPS).
- [ ] **Step 6: Commit** `Escala: o shell alinhado ao pixel físico em escala fracionária`.

### Task 13: A escala interna do shell

**Files:**
- Modify:
  - `core/theme/ThemeManager.qml` (`scale`, `px`, os tokens), `core/config/Config.qml` (`shellScale: 1`);
  - `features/settings/ui/AppearancePage.qml` (o tamanho) e o estado dela;
  - os `.qml` de `features/*/ui` e de `core/widgets` com medidas literais;
  - `ci/rules.py` (regra `medidas`), `ci/tests/test_rules.py`, `tests/theme.test.js`

**Interfaces:**
- Produces (`ThemeManager`):
  - `readonly property real scale: Config.shellScale * (Config.scaleMode === "apps" ? Config.appsScale : 1)` (o `scaleMode` e o `appsScale` entram aqui na `Config` com os padrões `"monitor"` e `1.25`; a Tarefa 14 os usa);
  - `px(v: real): int` = `Math.round(v * scale)`;
  - `font.*`, `spacing.*`, `radius.*`, `barHeight` e o tamanho dos ícones passam pelo `px`. O `Frame.thickness`, se for medida de tema, também.
- `AppearancePage`: "Tamanho do shell", um `SegmentedControl` com 100%, 110%, 125% e 150% → `Config.shellScale` (1, 1.1, 1.25, 1.5). A descrição diz: "Aumenta o shell sem mudar a escala do monitor."
- Regra `medidas` (`ci/rules.py`), em `features/*/ui/*.qml` e `core/widgets/*.qml`:
  - violação: uma linha `^\s*(width|height|implicitWidth|implicitHeight|font\.pixelSize|radius|spacing|(anchors\.)?\w*[mM]argin|size):\s*\d+(\.\d+)?\s*$` com valor ≥ 2;
  - aceito com o comentário `// px fixo: <motivo>` na mesma linha (ex.: tamanho de miniatura em pixels da imagem).
- A varredura troca cada literal por `ThemeManager.px(n)`. Medidas que vêm do Hyprland (geometria de janelas, telas) não mudam.

- [ ] **Step 1: Testes que falham:**
  - `ci/tests/test_rules.py`: `test_medidas_flags_literal_width`, `test_medidas_accepts_px_and_comment`, `test_medidas_ignores_zero_one_and_state`;
  - `tests/theme.test.js`: `theme: a escala interna multiplica as medidas` (`Config.shellScale = 1.25` → `spacing.normal` 15, `font.normal` 16, `px(34)` 43; restaura).
- [ ] **Step 2:** `dev/ci.sh rules unit` → falha (a regra acha as ~180 linhas de hoje).
- [ ] **Step 3:** implementar o `ThemeManager`, a página e a regra; fazer a varredura feature por feature até a regra passar.
- [ ] **Step 4:** `dev/ci.sh lint rules unit smoke` → verde.
- [ ] **Step 5: Conferir no container:**
  - monitor em 1 com `shellScale` 1,25 e monitor em 1,25 com `shellScale` 1: capturas da barra, do painel superior, da central, das Configurações e do lançador. **Esperado:** mesmas proporções, nitidez igual ou melhor no primeiro;
  - `shellScale` 1 em monitor 1 sem diferença visível para a base da Tarefa 1 (captura com a mesma diferença por pixel ≈ 0 na barra).
- [ ] **Step 6: Commit** `Escala: a escala interna do shell pelas medidas do tema`.

### Task 14: "Escala pelos apps" (o modo leve)

**Files:**
- Create: `services/AppsScale.qml`, `tests/appsscale.test.js`
- Modify:
  - `features/settings/state/MonitorsState.qml`, `features/settings/ui/MonitorsPage.qml`;
  - `features/displays/state/DisplaysState.qml` (monitores em 1 no modo), `features/themeSwitcher/state/ThemeSwitcherState.qml` (bordas e arredondamento do Hyprland pelo fator);
  - `services/HyprFile.qml` (seção `scale`), `services/Monitors.qml`;
  - `tests/coverage.json`

**Interfaces:**
- Produces (`AppsScale`, serviço; as funções puras testadas):
  - `envFor(f: real): var` → `{ QT_SCALE_FACTOR, GDK_SCALE, GDK_DPI_SCALE, XCURSOR_SIZE, HYPRCURSOR_SIZE }`. `GDK_SCALE` = `f >= 2 ? Math.floor(f) : 1`; `GDK_DPI_SCALE` = `f / GDK_SCALE` (4 casas); cursor = `Math.round(24 * f)`. Com `f === 1`, `{}`.
  - `sessionEnvText(env: var): string`: um `CHAVE=valor` por linha, com o cabeçalho de arquivo gerado. É o `~/.config/lucerna/session.env`, que o `lucerna-session` lê no login (Tarefa 5).
  - `hyprLua(f: real, hypr: var): string`, a seção `scale`:
    - `lucerna_scale_mode = "apps"`;
    - um `hl.env(...)` por variável;
    - `hl.config({ xwayland = { force_zero_scaling = true }, general = { border_size, gaps_in, gaps_out }, decoration = { rounding } })`, com os valores da base (2, 4, 10) e do tema multiplicados por `f` e arredondados.
  - `flagsText(existing: string, f: real): string`: tira a marca `# lucerna: escala pelos apps` e a linha seguinte; com `f > 1`, acrescenta a marca e `--force-device-scale-factor=<f>`. Sem a marca, o resto fica igual.
  - `gtkIniText(existing: string, f: real, original: var): string`: põe `gtk-xft-dpi=<round(96*1024*f)>` na seção `[Settings]` (cria a seção se faltar), sem mexer no resto. Com `f === 1`, devolve o valor `original` (ou tira a chave se não havia).
  - `xresourcesText(f: real): string` → `Xft.dpi: <round(96*f)>`.
  - `apply(f: real): void` e `restore(): void`:
    - escrevem o `session.env`, os `~/.config/{electron,chromium,chrome}-flags.conf`, os `~/.config/gtk-{3,4}.0/settings.ini` e o `~/.config/lucerna/Xresources`, cada arquivo com `.lucerna-bak` antes da primeira mudança;
    - guardam os valores originais em `~/.config/lucerna/scale-backup.json`;
    - rodam `xrdb -merge` se houver `xrdb` e `hyprctl setcursor <tema> <tamanho>`;
    - chamam `HyprFile.setSection("scale", …)` e o `hyprctl eval` da mesma seção.
    - No modo de segurança, nada.
- `MonitorsState`/`MonitorsPage`:
  - um `SegmentedControl` "Escala do monitor" | "Escala pelos apps" → `Config.scaleMode`;
  - no modo apps:
    - um `Select` de fator (1, 1.25, 1.5, 1.75, 2) → `Config.appsScale`;
    - o controle de escala de cada monitor desabilitado, mostrando 1;
    - os monitores aplicados em 1;
    - o aviso, com este texto: "Um fator só para todos os monitores. Os apps abertos antes continuam como estavam até serem reabertos, e o ambiente da sessão vale por inteiro depois de sair e entrar. O Firefox tem ajuste próprio (layout.css.devPixelsPerPx); apps que não seguem nenhum desses ajustes ficam pequenos." Sem o `xrdb`, acrescenta: "Sem o xrdb, os apps X11 ficam sem o ajuste das fontes.".
  - Voltar a "Escala do monitor" chama `restore()` e reaplica o arranjo salvo.
- O próprio shell não usa esse ambiente: o supervisor já tira o `QT_SCALE_FACTOR` (Tarefa 6), e a escala dele é a interna (Tarefa 13).

- [ ] **Step 1: Testes que falham** (`tests/appsscale.test.js`):
  - `appsscale: ambiente em 1,25` (`QT_SCALE_FACTOR` 1.25, `GDK_SCALE` 1, `GDK_DPI_SCALE` 1.25, cursor 30);
  - `appsscale: ambiente em 2` (`GDK_SCALE` 2, `GDK_DPI_SCALE` 1);
  - `appsscale: em 1, nada`;
  - `appsscale: flags acrescenta e tira só a nossa linha` (com uma linha `--enable-features=X` da pessoa que fica, e idempotente);
  - `appsscale: gtk ini mescla e devolve o original`;
  - `appsscale: a seção do Hyprland` (contém `force_zero_scaling = true`, `border_size = 3` com `f` 1,25 e borda 2, e `lucerna_scale_mode = "apps"`).
- [ ] **Step 2:** `dev/ci.sh unit` → falha.
- [ ] **Step 3:** implementar (as funções puras de `AppsScale` no `tests/coverage.json`).
- [ ] **Step 4:** `dev/ci.sh lint rules unit` → verde.
- [ ] **Step 5: Conferir no container:**
  - modo apps com 1,25 → `hyprctl monitors -j` com escala 1;
  - `cat ~/.config/lucerna/session.env`, `hyprctl getoption general:border_size` (3);
  - um kitty novo com `QT_SCALE_FACTOR=1.25` no `/proc/<pid>/environ`;
  - a página com o aviso (captura); o shell em 1,25 interno (captura comparada com a Tarefa 13);
  - um `chromium-flags.conf` de teste com uma linha própria: a linha fica, a nossa entra e sai;
  - de volta a "Escala do monitor": tudo restaurado (`diff` com os `.lucerna-bak`).
- [ ] **Step 6:** o bench em monitor 1 + modo apps 1,25, para a Tarefa 15.
- [ ] **Step 7: Commit** `Escala: o modo "Escala pelos apps", com os ajustes de cada toolkit`.

### Task 15: Medição final, Pendências dos dois repositórios, fumaça e PR

**Files:**
- Create: `docs/superpowers/bench/2026-11-04-escala-final.txt`
- Modify: `Lucerna — Pendências.md`; no `~/Documentos/projetos/lucernad`, `lucernad — Pendências.md` (branch própria lá)

- [ ] **Step 1:** `dev/ci.sh lint rules unit smoke` → verde.
- [ ] **Step 2: Medição final:** os dois benches em 1, 1,25 (escala do monitor) e 1 + modo apps 1,25, duas rodadas, com o mesmo blur e o mesmo tamanho da base. Grave uma tabela base × final por caso.
  - **Critério:** em 1,25, o `FPS shell`, o `FPS mín` e o `qs %` na faixa da escala 1 (±1 ponto). Nada pior que a base da mesma escala. Os `parado*` com 0 a 2 quadros.
  - O que for custo do Hyprland (o `Hyprland %` maior em 1,25 sem mudança no `qs`) fica medido e vai para as Pendências.
  - **Se algum caso do shell piorar, pare e reporte ao controlador com a tabela.**
- [ ] **Step 3: Pendências do shell:**
  - marcar `[x]` no "O shell volta sozinho se cair", no "Bloqueio confiável" e no item da borda borrada do marco 1, com o resumo e a branch;
  - registrar o que fica para a máquina real (marco 7):
    - as unidades do systemd de verdade (`systemd-analyze verify` e a queda do supervisor);
    - o logind real (tampa, `loginctl lock-session`, suspender pelo botão) e o elogind;
    - NVIDIA e híbrida de verdade, com o `nvidia-drm.modeset`;
    - o Super sozinho com o teclado real;
    - os caminhos dos arquivos de flags do Electron em cada distro e o `xrdb` ausente;
    - o custo medido do Hyprland em 1,25;
  - acrescentar ao marco 6 a tabela de caminhos instalados das Global Constraints;
  - registrar as sobras da revisão final.
- [ ] **Step 4: Pendências do `lucernad`:** numa branch `docs/bloqueio-no-shell` de lá, no item "Bloqueio confiável pelo logind", registrar a decisão: fica no shell (`services/Logind.qml`), sem módulo no daemon. Motivo: um só caminho, e o shell bloqueia sem o daemon. Marcar `[x]` com a referência ao PR do shell. Commit `Pendências: o bloqueio pelo logind fica no shell`, push e PR (conta `EduardoSA8006`).
- [ ] **Step 5:** a revisão final da branch (Opus) e as sobras dela nas Pendências.
- [ ] **Step 6: Commit** `Bench: a medição final da escala e as Pendências da base robusta`, `git push` e o PR (`gh pr create`, conta `EduardoSA8006`, org `lucerna-desktop`). No corpo:
  - a tabela base × final;
  - as capturas (modo de segurança, emergência, bloqueio depois da queda, os dois modos de escala);
  - o que fica para a máquina real.
