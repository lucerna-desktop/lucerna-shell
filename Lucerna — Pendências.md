# Lucerna — Pendências

O que falta fazer, na ordem em que vamos seguir. Cada item vira um PR; ao terminar, ele é marcado aqui.

## Em ordem

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
13. [ ] **Dock**, com spec próprio.
14. [ ] **Instalação e distribuição:** script de instalação (link, trecho do `hyprland.lua`, atalhos padrão) e pacote no AUR. A verificação no CI já está feita: quatro checks obrigatórios (`ci/`, `dev/ci.sh`).
15. [ ] **Lógica fora do shell (Rust).** Ver a seção "Separação da lógica" abaixo. Substitui o plano de plugins em C++ de `Lucerna — Plugins Próprios.md`, que precisa ser revisto à luz dela.
16. [ ] **Equalizador de áudio**, com spec próprio: muda o som (filtro do PipeWire, `filter-chain`, ou controle do EasyEffects) e mostra o espectro ao vivo atrás das faixas, reaproveitando o módulo de espectro.
17. [ ] **Temas com mais cores e o papel de parede como escolha**, com spec próprio (projeto aprovado em 2026-10-26). O modelo de tema hoje tem um destaque só (`accent`, 152 usos) e usa 11 das 26 cores do Catppuccin; o ajuste rápido (o Catppuccin com o azul como destaque) já foi feito (PR #51).
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

Módulos propostos, em ordem de prioridade:

1. [x] **Espectro:** captura do PipeWire e FFT próprias no lugar do `cava` (feito em 2026-10-20: módulo `spectrum` do `lucernad`; a batida fica para depois).
2. [x] **Sistema:** CPU, memória, rede, discos, temperaturas e GPU no lugar do parse em `services/SystemStats.qml`, do `gpu-status.sh`, do `drm-fdinfo.sh`, do `df` e do `lsblk`; NVIDIA pela NVML, sem `nvidia-smi` (feito em 2026-10-20: módulo `system` do `lucernad`).
3. [x] **Área de transferência:** observador do Wayland, histórico com deduplicação e imagens (SQLite), no lugar do `wl-paste --watch`, do base64 decodificado em JS e do `clipboard.json` (feito em 2026-10-21: módulo `clipboard` do `lucernad`).
4. [x] **Energia e brilho:** histórico do UPower e perfis de energia por D-Bus (hoje `busctl`), brilho interno e DDC/CI por biblioteca (hoje `brightnessctl` e `ddcutil`). (feito em 2026-10-22: módulo `power` do `lucernad`)
5. [x] **Rede externa:** letras (LRCLIB) e clima (Open-Meteo), com cache em disco (hoje sem cache). (feito em 2026-10-26: módulo `web` do `lucernad`)
6. [ ] **Launcher:** índice de apps com pontuação, frecência de verdade (hoje só contagem), busca de arquivos (hoje `fd`/`find`) e metadados de apps (hoje `app-info.sh`).
7. [ ] **Hyprland:** binds, entrada, keymap (hoje `xkbcli`) e monitores pelo socket IPC do Hyprland, no lugar do `hyprctl eval` e da geração de Lua.
8. [ ] **Luz noturna:** gama direto pelo protocolo `wlr-gamma-control`, sem o `hyprsunset`.
- [ ] **Ferramenta à parte:** `lucerna-video`, o conversor de papel de parede em vídeo (hoje `video-wallpaper.sh`, com `ffmpeg`), em lote, fora do daemon.
- [ ] Depois, se valer: captura de tela e gravação (hoje `grim` e `wf-recorder`).

Sobras do módulo de sistema:

- [ ] **`status` sem a primeira amostra:** o `lucernad status` (o `status` do `lucerna-cli`, no SDK) imprime o retrato inicial dos tópicos amostrados (`data: null`, `seq` 0) e sai, então `system.stats`, `system.disks` e `system.gpus` aparecem vazios. Ele deveria esperar a primeira amostra por um prazo curto.
- [ ] **Pacote do `lucernad`:** um PKGBUILD no repositório do `lucernad`. Hoje ele é instalado à mão pelos comandos do README e precisa ser recompilado e reinstalado a cada merge.
- [ ] **Uso da Intel na primeira amostra:** o fdinfo precisa de duas leituras, então ao abrir a aba Desempenho o uso da Intel fica "—" por ~2 s. Dá para tirar uma leitura curta extra no primeiro ciclo.

Sobras do módulo de espectro (baixo risco, adiadas na revisão final):

- [ ] **Captura, por dentro (`lucernad-spectrum/src/pipewire.rs`):**
  - quando um client sai, o grafo não é reenviado;
  - um nó novo só é ligado no próximo tique (até 100 ms);
  - um alvo que o WirePlumber recusa sempre é recriado a cada ~600 ms, sem log nem teto;
  - a sessão não espera a thread do PipeWire terminar;
  - a sonda que liga a captura logo que o nó aparece não confere o link player → sink.
- [ ] **Threads presas por sessão:** com o `/proc` travado para sempre, cada ciclo de assinatura deixa uma thread de casamento presa. O limite de um casamento em voo vale por sessão, não para o processo todo.
- [ ] **Casamento:**
  - o `/proc` é lido em duas vezes (`stat` e `exe`), então um PID reciclado no meio pode misturar processos;
  - um prazo do D-Bus estourado não refaz a conexão;
  - com `LUCERNA_TEST_HOST_BUS`, o PID do host é procurado no `/proc` do container.
- [ ] **Análise:**
  - se dois nós do mesmo player vierem com taxas diferentes, o analisador é recriado a cada amostra e o anel quase para;
  - com o player pausado e os nós ainda casados, as FFTs seguem rodando sem publicar;
  - a `magnitudes_db` cria o planejador da FFT a cada chamada.
- [ ] **"Capturando" depois de recarregar o shell:** o `spectrum.status` fica `capturing: true` por alguns segundos depois de um reload do Quickshell. A causa provável é o socket da geração antiga do shell ainda aberto; conferir com `ss -x` logo após um reload.
- [ ] **Shell:**
  - falta um teste do `spectrum.configure` com um player de verdade (os testes só cobrem `null`) e do `onPlayerChanged`;
  - o `Spectrum.available` não tem consumidor fora dos testes;
  - o `applyBands` não confere se as bandas são números.

Sobras do módulo da área de transferência (baixo risco, adiadas na revisão final):

- [ ] **Apagar de verdade (`lucernad-clipboard/src/store.rs`):**
  - o `secure_delete` (e o `secure-delete` do FTS) só protege dali em diante: o que foi apagado antes de ligá-lo fica nas páginas livres do banco até um `VACUUM`;
  - o corte pelo limite (`evict`) não passa pelo `forget`, então as páginas apagadas ficam no `-wal` até o checkpoint automático;
  - um `forget` que falha depois do `delete` devolve erro sem publicar a revisão nova.
- [ ] **Item que some entre o `locate` e a leitura** (apagado no meio de um `copy`/`get`): sai como erro interno, não como o `1001` "O item <id> não existe mais.".
- [ ] **`lucernad copiar` como primeiro cliente** (sem o shell nem outro assinante) cria um `history.db` vazio antes de achar o item.
- [ ] **`O_NONBLOCK` no fd de quem cola:** a escrita da seleção põe o fd em não bloqueante, e isso fica na descrição de arquivo do outro app; o caminho `WouldBlock`/`POLLOUT` do envio não tem teste.
- [ ] **Miniatura reduzida e girada** (EXIF com rotação numa imagem grande): sem teste.
- [x] **Marcas de direção no `historico`** (U+202E, U+2066–2069): trocadas por U+FFFD na saída, como os caracteres de controle (resolvido na revisão final).
- [ ] **Shell:**
  - falta um teste da ordem do `Component.onCompleted` do `Clipboard` (configurar antes de assinar) com o cliente já conectado;
  - o `onAtYEndChanged` do painel não dispara de novo quando a página somada cabe inteira na tela (a lista não chega a rolar): o "mais" seguinte só vem pelas setas.

## Sobras do módulo de energia e brilho

Adiadas na revisão do módulo `power` do `lucernad` (lucernad#14) e do shell (PR #50).

- [ ] **lucernad:**
  - cada escrita na integrada faz 4 chamadas D-Bus ao logind (dá para usar um `GetAll` e guardar o `Type`/`Seat` da sessão);
  - um `GetHistory` que falha derruba o histórico inteiro (o último bom poderia ficar, com o erro ao lado);
  - os perfis ficam sem estado inicial se a primeira leitura falha (só voltam no próximo `PropertiesChanged` ou `NameOwnerChanged`);
  - o `O_NOFOLLOW` do `TreeWriter` vale só no último componente do caminho;
  - `EBUSY` no endereço 0x50 (EDID) sem tentar o `I2C_SLAVE_FORCE`;
  - docks DisplayLink (monitores sem barramento i2c de placa de vídeo) ficam de fora.
- [ ] **Shell:**
  - o slider recua quando o DDC leva mais de 1 s (o hold acaba antes da publicação final) e avança na publicação;
  - corrida mínima no `reload` (`power.list`) quando o módulo volta enquanto chega um `power.screens`;
  - com o lucernad fora desde a partida, os botões de perfil ficam escondidos (o `profilesAvailable` não tem último valor);
  - um `1003` no meio do arrasto marca a tela com erro e o slider da central passa para a próxima tela;
  - o `busctl` continua na imagem do container (vem do systemd do Arch base), embora o shell não o use mais.

## Sobras do módulo de rede externa

Adiadas na revisão do módulo `web` do `lucernad` (lucernad#17) e do shell (PR #52).

- [ ] **Vagalume não testado na máquina real:** a API (`api.vagalume.com.br`) respondeu 503 durante todo o desenvolvimento, inclusive a documentação e os termos. Quando voltar: conferir o formato da resposta (`type` `exact`/`aprox`), colar a chave nas Configurações e testar uma faixa brasileira que a LRCLIB não tenha.
- [ ] **lucernad:**
  - letra em erro não tem nova tentativa automática (só ao reabrir a aba, no `web.refresh` ou na volta da conexão);
  - com a chave do Vagalume, uma faixa instrumental é buscada de novo a cada vez que toca;
  - a busca de cidade em andamento não é cancelada quando o modo offline liga, e há uma corrida curta entre a troca da conexão e a busca;
  - o clima fica em `loading` ou com o erro de offline já superado enquanto não há assinante, e aparece um `loading` passageiro quando um `configure` troca a cidade e liga o offline juntos;
  - a normalização faz as minúsculas depois de tirar os acentos (`İstanbul` vira `i stanbul`); o sufixo só é reconhecido depois de ` - ` com hífen comum (não ` – ` nem ` — `); os formatadores bidi (Cf) não são removidos do texto (o shell passa pelo `plain()`);
  - o cache: a poda varre as duas pastas, mas só confere a do tipo gravado (um link na outra apagaria `.json` fora do cache), e a leitura segue link (um FIFO no lugar do arquivo trava a leitura);
  - a conectividade: o `PropertiesChanged` não filtra pela interface do NetworkManager; há uma janela estreita no `watch()` em que um receptor novo fica num canal morto;
  - testes: o corpo lido em pedaços (resposta sem `Content-Length`) não tem teste; o `LocalServer` solto não fecha as conexões abertas; o `base_from_env` aceita porta com zero à esquerda; falta teste do `--lat`/`--lon` negativos na linha de comando; umidade e chance de chuva saem como `58.0` (o shell não se importa).
- [ ] **Shell:**
  - o "Hoje" e a data do topo da aba Clima usam a data da máquina, e os dias vêm pela data da cidade: com a cidade em outro fuso, perto da meia-noite, os dois podem divergir;
  - a barra de ações rápidas do Painel não tem navegação pelo teclado (o Tab do painel troca de aba); se fizer falta, as setas;
  - sem teste do `openLink` (só `https://`) da página Créditos nem do `openSettings` da aba Clima.

## Sobras dos painéis da moldura

Adiadas na revisão final da branch `feat/paineis-moldura` (a barra fundida à moldura e os painéis que saem das bordas).

- [ ] **O conteúdo dos painéis na mesma janela da forma**, como o `ContentWindow` do Caelestia. Hoje a forma é desenhada na janela da barra e o conteúdo do painel superior e da central fica na janela de cada um: duas superfícies que redesenham a cada quadro. Por isso a central ainda gasta perto do dobro de CPU da `main` ao abrir, e a forma e o conteúdo podem chegar à tela com um quadro de diferença (atenuado: o conteúdo entra mais tarde e recuado da beira). Juntar resolve as duas coisas e a ordem das camadas; o preço é o teclado, que a janela da forma passaria a pegar conforme o painel aberto.
- [ ] **A barra revelada pelo mouse custa mais que na `main`.** Com ela, a moldura aparece nos quatro lados, e a janela da forma ocupa a tela toda: o Hyprland desfoca a tela inteira a cada quadro da animação (na `main`, só o retângulo da pílula). Fica perto de 62 contra 67 FPS no container. Só se resolve dividindo a moldura em janelas por borda ou desligando o desfoque durante a animação.
- [ ] **A borda da forma com escala fracionária:** a suavização é de 1 px lógico (`frame.frag`), e em 1,25 ou 1,5 a beira e o contorno do tema ficam um pouco borrados. Usar `fwidth` no lugar.
- [ ] **O alcance do shader ainda é fixo** (20 px no `frame.frag`), amarrado à suavização de 18 do `Frame`. Um teste avisa se alguém subir a suavização; o certo seria passar o alcance como uniform.
- [ ] **O Esc na central aberta pelo atalho com uma janela focada por baixo.** A central não pega mais o teclado com exclusividade (para o clique na barra funcionar); conferir no Hyprland de verdade que o Esc ainda chega a ela.
- [ ] **Depois de um `hyprctl reload`**, as regras do tema, do desfoque e da moldura são reenviadas pelo shell; conferir numa sessão de verdade (no container, o reload derruba a saída aninhada).
- [ ] **As capturas da documentação** (`docs/screenshots/desktop.jpg` e talvez `hero.jpg`) ainda mostram a barra antiga.

## Depois

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
- [ ] Lint: quando o CI deixar de testar o Qt 6.11, tirar o `unqualified` das quatro linhas de supressão das margens e do `QMLLINT_ALLOWED_COMMENT` em `ci/rules.py`.
- [ ] Crédito ao Caelestia também na página Sobre das configurações (hoje só no README).

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
- [ ] Central: os ícones da barra abrindo as ações na página certa e fechando no mesmo ícone (sem fechar as notificações), o sino abrindo e fechando só as notificações, e o foco voltando ao painel (o `Esc` fecha) depois de fechar as ações com a senha do Wi-Fi sendo digitada; os tiles (o corpo liga e desliga, a setinha abre a página), os sliders de volume e brilho e os volumes do microfone e de cada app; a troca de dispositivo, conectar a uma rede com senha, parear, os perfis de energia, a engrenagem e o "Limpar".

## Ambiente de teste

- [ ] Os atalhos com Alt pararam de funcionar no Hyprland aninhado (o teclado chega; os binds existem e as ações funcionam). Com o `wtype`, a causa foi achada: o Hyprland aninhado resolve os binds pelo keycode do keymap real, e o `wtype` dá ao primeiro caractere o keycode 1, que é o Esc (`wtype -M alt c` vira `Alt+Esc`, o menu de energia). O contorno, com caracteres de enchimento antes da tecla, está no `dev/test.sh`. Falta conferir com o teclado de verdade.
- [ ] `dev/ci.sh` usa nomes fixos de contêiner (`lucerna-ci-<check>`) e começa com `docker rm -f`, então duas execuções ao mesmo tempo (dois worktrees) se derrubam. Acrescentar um sufixo por worktree ou PID.
- [ ] A imagem do container de teste avisa "locale C" (o `LANG=pt_BR.UTF-8` sem o locale gerado) e o log mostra `qt.qpa.wayland.textinput ... disableSurface`. Gerar o locale no `dev/Dockerfile` e conferir se o aviso do textinput some.
- [ ] Os testes de áudio no container tocam pelo PipeWire do host (saem nos alto-falantes). Usar sempre `mpv --ao=null` ou um sink nulo; documentar no `dev/test.sh`.
