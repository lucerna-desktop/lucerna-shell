# Lucerna — Pendências

O que falta fazer no shell, na ordem em que vamos seguir. Cada item vira um PR; ao terminar, ele é marcado aqui.

Cada repositório do ecossistema tem o seu arquivo de pendências na raiz. Até 2026-11-04, os itens do `lucernad` e do `lucerna-sdk` ficavam aqui também; eles passaram para as [Pendências do `lucernad`](https://github.com/lucerna-desktop/lucernad/blob/main/lucernad%20%E2%80%94%20Pend%C3%AAncias.md) e as [Pendências do `lucerna-sdk`](https://github.com/lucerna-desktop/lucerna-sdk/blob/main/lucerna-sdk%20%E2%80%94%20Pend%C3%AAncias.md). Um item que envolve dois repositórios fica onde o trabalho acontece, com uma linha de referência no outro.

## Em ordem

### Roteiro até o uso diário

Decisão de 2026-11-04: **fechar 100% do shell antes dos apps**, para trocar a sessão KDE pelo Lucerna no dia a dia. A troca só acontece quando tudo estiver funcionando no container e não houver mais o que testar só por ele.

O shell é para **qualquer usuário e qualquer hardware**: notebook ou desktop, tampa fechada, bateria, GPU integrada, dedicada ou híbrida, vários monitores, apps variados. A máquina do usuário (Acer Nitro AN515-57: Intel no painel de 144 Hz com escala 1,25 e RTX 3050 no HDMI do ultrawide 2560x1080@60; o Hyprland roda na Intel) é só um caso de teste, nunca a regra: nada do padrão pode depender dela. A triagem que originou o roteiro (itens, estimativas e o roteiro de teste de 9 etapas) é a base dos sub-itens abaixo; `P` é de horas a 1 dia, `M` de alguns dias (um PR) e `G` pede spec próprio e vários PRs.

Os marcos seguem esta ordem; cada um só começa quando o anterior fecha. Os itens numerados de depois (1 a 17) continuam abaixo, com a nota do marco a que pertencem.

- [ ] **Marco 1: base robusta.** Uma sessão que não deixa o usuário na mão.
  - [ ] **Configuração padrão do Hyprland para qualquer máquina** (`hyprland.lua` instalado pelo pacote, com um arquivo do usuário opcional por cima): mod Super, atalhos de janela e de workspaces que não colidem com os do shell, `kb_layout`, terminal, `monitors` pelo arranjo salvo, ambiente da sessão importado para o systemd (`WAYLAND_DISPLAY`, `XDG_CURRENT_DESKTOP=Hyprland`). GPU híbrida (`AQ_DRM_DEVICES` e as variáveis da NVIDIA) como trecho opcional por detecção, nunca fixo. Hoje só existe o `dev/hyprland.lua` (ALT, feito para o aninhado). P–M
  - [ ] **O shell volta sozinho se cair:** unidade de usuário com `Restart=on-failure` e limite de tentativas, aviso "o shell reiniciou", e `misc.allow_session_lock_restore = true` no padrão. Conferir que o `WlSessionLock` reabre bloqueado depois da morte do processo (não só de um reload). Atalhos de pânico do Hyprland (reiniciar o shell, sair da sessão) que funcionam com o `qs` morto. P–M
  - [ ] **Bloqueio confiável:** bloquear ao fechar a tampa, ao suspender de qualquer origem e com `loginctl lock-session`, e **bloquear antes de dormir** (*delay inhibitor* até a superfície do bloqueio estar desenhada; hoje o `systemctl suspend` do shell corre com o desenho). Comportamento da tampa com e sem monitor externo. A parte do daemon está nas [Pendências do `lucernad`](https://github.com/lucerna-desktop/lucernad/blob/main/lucernad%20%E2%80%94%20Pend%C3%AAncias.md) (bloqueio pelo logind). M
  - [ ] **Hibernar sem swap:** esconder o botão quando o logind diz que não dá (`CanHibernate`). P
  - [ ] **Bugs que incomodam todo dia** (seções de sobras e "Depois" abaixo): a **senha do Wi-Fi que some** quando a lista de redes atualiza ("Depois", Central, Wi-Fi), a **barra em repouso desfocando a tela inteira** na bateria ("Sobras do desfoque" e "Sobras dos painéis da moldura"), a borda borrada em escala fracionária (feita na base robusta, Tarefa 12) e o **painel superior parado redesenhando a ~67 fps** (idem). P–M cada
- [ ] **Marco 2: greeter próprio.** greetd com um greeter em Quickshell **no mesmo repositório**, no lugar do SDDM; passa por brainstorming, spec e desenho estático antes de qualquer código. G
  - [ ] **Mesmo visual do shell:** o design do shell, o papel de parede e o fundo animado, e uma **troca animada e rápida para a sessão, sem corte**. A **tela de bloqueio e o greeter são o mesmo componente.**
  - [ ] **Compositor do greeter:** um Hyprland mínimo, só para ele.
  - [ ] **Funções:** escolha de sessão (Lucerna ou KDE), energia, layout do teclado, vários monitores, aviso de Caps Lock e digital pelo PAM.
  - [ ] **Dados do usuário** (tema, papel de parede, avatar, monitores) num lugar que o greeter lê **sem que um usuário possa alterar os de outro**; o AccountsService guarda avatar e fundo.
  - [ ] **Saída de emergência:** roteiro de volta ao SDDM pelo TTY e o `agreety` como greeter de reserva.
- [ ] **Marco 3: integrações com o resto do sistema.** Cada uma com spec curto (a bandeja e o polkit) ou só o ajuste na sessão.
  - [ ] **Bandeja do sistema (StatusNotifierItem)** na barra, com menu (`Quickshell.Services.SystemTray`); Discord e Steam dependem dela. M
  - [ ] **Agente polkit:** subir um agente na sessão (`hyprpolkitagent`, ou o do KDE), e depois um diálogo próprio do shell. P / M
  - [ ] **Autostart XDG** (`~/.config/autostart/*.desktop`); a página "Iniciar com a sessão" das Configurações vem depois. P
  - [ ] **Tema dos apps:** `QT_QPA_PLATFORMTHEME`, tema GTK, cursor e ícones. P
  - [ ] **Notificações persistentes** em disco (hoje só sobrevivem a um reload; liga com a lista vazia depois de um reinício do `qs`, em "Sobras do modo jogo"). M
- [ ] **Marco 4: os projetos já aprovados**, antes da troca: a **dock** (item 13), os **temas por papel de parede** (item 17) e o **equalizador** (item 16). Cada um com o spec e as aprovações dos itens abaixo.
- [ ] **Marco 5: projetos novos.** Cada um começa por brainstorming.
  - [ ] **Gerenciador de senhas próprio**, no lugar do KWallet. Deve implementar `org.freedesktop.secrets` (o Secret Service) para navegadores e apps; é uma decisão do usuário, **a confirmar no brainstorming**, junto com o repositório e a forma (serviço à parte, módulo do `lucernad`, ou o shell só como interface). G
  - [ ] **Compartilhamento de tela e som:** o portal do Hyprland (`xdg-desktop-portal-hyprland` e o seletor de tela e janela) e o áudio do sistema na transmissão. Será detalhado depois. G
- [ ] **Marco 6: pacotes e instalação** (item 14): PKGBUILD e AUR do shell e do `lucernad` (o do daemon está nas Pendências do `lucernad`), versões casadas entre os dois, as dependências do Lucerna (fonte de ícones, portal, agente polkit) e **o roteiro de volta ao KDE** (escolher "Plasma" no login, TTY, desinstalar sem tocar no Plasma; `tar` de `~/.config` antes de começar). M
- [ ] **Marco 7: verificação no hardware real e a troca.** A seção "Verificar com hardware e entrada reais" inteira na máquina de teste do usuário, mais o roteiro de 9 etapas da triagem (instalar sem usar; primeira sessão só no notebook; monitor externo; energia na bateria; integrações; falhas de propósito; jogo e desempenho; uso real com o KDE de reserva), com as correções que saírem dali. Só então o Lucerna vira a sessão padrão (1 a 2 semanas sem voltar ao KDE por necessidade).

Depois dos marcos, sem pressa e sem bloquear a troca: o item 15 (lógica fora do shell), o porte para o KWin e as outras distros (item 14), os apps e os bugs de gravidade média e baixa que a triagem listou.

### Itens numerados

A lista original, com o histórico dos feitos. As notas em itálico dizem a que marco o item pertence.

1. [x] **Proposta atualizada.** A tabela "Escopo" de `Lucerna — Proposta.md` ainda diz que barra, painel e energia estão por fazer e descreve o launcher como só "abrir aplicativos". Faltam monitores, mouse, teclado, papel de parede animado e vídeo.
2. [x] **Launcher: o que hoje só o estilo completo tem.** Fixar nos favoritos e ocultar um app (por clique direito ou atalho) no compacto e na tela cheia. Busca em arquivos e na web também fora do estilo completo (por prefixo ou atalho).
3. [x] **Ociosidade e tela.** Desligar a tela e bloquear depois de X minutos, suspender depois de Y, sem depender do `hypridle` (o Quickshell tem `IdleMonitor`). Com exceções: mídia tocando, app em tela cheia e, no modo apresentação, não apagar.
4. [x] **Luz noturna.** Temperatura de cor por horário (fixo ou pôr e nascer do sol), nos tiles da central e nas configurações.
5. [x] **Temas claros.** Catppuccin Latte e Rosé Pine Dawn, as versões claras oficiais.
6. [x] **Atalhos editáveis.** A página Atalhos das configurações só informa; os atalhos do shell continuam no `hyprland.lua`. Passar a editar ali, reaproveitando os binds da aba Teclado.
7. [x] **Monitores no login.** O arranjo salvo só vale quando o Lucerna inicia, e no login o `hyprland.lua` aparece antes. Opção de gravar o arranjo num arquivo que o `hyprland.lua` inclui.
8. [x] **Histórico da área de transferência**, num painel próprio (`Super+V`).
9. [x] **Captura de tela e gravação:** área, janela ou tela, com notificação e atalho.
10. [x] **Visão geral dos workspaces**, com as janelas em miniatura.
11. [x] **Brilho de monitores externos** por DDC/CI.
12. [x] **Central.** Dois painéis flutuantes na direita, no lugar da barra lateral: ações (tiles com uma página por recurso, inclusive o volume de cada app, e os sliders de volume e brilho) e notificações, independentes (`Super+A`, `Super+N`; os dois com `Super+C`). Mudança de comportamento: `Super+N` (a ação `notifications`) agora abre só as notificações; a central inteira fica em `Super+C`.
13. [ ] **Dock**, com spec próprio. *(Marco 4.)*
14. [ ] **Instalação e distribuição:** script de instalação (link, trecho do `hyprland.lua`, atalhos padrão) e pacote no AUR. A verificação no CI já está feita: quatro checks obrigatórios (`ci/`, `dev/ci.sh`). *(Marco 6; o AUR e as outras distros depois dele.)*
    - **Outras distros** (o Lucerna não depende do Arch, e sim de Hyprland 0.56+, Quickshell 0.3+ e Qt 6 recente; o `lucernad` compila em qualquer distro com PipeWire, D-Bus e logind). Ordem sugerida:
      1. AUR (o shell e o `lucernad`), a base dos outros;
      2. Nix (flake): NixOS e quem usa Nix em qualquer distro, com as versões fixadas (resolve Qt e Hyprland antigos);
      3. Fedora (COPR), a distro grande com Hyprland e Qt em dia;
      4. script de instalação genérico para as outras: compila o que falta e avisa as versões mínimas;
      5. sem systemd (Void, Alpine, Artix): o shell inicia o `lucernad` quando não acha o socket (hoje ele sobe por socket do usuário do systemd).
    - Debian e Ubuntu estáveis ficam para depois (fora o Nix): o Hyprland e o Qt deles costumam estar atrás das versões mínimas.
    - **Porte futuro para o KDE Plasma (KWin)**, só se houver interesse. Referência: o [caelestia-kde](https://github.com/ladybug-me/caelestia-kde), que leva o Caelestia ao KDE com um plugin C++ no Quickshell e um efeito do KWin (GPL-3.0; não reaproveitar o código). No Lucerna, o caminho seria um serviço de compositor no shell e, no `lucernad`, uma implementação para o KWin ao lado da do Hyprland (janelas e áreas de trabalho, atalhos pelo `kglobalaccel`, Night Color, monitores pelo KScreen). Ficam de fora no KWin: bordas e cores do tema nas janelas, lado a lado nativo, áreas de trabalho dinâmicas e a tela de bloqueio própria.
15. [ ] **Lógica fora do shell (Rust).** Ver a seção "Separação da lógica" abaixo. Substitui o plano de plugins em C++ de `Lucerna — Plugins Próprios.md`, que precisa ser revisto à luz dela. *(Depois dos marcos, salvo o que um marco precisar.)*
16. [ ] **Equalizador de áudio**, com spec próprio: muda o som (filtro do PipeWire, `filter-chain`, ou controle do EasyEffects) e mostra o espectro ao vivo atrás das faixas, reaproveitando o módulo de espectro. *(Marco 4.)*
17. [ ] **Temas com mais cores e o papel de parede como escolha**, com spec próprio (projeto aprovado em 2026-10-26). O modelo de tema hoje tem um destaque só (`accent`, 152 usos) e usa 11 das 26 cores do Catppuccin; o ajuste rápido (o Catppuccin com o azul como destaque) já foi feito (PR #51). *(Marco 4.)*
    - **Modelo de cores ampliado**, no estilo do Material 3: primário, secundário e terciário, com os containers e as cores "sobre" cada um; níveis de superfície; estados (erro, sucesso, aviso, informação/link). Revisar onde cada cor entra no shell.
    - **Temas prontos fiéis às paletas oficiais**, sem algoritmo (no Mocha: primário Blue, secundário Mauve, terciário Peach ou Teal, superfícies Base, Mantle, Crust e Surface 0–2).
    - **O papel de parede vira a unidade de escolha:** o `Super+T` passa a ser o carrossel de papéis de parede e troca o fundo e as cores juntos. Cada papel de parede tem o tema definido pelo usuário (opcional) e o tema gerado pelo `lucernad` (Material 3 a partir da imagem, guardado pelo hash do arquivo; num vídeo, por um quadro). O Tab no carrossel alterna entre "seu tema" e "gerado", com a etiqueta no card.
    - **A última escolha fica lembrada por papel de parede**; na primeira vez, os papéis de parede do Lucerna abrem no tema definido e os do usuário, no gerado.
    - Vários papéis de parede por tema (os 13 temas viram papéis de parede prontos); claro/escuro global, com a opção "seguir o horário"; a variante do gerado global (padrão: tonal spot); pastas de papéis de parede; fonte, raios e efeitos vêm do tema definido, e o gerado usa os padrões do Lucerna.
    - Antes de implementar, o usuário aprova a documentação final completa e um desenho estático das telas (o carrossel, a página Aparência etc.), como foi feito com a aba Clima.

## Separação da lógica (a definir melhor)

Decisão (2026-10-18): o shell é só a interface; a lógica vai para código separado, em Rust, num **repositório próprio e público**, com as mesmas configurações do `lucerna-shell` (licença GPL-3.0, CI com checks obrigatórios, ruleset da branch principal, revisão, padrão de commits em português). Ainda falta definir: a forma (um daemon com módulos, como `lucernad`, ou vários binários), o protocolo com o shell (proposta: socket Unix em `$XDG_RUNTIME_DIR` com mensagens JSON e atualizações enviadas pelo daemon, lido pelo `Socket` do `Quickshell.Io`), o empacotamento e a versão do protocolo entre os dois repositórios.

Princípio da migração: cada `services/` do shell mantém as mesmas propriedades e vira um adaptador; com o daemon rodando, lê dele; sem ele, usa a implementação atual. Um módulo por vez, como já está feito com o espectro (o `Spectrum` lê do `lucernad`).

Fica no shell: as APIs nativas do Quickshell (PipeWire, MPRIS, Bluetooth, rede, notificações, PAM, Hyprland), a coordenação dos painéis, os temas, a geometria dos monitores nas configurações, a formatação e as animações.

Os módulos (os feitos e os que faltam: launcher, Hyprland, luz noturna, o `lucerna-video` e a captura de tela) e as sobras de cada um no daemon estão nas [Pendências do `lucernad`](https://github.com/lucerna-desktop/lucernad/blob/main/lucernad%20%E2%80%94%20Pend%C3%AAncias.md). Aqui ficam as sobras do lado do shell.

## Sobras do módulo de espectro

- [ ] Falta um teste do `spectrum.configure` com um player de verdade (os testes só cobrem `null`) e do `onPlayerChanged`.
- [ ] O `Spectrum.available` não tem consumidor fora dos testes.
- [ ] O `applyBands` não confere se as bandas são números.

## Sobras do módulo da área de transferência

- [ ] Falta um teste da ordem do `Component.onCompleted` do `Clipboard` (configurar antes de assinar) com o cliente já conectado.
- [ ] O `onAtYEndChanged` do painel não dispara de novo quando a página somada cabe inteira na tela (a lista não chega a rolar): o "mais" seguinte só vem pelas setas.

## Sobras do módulo de energia e brilho

Adiadas na revisão do shell (PR #50); as do `lucernad` (lucernad#14) estão nas Pendências de lá.

- [ ] O slider recua quando o DDC leva mais de 1 s (o hold acaba antes da publicação final) e avança na publicação.
- [ ] Corrida mínima no `reload` (`power.list`) quando o módulo volta enquanto chega um `power.screens`.
- [ ] Com o lucernad fora desde a partida, os botões de perfil ficam escondidos (o `profilesAvailable` não tem último valor).
- [ ] Um `1003` no meio do arrasto marca a tela com erro e o slider da central passa para a próxima tela.
- [ ] O `busctl` continua na imagem do container (vem do systemd do Arch base), embora o shell não o use mais.

## Sobras do módulo de rede externa

Adiadas na revisão do shell (PR #52); as do `lucernad` (lucernad#17), inclusive o teste do Vagalume na máquina real, estão nas Pendências de lá.

- [ ] O "Hoje" e a data do topo da aba Clima usam a data da máquina, e os dias vêm pela data da cidade: com a cidade em outro fuso, perto da meia-noite, os dois podem divergir.
- [ ] A barra de ações rápidas do Painel não tem navegação pelo teclado (o Tab do painel troca de aba); se fizer falta, as setas.
- [ ] Sem teste do `openLink` (só `https://`) da página Créditos nem do `openSettings` da aba Clima.

## Sobras dos painéis da moldura

Adiadas na revisão final da branch `feat/paineis-moldura` (a barra fundida à moldura e os painéis que saem das bordas).

- [x] **O conteúdo dos painéis na mesma janela da forma** (branch `feat/conteudo-janela-forma`). A forma e o conteúdo da barra, do painel superior, da central, do OSD e dos popups de notificação agora vivem numa janela só por tela (`FrameWindow`, `lucerna-panel-frame`), sempre mapeada, que encolhe a 1 px na borda em repouso e muda só entre quatro níveis (1 px, coluna, coluna larga, tela cheia). O conteúdo desliza com o fundo desde o 1º quadro, as camadas ficam na ordem certa e o teclado vai só com uma entrada `keyboard` ativa (`OnDemand`, nunca `Exclusive`). O caminho antigo (janelas próprias `lucerna-frame-*`, `BarWindow`, `Frame.isReady`, `contentOpacity`) saiu.
- [ ] **A barra revelada pelo mouse custa mais que na `main`.** Com ela, a moldura aparece nos quatro lados, e a janela da forma ocupa a tela toda: o Hyprland desfoca a tela inteira a cada quadro da animação (na `main`, só o retângulo da pílula). Fica perto de 62 contra 67 FPS no container. Só se resolve dividindo a moldura em janelas por borda ou desligando o desfoque durante a animação. Continua aberto (fora do escopo da branch, decisão do usuário): a janela agora é `lucerna-panel-frame` e só encolhe a 1 px sem nada à mostra; com a barra revelada ela ocupa a tela toda.
- [x] **A borda da forma com escala fracionária:** a suavização é de 1 px lógico (`frame.frag`), e em 1,25 ou 1,5 a beira e o contorno do tema ficam um pouco borrados. Usar `fwidth` no lugar. Resolvido na base robusta (Tarefa 12): a suavização do `frame.frag` usa `fwidth`, as beiras dos pedaços vão ao pixel físico (`Frame.snapRect`), e as bordas e as linhas de 1 px são `Pixel.hairline` (1 px físico).
- [ ] **O Esc na central aberta pelo atalho com uma janela focada por baixo.** Agora o Esc chega pelo grab (a janela da forma pede `OnDemand` só com uma entrada `keyboard` ativa). Não foi conferido na Tarefa 8 (o container não tem uma janela focada por baixo que reproduza o caso); continua a conferir no Hyprland de verdade.
- [ ] **Depois de um `hyprctl reload`**, as regras do tema, do desfoque e da moldura são reenviadas pelo shell; conferir numa sessão de verdade (no container, o reload derruba a saída aninhada).
- [x] **A janela da forma volta à tela inteira quando o OSD acaba.** Com `parts` vazio, o `Frame.compactOn` dá falso, e a janela pede um resize de tela cheia só para os quadros do `lingering`. Manter o último `compact` enquanto não houver pedaços (ou tratar a lista vazia como compacta). Resolvido com a janela sempre mapeada (`feat/conteudo-janela-forma`): não há mais `lingering` nem `compactOn`.
- [x] **O `lingering` da `BarWindow` depende da ordem entre o `onPartsChanged` e a binding do `visible`.** Hoje o handler vem antes, mas é frágil: derivar a condição de uma flag própria (`hadParts`), não do próprio `visible`. Resolvido com a janela sempre mapeada (`feat/conteudo-janela-forma`): não há mais `lingering` nem `compactOn`.
- [ ] **A junção da barra com a moldura fica com suavização 17, não 22.** O limite "metade do menor lado à mostra" vale também para a pílula de 34 px. Se o 22 for desejado na barra, isentar o `role === "pill"` do limite da suavização (ou limitar só o raio); se não, registrar no spec.
- [ ] **O painel superior acompanhante fica abaixo das Configurações.** Com os dois abertos, o painel superior fica por baixo das Configurações (decisão do usuário, confirmada na Tarefa 4): um clique fora fecha primeiro as Configurações, e um segundo fecha o painel superior. Captura: `docs/superpowers/bench/2026-10-28-painel-superior-sob-configuracoes.png`.
- [ ] **Popup de notificação sob o painel superior em tela estreita.** Em 1366x768, um cartão de notificação embaixo do painel superior aberto aparece legível através do fundo translúcido do painel (os popups ficam abaixo dos painéis, decisão do usuário). Opção: esconder os popups daquela tela enquanto o painel superior está aberto.
- [ ] **O `cleared` do grab agora fecha os painéis de verdade** (correção em `Panels.clearedByCompositor`). A mudança de comportamento que se vê: o clique fora agora fecha as Configurações pelo caminho do grab (o `cleared` do Hyprland, conferido pelo `clearedCheck`). A troca de workspace com só as Configurações abertas **não** as fecha (conferido na Tarefa 8: `panels get` continua `settings` na área 2 e de volta na 1). Conferir em hardware real se é bem-vindo.
- [ ] **Os popups de notificação agora ignoram a zona exclusiva das outras camadas.** A janela própria dos popups usava `ExclusionMode.Normal` (ficava fora de uma barra/dock de outro cliente que reserva espaço); dentro da janela da forma, que é `ExclusionMode.Ignore`, eles se posicionam pela tela inteira e podem ficar por baixo de uma camada assim. Sem caso no Lucerna hoje (a barra não reserva espaço); se aparecer, descontar a zona exclusiva na posição dos popups.
- [ ] **O OSD abre com o swap esperando dois quadros quando o compositor não tem mais nada para redesenhar.** No bench oficial (área vazia, a barra à mostra, a janela da forma em tela cheia) o `osd:abrir` piorou contra a `main`: pior 9 → 26 ms, p95 1 → 13/19, longos 0 → 4/26, FPS tela ~73 → ~53. Na revisão final, com a regra `no_anim` da janela da forma enfim valendo (antes o Hyprland animava e esticava a janela a cada troca de largura, e esse redesenho mascarava o efeito), o mesmo aparece com a barra escondida e a janela na coluna de 128 (`BENCH_KITTY=1`): pior 26/27, p95 25/14, 45/23 longos por rodada. Todo o tempo é do `eglSwapBuffers` (sync e render 0), alternando 25/13 ms: é o ritmo dos frame callbacks do Hyprland para a janela da forma, não trabalho do qs, e na `main` a janela própria do OSD não esperava. Caminhos: medir na máquina real a 144 Hz (o container é um Hyprland aninhado a 60 Hz dentro do KDE, e o ritmo pode ser do aninhamento) com `BENCH_KITTY=1 dev/bench-paineis.sh` e o bench padrão; se repetir, investigar o swap interval/`frameCallback` do Qt na janela sempre mapeada (ex.: o `QSG_RENDER_LOOP` e o `wl_surface.frame` com dano pequeno) e o caminho de repaint do Hyprland para uma camada que só muda numa faixa.
- [x] **A central abria de cima para baixo pelo atalho geral** (`Super+C`, relato do usuário). Com os dois painéis abrindo juntos, as Ações entravam primeiro e as Notificações, 40 ms depois (a cascata), cresciam para baixo a partir delas (o `reveal` do PR #61), e o bloco da forma descia junto; o fechamento também encolhia na vertical. Resolvido em `feat/conteudo-janela-forma`: sem a cascata, os dois andam no mesmo passo e entram (e saem) como uma peça só, deslizando da direita para a esquerda já na altura toda, sem o pulo de 496 para 1192 px (as duas partes estão à mostra desde o 1º quadro). O crescimento vertical ficou só para as Notificações entrando ou saindo sozinhas com as Ações já à mostra (a central aberta). O OSD já entrava só na horizontal, na altura fixa. Tiras conferidas no container (com e sem notificações, aberturas repetidas, as Notificações sozinhas e o OSD).
- [ ] **Painel superior aberto e parado redesenha a ~67 fps já na `main`** (medição `parado-painel`, base do bench). Se continuar assim no fim, fica aberto.
- [ ] **O canto próprio da central reaparece na subida das Notificações.** O `top-` do bloco só entra com o topo a até 0,5 px da moldura; quando as Ações saem e o inbox sobe animado, o bloco fica solto e "estala" na junção ao chegar. Conferir a olho; se incomodar, interpolar a junção pela distância até a moldura (prender sem esticar o bloco).
- [x] **A expansão dos painéis termina num corte seco.** Resolvido na branch `fix/animacao-corte-seco`. A causa: o tipo do `Anim` do `Behavior on shown` (`OverlayPanel`, e o mesmo padrão na `BarWindow`, no OSD, nos avisos dos monitores e no véu da ociosidade) era escolhido pelo estado (`open ? ... : ...`), lido antes de ser reavaliado: a abertura rodava a curva da saída (um salto de 28% no 1º quadro, com o conteúdo indo de quase nada ao cheio) e o fechamento, a mola. Agora a escolha sai do `targetValue` do Behavior, e a regra `animações` do `ci/rules.py` barra o padrão. Na central, a altura do bloco pulava de 496 para 1192 px quando as Notificações entravam abaixo das Ações; agora elas crescem a partir das Ações (e encolhem até elas ao sair) só quando entram sozinhas; com as duas juntas, o bloco desliza já na altura toda (ver acima). O fechamento foi conferido em câmera lenta: o conteúdo esmaece antes de a forma terminar, sem a janela sumir no meio. Fica de fora o conteúdo entrar junto da forma (hoje a partir de ~70%, `Frame.contentStart`): vai pelo item do conteúdo na janela da forma, acima.
- [ ] **As capturas da documentação:** a `docs/screenshots/desktop.jpg` já mostra a barra fundida à moldura; a `hero.jpg` (e as dos painéis, se for o caso) ainda mostram a barra antiga.

## Sobras do desfoque

Adiadas na revisão final da branch `feat/desfoque` (níveis do desfoque, xray, pausa do papel de parede).

- [ ] **A barra em repouso ainda custa o desfoque da tela inteira.** Com `barOnEmpty` (o padrão), a pílula da barra fica à mostra na área de trabalho vazia, e a janela da forma ocupa a tela inteira e é desfocada; com o papel animado, o Hyprland refaz o desfoque da tela toda a cada quadro do papel (no Desempenho, o xray ainda suja o fundo guardado). A pausa do papel não vale para a pílula sozinha (senão o papel nunca andaria onde aparece), então o repouso e a barra revelada medem igual à `main`. Resolver encolhendo a janela da barra para o tamanho da pílula quando só há a pílula (ou uma regra/namespace própria para ela). Continua aberto (fora do escopo da branch, decisão do usuário): a janela agora é `lucerna-panel-frame` e encolhe a 1 px só sem nada à mostra; com a pílula ela ainda cobre a tela.
- [ ] **Migração de canto do `blurOverride.enabled`.** Antes, `{ enabled: true }` no ajuste do usuário vencia um tema com `hyprland.blur: false`; agora o `modeFrom` ignora o `enabled: true` e o tema deixa o nível em `off`. Nenhum tema embutido tem `blur: false`. Se importar: com `custom.enabled === true`, usar o `blurMode` do tema ou `"performance"`, sem olhar o `theme.blur`.
- [ ] **O `windowRuleSent` não sobrevive a um reinício do shell.** Se o shell reinicia depois de mandar a regra `no_blur` e o `blurWindows` volta a `true` por fora (editando o config), a regra fica até o próximo reload. Caso remoto.
- [ ] **Religar o desfoque das janelas faz `hyprctl reload`**, que apaga ajustes em tempo de execução de fora do shell (um `hyprctl keyword` do usuário) e devolve os monitores ao arquivo por uns 300 ms antes do `DisplaysState` reaplicar. O texto da linha avisa; mesmo padrão do `Input.reload()`. Conferido no container: a regra vale para janelas já abertas e o reload devolve o desfoque delas (a saída aninhada continuou de pé desta vez).
- [ ] **A config do desfoque força `popups = false` e `new_optimizations = true`** por cima do `hyprland.lua` do usuário (decisão do spec). Citar no PR; se alguém reclamar, deixar só o `debug.vfr`.
- [ ] **8×2 em vez de 12×1:** com uma passada o desfoque saía em blocos, então os temas ficaram com as mesmas duas passadas da `main` e raio maior (32 em vez de 24, um pouco mais desfocado). O ganho de custo vem do xray e da pausa do papel, não de menos passadas.
- [ ] **A prévia do vidro (`GlassPreview`) não simula o xray** no nível Desempenho; só a intensidade.

## Sobras do modo jogo

Da implementação do modo jogo no shell (branch `feat/modo-jogo`, com o `lucernad` do PR #19). As sobras do daemon (M2, M3, M9, M10 e M7 da revisão do `lucernad`) estão nas Pendências de lá.

- [x] **Perfil falso no ambiente de teste:** o container monta o D-Bus do sistema do host, e o modo jogo seguraria o perfil de energia do host. Resolvido com o lucernad#21: com o `LUCERNAD_POWER_ROOT`, o perfil e o GameMode são falsos em arquivos (o `ci/power-root.sh` cria as pastas); o `dev/bench-game.sh` exige o lucernad na raiz de teste, e a fumaça ainda aponta o `DBUS_SYSTEM_BUS_ADDRESS` do lucernad para um socket inexistente.
- [ ] **O resumo depois de um reinício do processo do `qs`** (revisão final, M3): ele sobrevive a um reload (o `keepOnReload` e o `receivedAt` persistido), mas com o `qs` morto e subido de novo a lista do `NotificationServer` volta vazia e o resumo sai nulo. Coerente com o que já existia; o "reinício" dos testes e do spec é o reload. Conferir no container quando houver notificações persistentes.
- [ ] **O ícone da barra não tem dica flutuante** (revisão final, M6): a barra não tem um componente de dica. O ícone mostra "Desligar" ao lado com o mouse em cima, e o texto completo ("Modo jogo ligado: tela cheia, jogo. Clique para desligar.") fica no `BarState.gameTooltip` (o `Accessible.name`). Fazer a dica quando houver um componente para isso.
- [ ] **A lista "nunca" de fábrica está copiada** do `DEFAULT_NEVER` do `lucernad` no padrão do `Config.gameNever` (revisão final, M2): o shell sempre manda a lista dele no `game.configure`, e o daemon não publica a de fábrica (nem no `game.state` nem num método), então ler dela pede uma mudança no `lucernad` (um `game.defaults` ou o campo no `game.status`), registrada nas Pendências de lá. Até lá, o comentário no `Config` aponta a origem; se a lista do daemon mudar, mudar aqui também. Depois: a fumaça comparar as duas, e um botão "voltar à lista de fábrica" na página.
- [ ] **O resumo das notificações conta as que ainda estão na lista:** uma notificação dispensada durante o jogo (pelo app ou na central) não entra (decisão D20 do spec).

## Depois

- [ ] **Host de painéis dos apps: subir o serviço quando a conexão é recusada** (do "Trabalho seguinte" do lucerna-sdk#14; item 7 do lucerna-sdk#13). Com a conexão ao `<app>.sock` recusada, o host roda `<app.tui do manifesto> serve` pelo mesmo molde do `Client::connect_or_spawn` do SDK (grupo de processos novo, saída no `serve.log`, até 2 s com espera crescente) e reconecta. Vai junto com o cliente QML do protocolo.
- [ ] **O lado do shell do explorador (`lucerna-files`, v3 do spec):** o formato do tema que o shell publica (o tema resolvido em JSON público, num spec do shell), o progresso das operações na central (pelo `progress.*` do `lucerna-sdk`), o `FileSearch.qml` pelo `files.sock`, arrastar e soltar com os painéis, "definir como papel de parede" e miniaturas compartilhadas.
- Os **comandos de linha para todo o ecossistema, em inglês** (pedido de 2026-11-01, PR #63) passaram para as [Pendências do `lucerna-sdk`](https://github.com/lucerna-desktop/lucerna-sdk/blob/main/lucerna-sdk%20%E2%80%94%20Pend%C3%AAncias.md): o padrão é desenhado no `docs/ecossistema.md` de lá, e a migração do `qs ipc` acontece aqui depois.
- [ ] Aba Desempenho: um medidor de bateria em forma de pilha, só no notebook. Rascunhos de três encaixes (ao lado de CPU e GPU, em pé ao lado da Memória, faixa embaixo) em `.superpowers/brainstorm/436361-1792526405/content/bateria-desempenho.html`; o usuário quer planejar melhor antes.
- [ ] Aurora, Brasas, Chama e Vaga-lumes somam luz ao fundo e, num tema claro, estouram para branco. Adaptá-los como o Ondas (que já tem versão clara). Os efeitos próprios dos temas claros (Ondas e Névoa) estão bons.
- [ ] Sliders das configurações gravam o `Config` a cada movimento (GlassPage, NightLightPage, IdlePage, MousePage, KeyboardPage, PowerPage e NotificationsPage). Com `blockWrites` não há perda nem corrupção, e a gravação mediu 1,4 ms em NVMe, mas em disco lento o arrasto pode engasgar. Correção prevista: debounce de uns 200 ms, com o reload suspenso durante a espera e um flush ao sair.
- [ ] Fumaça com o Hyprland de verdade, quando houver runner com GPU: hoje ela roda no `sway` headless, e o que depende do Hyprland (workspaces, visão geral com janelas, `hyprctl`) não é exercitado.
- [ ] `CHANGELOG`, junto com as releases.
- [ ] Central, Wi-Fi: o `WifiState.networks` refaz a lista inteira a cada mudança, então as linhas são recriadas e a senha que estava sendo digitada se perde quando a lista de redes se atualiza. Manter as linhas pela rede (ou guardar a senha fora do delegate).
- [x] (feito em 2026-10-22: módulo `power` do `lucernad`) Central, bateria: a sonda do power-profiles-daemon (`busctl`) roda só na partida do shell. Se o daemon subir depois, os botões de perfil (e o tile "Energia" de um desktop) não aparecem até reiniciar o shell. Repetir a sonda (ao abrir a central ou ao mudar o `PowerProfiles`).
- [ ] Central, saída de áudio: o volume por app mostra qualquer app com áudio aberto, inclusive pausado, porque o `PwNode` do Quickshell 0.3 não diz se o stream está tocando. Filtrar quando houver esse estado.
- [ ] Central, saída de áudio (aceito): sem saída padrão, o volume por app não aparece, porque a página da Saída some junto com o tile.
- [ ] Central, sliders (aceito): a roda do mouse sobre um slider largo (volume, brilho, microfone) muda o valor em vez de rolar a página.
- [ ] Central (aceito): as ações e as notificações são sub-estados de um painel modal só, então o `panels get` mostra só `central`, sem dizer qual dos dois está aberto.
- [ ] Central (aceito): durante a saída animada de um dos dois painéis, um clique na área dele ainda conta como dentro (não fecha a central).
- [ ] Central, saída de áudio (aceito; conferir com o mouse): ao trocar para um sink Bluetooth recém-conectado, a página da Saída pode voltar ao estado inicial se o sink demorar a ficar pronto (o recurso "some" por um instante).
- [ ] Central, popups (alternativa adiada): com só as ações abertas, os popups ficam escondidos e esperam. Poderiam descer para baixo das ações e continuar aparecendo.
- [ ] Notificações: histórico persistente (hoje só sobrevive ao reload) e modo avião (o shell não tem rfkill), ambos fora do escopo da central.
- [ ] README: a captura `docs/screenshots/hero.jpg` (cena montada com terminais e música) ainda mostra o visual antigo do painel superior. Refazer a cena.
- [ ] Lint: quando o CI deixar de testar o Qt 6.11, tirar o `unqualified` da linha de supressão da margem e do `QMLLINT_ALLOWED_COMMENT` em `ci/rules.py`.
- [ ] Crédito ao Caelestia também na página Sobre das configurações (hoje só no README).
- [ ] Atalhos (base robusta, Tarefa 11): arrastar e redimensionar (`Super` + botão esquerdo/direito) só mostram a tecla na página de Atalhos; falta escolher o modificador (a captura é de teclas, e os botões esquerdo e direito ficam fora da captura do mouse).
- [ ] Apps padrão (Tarefa 11): o `apps.conf` só é gravado quando a escolha muda na página de Atalhos; um `Config.defaultApps` mudado por fora (o `config.json` à mão, `dev/test.sh setc`) não chega ao `apps.conf` até a próxima escolha. De propósito, para não apagar um `apps.conf` escrito à mão na partida; rever se o `apps.conf` passar a ser só do shell.
- [ ] Escala fracionária (base robusta, Tarefa 12): só as linhas de 1 px viraram `Pixel.hairline`; as bordas de 2 px (foco, seleção, notificação crítica) ficam em 2 lógicos (2,5 físicos em 1,25) e vão com o `ThemeManager.px()` da Tarefa 13. No pixel físico ficaram a forma (as vagas do shader), o painel superior, os centralizados (Configurações, área de transferência, energia, visão geral) e os três estilos do lançador; a central, o OSD e os popups (presos à direita, com larguras múltiplas de 4) e os cartões do seletor de temas (no carrossel) seguem em pixel lógico.
- [ ] Escala fracionária (achados da Tarefa 1, não são de alinhamento): na tela de bloqueio em 1,5 sobra uma faixa sem desenho embaixo depois de trocar a escala com o shell aberto (o fundo fica no tamanho da escala anterior), e a lista lateral das Configurações sai cortada no fim em 1,25 e 1,5 (a altura da janela não cabe a lista). Para a Tarefa 13/15.
- [ ] Escala pelos apps (base robusta, Tarefa 14): o `hl.env` do Hyprland não desfaz uma variável, então ao voltar para a escala do monitor (e no fator 100% dentro do modo) as variáveis que não existiam antes vão com o valor neutro (`QT_SCALE_FACTOR=1`, `GDK_SCALE=1`, `GDK_DPI_SCALE=1`, cursor 24) para os apps abertos até sair e entrar; o `GDK_SCALE=1` fixa a escala inteira do GTK no X11 (num monitor em 2, um app GTK X11 aberto nesse meio-tempo sai em 1). O valor de antes do `QT_SCALE_FACTOR` nunca é conhecido (o supervisor o tira do ambiente do shell). Se houver como tirar a variável (um `hl.env` sem valor numa versão nova, ou um `exec` com `env -u`), usar.
- [ ] Escala pelos apps: a cópia `.lucerna-bak` nunca é sobrescrita (para um `scale-backup.json` perdido no meio do modo não trocar a cópia de verdade pela versão do modo). Numa segunda entrada no modo, depois de a pessoa mudar o arquivo, a cópia continua a de antes da primeira; a volta não depende dela (usa a marca e o JSON), mas comparar com ela engana.
- [ ] Escala pelos apps: sem o `scale-backup.json` (apagado à mão), a volta só tira o que é marcado (a linha das flags, o `session.env` e o `Xresources` gerados) e deixa o `gtk-xft-dpi`, cujo valor de antes não se sabe. A volta pelo `scale-backup.json` mantém o que a pessoa mudou nesses arquivos durante o modo (não copia o `.lucerna-bak` de volta); um `gtk-xft-dpi` trocado à mão nesse meio-tempo é sobrescrito pelo valor guardado.
- [ ] Escala pelos apps: ao entrar no modo sem um arranjo salvo, o arranjo de agora é salvo como o da escala do monitor (é a ele que a volta retorna), e passa a valer no lugar da escala automática da base para aqueles monitores (o mesmo valor, mas fixo). A página lê o `Monitors.monitors`, que não se atualiza com uma escala trocada por fora (`hyprctl eval` sem evento): nesse caso, salva a escala velha.
- [ ] Escala pelos apps: o modo leva o arranjo dele à parte (`apps: <conjunto>` no `Config.monitorSetups`); sem ele, os monitores em 1 seguem o da escala do monitor pelas bordas encostadas (`Monitors.atScale`), e um arranjo em L ou com deslocamentos fora das bordas anda na proporção do tamanho, não exato.

## Verificar com hardware e entrada reais

No ambiente de teste não dá para simular cliques, e o Hyprland ignora teclado virtual. Estes pontos foram testados só pela lógica (IPC e capturas) e precisam de uma conferência na máquina de verdade:

- [ ] Atalhos: capturar a tecla com o teclado de verdade (o `wtype` manda outro keymap) e os atalhos do shell disparando.
- [ ] Mouse e teclado: capturar botões e teclas, remapear teclas e os binds dos botões extras.
- [ ] Monitores no login: monitor real casado pela descrição (`desc:`) e o arranjo já certo antes de o shell subir.
- [ ] Monitores: arrastar no canvas; em monitor real, a lista de resoluções, o VRR e a cor de 10 bits.
- [ ] Papel de parede: pausa com a tela bloqueada e com a tela apagada; o vídeo solta o decodificador depois de 2 min pausado; 60 fps caem para 30 na bateria.
- [ ] Ociosidade: suspender, segurar com mídia tocando e com tela cheia, e o aviso do `hypridle`.
- [ ] Luz noturna: a cor mudando de fato (a CTM não aparece no Hyprland aninhado nem em capturas) e a transição suave.
- [ ] Captura: o som da gravação (sistema e microfone) e a área com escala fracionária ou em outro monitor.
- [ ] Visão geral: arrastar uma janela para outro workspace (no container não dá para simular o arrasto) e vários monitores.
- [ ] Brilho: as teclas ajustando o monitor em foco (no container o foco é a janela aninhada, não o HDMI).
- [ ] Launcher: navegação pelo teclado nos três estilos, `Ctrl+1…9` nas ações do app e o "Mais opções".
- [ ] Painel superior: as setas do calendário (a bolha some em outro mês e volta no atual), o clique nos cards de GPU e de Disco trocando de GPU e de disco (com o esmaecimento), o "4,8 / 224 GiB" do `sda`, o clique numa linha da letra pulando para o trecho, a troca de player pelo ícone.
- [ ] Aba Desempenho: a temperatura da RTX (lida pela NVML do `lucernad`, só com a placa em uso; o container de teste não tem a NVIDIA) e o uso da Intel pelo fdinfo do `lucernad` na máquina real.
- [ ] Painéis da moldura: o clique de verdade na barra fundida (a fumaça e o roteiro usam um ponteiro virtual), a barra e a moldura em dois monitores (o painel abre no monitor com foco e sai da barra dele; com o painel superior, a central, o OSD ou um popup à mostra, passar o mouse para o outro monitor não os leva junto), e a barra se transformando no painel superior com o mouse de verdade (o conteúdo esmaecendo, sem clique perdido).
- [ ] Modo jogo: entrar com um jogo de verdade (Steam/Proton, Wine, Lutris) e pela tela cheia de um jogo; o clique no ícone da barra desligando; a chave das ações rápidas com o mouse; o atalho (a ação "Ligar/desligar o modo jogo" com uma tecla escolhida em Atalhos) e a ação "Mostrar/esconder a barra" com o teclado de verdade; o clique no cartão de resumo abrindo as notificações; o perfil de desempenho e o GameMode da Feral numa máquina com os dois; a medição (`dev/bench-game.sh`) numa sessão Hyprland real.
- [ ] Tela de emergência (`lucerna-session emergency`): em dois monitores (um véu por tela, todos com o foco exclusivo; conferir que as setas e o Enter chegam), o Ctrl+Alt+Delete com o teclado de verdade, e o Desligar e o Reiniciar de verdade (no container só simulam), com e sem systemd.
- [ ] Bloqueio pelo logind (`services/Logind.qml`): na máquina real, o `GetSession("auto")` com o shell subido pelo `lucerna-shell.service` (fora do escopo da sessão, o logind cai na sessão gráfica do usuário), o inibidor delay aceito pelo polkit, o bloqueio na tela antes de dormir pelo `systemctl suspend`, pela tecla de energia e pela tampa, a hibernação, o `loginctl lock-session`/`unlock-session` e o `LockedHint` no `loginctl show-session`. No container só o logind falso.
- [ ] Tampa com monitor externo (`Monitors.lidPlan`, `DisplaysState.followLid`): num notebook de verdade (o container só tem a `WAYLAND-1`, que não é interna), fechar a tampa com um externo ligado apaga a `eDP` sem suspender (o `HandleLidSwitchDocked=ignore` padrão do logind; quem mudou isso no `logind.conf` suspende mesmo assim) e, com a opção de Energia, bloqueia; abrir religa a `eDP` com o arranjo salvo; tirar o externo com a tampa fechada religa a `eDP`. Ver também o externo espelhando a `eDP` (com a tampa fechada a `eDP` desliga e o espelho perde a origem).
- [ ] Central: os ícones da barra abrindo as ações na página certa e fechando no mesmo ícone (sem fechar as notificações), o sino abrindo e fechando só as notificações, e o foco voltando ao painel (o `Esc` fecha) depois de fechar as ações com a senha do Wi-Fi sendo digitada; os tiles (o corpo liga e desliga, a setinha abre a página), os sliders de volume e brilho e os volumes do microfone e de cada app; a troca de dispositivo, conectar a uma rede com senha, parear, os perfis de energia, a engrenagem e o "Limpar".
- [ ] Escala pelos apps (Tarefa 14): numa sessão real, com o xrdb, o Chromium/Chrome e um app Electron lendo os `*-flags.conf` (o wrapper do Arch), um app GTK 3 e um GTK 4 com o `gtk-xft-dpi` e o `GDK_DPI_SCALE`, um app Qt com o `QT_SCALE_FACTOR`, um app X11 com o `Xft.dpi` e o cursor no tamanho novo; o `session.env` valendo depois de sair e entrar (pelo `systemctl --user import-environment` também, com systemd). No container só o kitty e os arquivos.
- [ ] Super sozinho (lançador ao soltar, `release = true` no `SUPER + SUPER_L`): conferido no container com o Alt e o `wtype` (Alt sozinho abre; Alt+1 e soltar não abre; Alt+arrastar uma janela com o ponteiro virtual e soltar não abre). Conferir com o teclado e o mouse de verdade na sessão real, com o Super.

## Ambiente de teste

- [ ] Os atalhos com Alt pararam de funcionar no Hyprland aninhado (o teclado chega; os binds existem e as ações funcionam). Com o `wtype`, a causa foi achada: o Hyprland aninhado resolve os binds pelo keycode do keymap real, e o `wtype` dá ao primeiro caractere o keycode 1, que é o Esc (`wtype -M alt c` vira `Alt+Esc`, o menu de energia). O contorno, com caracteres de enchimento antes da tecla, está no `dev/test.sh`. Falta conferir com o teclado de verdade.
- [ ] `dev/ci.sh` usa nomes fixos de contêiner (`lucerna-ci-<check>`) e começa com `docker rm -f`, então duas execuções ao mesmo tempo (dois worktrees) se derrubam. Acrescentar um sufixo por worktree ou PID.
- [ ] A imagem do container de teste avisa "locale C" (o `LANG=pt_BR.UTF-8` sem o locale gerado) e o log mostra `qt.qpa.wayland.textinput ... disableSurface`. Gerar o locale no `dev/Dockerfile` e conferir se o aviso do textinput some.
- [ ] A imagem do container de teste não tem o `less`: o "Ver o registro" (do modo de segurança e da tela de emergência) abre o kitty com "Failed to launch child: less". Instalar o `less` no `dev/Dockerfile`; e, para qualquer sistema, o `lucerna-session open terminal` poderia cair para o `$PAGER` ou para um `tail` quando não houver `less`.
- [ ] Os testes de áudio no container tocam pelo PipeWire do host (saem nos alto-falantes). Usar sempre `mpv --ao=null` ou um sink nulo; documentar no `dev/test.sh`.
