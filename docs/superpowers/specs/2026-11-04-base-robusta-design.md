# A base robusta: sessão pronta em qualquer máquina, recuperação e bloqueio confiável

**Data:** 2026-11-04
**Repositórios:** `lucerna-shell` (principal) e `lucernad` (bloqueio pelo logind, se o desenho do construtor puser lá)
**Marco:** 1 do "Roteiro até o uso diário" em `Lucerna — Pendências.md` (seção "Em ordem").
**Referências:** a triagem de 2026-11-04 (`triagem-dia-a-dia.md` no scratchpad da sessão; resumida no roteiro das Pendências); o `dev/hyprland.lua` do container (o único Hyprland config que existe hoje, com Alt como tecla principal).

## Por quê

O usuário quer trocar a sessão KDE pelo Lucerna no dia a dia, e o Lucerna será usado por todo tipo de usuário, em qualquer hardware. Hoje não dá para entrar numa sessão Lucerna de verdade: não há configuração padrão do Hyprland, o shell é iniciado uma vez só (`exec_cmd`) e não volta se cair (se cair com a tela bloqueada, a sessão trava), e a tela nem sempre bloqueia (fechar a tampa, suspender por fora ou `loginctl lock-session` não bloqueiam; no suspender do próprio shell a máquina pode dormir antes de a tela de bloqueio aparecer).

## Princípio

O shell lida com **qualquer usuário e qualquer hardware**: notebook ou desktop, tampa fechada, bateria, GPU integrada, dedicada ou híbrida, um ou vários monitores, qualquer conjunto de apps. A máquina do usuário (Acer Nitro AN515-57: Intel na tela de 144 Hz, escala 1,25; RTX 3050 no HDMI de um ultrawide 2560x1080@60; Hyprland na Intel) é só um caso de teste.

## Decisões do usuário

### 1. Configuração em três camadas

- **A base do Lucerna**, instalada pelo pacote e só leitura (ex.: `/usr/share/lucerna/hypr/`): os padrões para qualquer máquina. Atualizar o Lucerna melhora os padrões sem tocar no que é do usuário.
- **As Configurações**: o que a pessoa muda pela interface do shell vai para um arquivo que o shell controla (ex.: `~/.config/lucerna/hypr/`).
- **O arquivo próprio do usuário** (`~/.config/hypr/hyprland.lua`), carregado por último, para o avançado. O shell nunca escreve nele.

### 2. Pronto ao entrar, sem configurar nada

- **Monitores:** cada um no modo preferido e na maior taxa de atualização; escala calculada pelo tamanho físico da tela (decisão minha, ver abaixo); depois, ajuste pela página de Monitores (que já existe).
- **Teclado:** o layout do sistema (o mesmo do instalador e do console, pelo `localed`/`/etc/vconsole.conf`/X11 keymap do sistema). Touchpad com toque para clicar e rolagem natural.
- **Placa de vídeo:** um script de entrada da sessão, `lucerna-session`, detecta o hardware: com NVIDIA, liga as variáveis de ambiente necessárias e avisa (notificação ao entrar) se o `nvidia-drm.modeset` estiver desligado; em máquina híbrida, deixa a integrada desenhar a tela.
- **Atalhos padrão** (Super como tecla principal), todos listados nas Configurações e trocáveis por lá:
  - Super sozinho: lançador de apps; Super+Enter: terminal; Super+Q: fechar a janela; Super+F: tela cheia; Super+L: bloquear.
  - Super+1…9: ir ao workspace; Super+Shift+1…9: levar a janela; Super+Tab: visão geral.
  - Super+setas: mover o foco; Super+Shift+setas: mover a janela; Super+mouse: arrastar e redimensionar.
  - Super+C: central; Super+V: área de transferência; Super+T: temas; Super+, (vírgula): Configurações; Print: captura.
  - Emergência, fixos na configuração do próprio Hyprland (funcionam com o shell morto): Ctrl+Alt+Delete: menu de energia; Ctrl+Alt+Shift+Esc: encerrar a sessão (volta à tela de login).
  - O Alt como tecla principal fica só no container de teste (o KDE do host captura o Super).
- **Apps padrão:** terminal, navegador e gerenciador de arquivos detectados entre os instalados (ex.: kitty, foot, Alacritty, Konsole; Firefox, Chromium; Dolphin, Nautilus, Thunar), trocáveis nas Configurações.

### 3. O shell volta sozinho

- **Com systemd** (o caso comum): o shell roda como serviço do usuário ligado à sessão gráfica e reinicia em cerca de 1 s se cair.
- **Sem systemd:** um laço no `lucerna-session` faz o mesmo.
- O Hyprland fica configurado para aceitar um novo bloqueio depois de uma queda (`misc:allow_session_lock_restore`): se o shell cair com a tela bloqueada, volta bloqueado.

### 4. Quedas seguidas

1. **Tentar de novo com pausa crescente:** até 3 reinícios em 30 s, esperando 1, 2 e 4 s. Uma queda isolada nem é notada.
2. **Modo de segurança:** passado o limite, o shell sobe sem as personalizações da pessoa (tema padrão, sem fundo animado, sem os ajustes das Configurações), com uma faixa "O Lucerna está no modo de segurança".
3. **Tela de emergência:** se nem o modo de segurança subir, uma janela mínima, feita **sem o shell** (para não cair junto), diz "O Lucerna não conseguiu iniciar" com: tentar de novo, abrir um terminal, ver o log, sair da sessão.
4. **Atalhos independentes do shell:** abrir terminal e sair da sessão ficam na configuração do Hyprland.
5. **Registro:** depois de voltar, o shell avisa numa notificação que reiniciou após uma falha, com o caminho do log; os últimos relatórios ficam em `~/.local/state/lucerna/shell/`.
6. **A tela bloqueada nunca se abre por uma falha:** se o shell cair bloqueado e não conseguir voltar, a tela continua bloqueada; a saída é desbloquear pelo TTY com a senha.
7. **Fora:** voltar sozinho à versão anterior do pacote (depende de cada distro e pode piorar); a tela de erro pode mostrar como fazer.

Essa sequência segue o padrão de outros softwares (o limite de reinícios do systemd, o DrKonqi e o reinício do plasmashell no KDE, a tela "Oh no! Something has gone wrong" do GNOME, o modo de segurança do Firefox e do Android).

### 5. Bloqueio confiável

- O shell (ou o `lucernad`) ouve o logind: bloqueiam a tela fechar a tampa (sem monitor externo, ver abaixo), suspender por qualquer caminho, `loginctl lock-session` e a inatividade (que já existe).
- Antes de dormir, a suspensão espera a tela de bloqueio aparecer (inibidor de atraso do logind, `PrepareForSleep`), para a máquina nunca dormir com a área de trabalho à mostra.
- A tampa segue a regra do logind. Sem monitor externo, fechar a tampa suspende e bloqueia.
- **Com monitor externo ligado, fechar a tampa não bloqueia nem suspende, só apaga a tela do notebook** (decisão do usuário, 2026-11-04, seguindo o padrão do KDE). É personalizável: uma opção nas Configurações (página de Energia ou de Bloqueio, a critério do construtor) "Bloquear ao fechar a tampa com monitor externo", desligada por padrão.

### 6. Escala fracionária de primeira classe (decisão do usuário, 2026-11-04)

O usuário usa 125% no dia a dia, e muita gente usa escalas fracionárias (1,25, 1,5). O shell precisa funcionar nelas **sem quebrar nada e otimizado**, com o mesmo desempenho e nitidez da escala 1. No Hyprland, 1,25 é conhecido por pesar; causas prováveis, a confirmar por medição:

- **Apps sem o protocolo de escala fracionária** (`wp-fractional-scale-v1`): desenham em 2x e o compositor reduz para 1,25 a cada quadro — (2/1,25)² ≈ 2,6 vezes mais pixels que o necessário, mais a passada de redução.
- **XWayland:** os apps X11 desenham em 1x e são ampliados (borrados) ou, com ajuste, desenham em escala própria.
- **Geometria não inteira:** posições e tamanhos lógicos não caem em pixels inteiros; as áreas de redesenho (dano) são arredondadas para fora e crescem, e o desfoque é refeito sobre mais pixels. Bordas de 1 px e textos caem entre pixels e borram (já há o item "borda borrada na escala 1,25" nas Pendências).
- Otimizações que o Hyprland desliga ou perde em escala não inteira (ex.: envio direto ao monitor de uma janela em tela cheia).

Exigências:
- O shell desenha na escala exata (Qt 6 com o protocolo fracionário), com bordas, linhas e ícones alinhados ao pixel físico, sem borrar.
- A base do Hyprland traz os ajustes que evitam o pior para os apps: XWayland sem ampliação borrada (`xwayland:force_zero_scaling` e as variáveis de escala dos toolkits), Electron/Chromium em Wayland nativo, Qt e GTK 4 usando o protocolo fracionário.
- **Medição:** o `dev/bench-paineis.sh` e o de desfoque rodam também em 1,25 (o container aceita escala por regra de monitor) e comparam com 1; a meta é a mesma faixa de FPS e CPU da escala 1. O que o shell não controlar (custo do próprio Hyprland) fica medido e registrado nas Pendências.
- A escala inicial pelo tamanho físico (decisão minha, abaixo) é um ponto de partida; quem usa 1,25 escolhe na página de Monitores e o shell respeita.

**Duas formas de escala (decisão do usuário, 2026-11-04, depois de avaliar a sugestão de "monitor em 1 + fontes maiores"):**
- **Escala interna do shell:** o shell ganha um fator de escala próprio, aplicado às medidas do tema (tamanhos, raios, espaçamentos, fontes, ícones), para desenhar em 1,25 com o monitor em 1, nítido e alinhado ao pixel. Vale em qualquer das duas formas abaixo.
- Na página de Monitores, a pessoa escolhe:
  - **Escala do monitor** (padrão): a fracionária do Hyprland, que permite monitores com escalas diferentes.
  - **Escala pelos apps** (modo leve): os monitores ficam em 1 e o próprio shell escreve os ajustes de cada toolkit, sem pacotes extras (lxappearance, qt5ct): Qt (`QT_SCALE_FACTOR`/DPI das fontes no ambiente da sessão), GTK (escala da interface e das fontes pelas configurações do GTK), Electron/Chromium (fator de escala nas flags), XWayland (`Xft.dpi`), cursor e as medidas do Hyprland (bordas, espaços). Aumentar só as fontes não basta: a interface inteira de cada app escala. A página avisa as limitações: um fator só para todos os monitores, e apps que não seguem (o Firefox tem ajuste próprio; apps sem suporte ficam pequenos).
- A medição da primeira tarefa (custo em 1 × 1,25) diz de onde vem o peso e orienta o padrão: se vier dos apps desenhados em 2x e reduzidos, o modo leve ganha força; se vier do Hyprland, fica registrado.

## Objetivos

- Uma pessoa instala o Lucerna, entra na sessão e tem tudo funcionando em qualquer máquina, sem editar arquivo.
- A sessão se recupera sozinha de uma queda do shell, e nunca expõe a área de trabalho com a tela bloqueada.
- Escala fracionária (1,25 e 1,5) tão nítida e leve quanto a escala 1, medida.
- Tudo validável no container `lucerna-polish`: derrubar o shell (uma vez, repetidamente, bloqueado), bloquear por todos os caminhos (logind simulado), simular a detecção de NVIDIA/híbrida e de layout de teclado.

## Não objetivos

- O greeter e a troca do display manager (marco 2, projeto próprio).
- Pacotes e instalação (marco 6); este marco define os arquivos que o pacote vai instalar e onde, mas não o PKGBUILD.
- Bandeja, polkit, autostart, tema dos apps (marco 3).
- Mudanças visuais nos painéis.

## Anti-objetivos

- O shell escrevendo no arquivo do usuário, ou uma atualização apagando o que o usuário configurou.
- Reiniciar sem limite (laço de quedas consumindo a máquina).
- Qualquer caminho em que uma falha desbloqueie a tela.
- Decidir pelo hardware ou pelos hábitos do usuário (a configuração dele é um caso de teste, não o padrão).
- Atalho de emergência que dependa do shell.

## Restrições

- Hyprland 0.56 com configuração em Lua; o shell já aplica ajustes em tempo de execução (`hyprctl eval`/`keyword`) e já tem as páginas de Monitores, Teclado, Mouse, Inatividade e Energia.
- Quickshell/QML, organização feature-first + core + MVVM do repo, regras do `ci/rules.py`, `dev/ci.sh` verde.
- Testes não tocam o hardware real, o D-Bus real do host (o logind do host inclusive), a sessão real do usuário (KDE); verificação no container.
- Nomes novos de comandos, subcomandos e métodos em inglês (`lucerna-session`, por exemplo).
- Os apps do ecossistema funcionam sozinhos; o shell não pode exigir o lucernad para bloquear ou se recuperar (se o bloqueio pelo logind ficar no lucernad, o shell precisa de um caminho próprio quando ele não está).

## Decisões minhas (o usuário pode revisar)

- **Escala pelo tamanho físico:** a escala inicial vem da densidade de pixels (EDID: tamanho em mm), arredondada aos passos que o Hyprland aceita sem borrar (ex.: 1, 1,25, 1,5, 2); na tela do usuário (15,6″, 1920x1080) daria 1,25.
- **Limite de quedas:** 3 em 30 s com 1/2/4 s; o construtor pode ajustar os números se o systemd exigir outra forma, mantendo o comportamento.
- **Ctrl+Alt+Delete:** fica na base do Hyprland e chama `lucerna-session power`, que pede ao shell o menu de energia; se o shell não responder (morto ou travado), abre a tela de emergência (a mesma peça feita sem o shell), que também tem desligar, reiniciar e sair.
- **Atalhos que já existem e não estavam na lista:** ficam (Super+D painel superior, Super+N notificações, Super+A ações, Super+Esc energia, Super+Space como segundo atalho do lançador). O que muda de padrão: o lançador ganha o Super sozinho e as Configurações passam de Super+S para Super+, (vírgula). Atalhos que a pessoa já personalizou são mantidos (só os padrões mudam). Na base do Hyprland ficam só os que precisam funcionar sem o shell (terminal, sair da sessão, Ctrl+Alt+Delete); os do shell continuam aplicados por ele em tempo de execução, como hoje.
- **Sem systemd:** o reinício pelo laço do `lucerna-session` e o bloqueio pelo elogind, que tem a mesma interface D-Bus (`org.freedesktop.login1`), sem caminho de código à parte; o container testa só com o logind simulado, e a limitação fica documentada.

## O que fica para o construtor

- Onde fica a escuta do logind (shell ou lucernad) e como o shell bloqueia sem o lucernad.
- O formato e os caminhos exatos das três camadas, e como as Configurações migram o que hoje aplicam só em tempo de execução para o arquivo controlado.
- Como o `lucerna-session` detecta GPU, layout do teclado e init (systemd ou não), e a unidade systemd do shell.
- Com o que a tela de emergência é feita (precisa funcionar sem o Quickshell do shell).
- O que conta como "personalização" a desligar no modo de segurança.
- Como simular logind, NVIDIA e quedas no container, e os testes de unidade e fumaça.
- Registrar as sobras no arquivo de pendências do repo onde o trabalho acontece.
