# Lucerna — Proposta

Sep 23, 2026 · @Eduardo Alves

## Visão geral

Lucerna é um shell de desktop próprio, escrito do zero em Quickshell (QML), feito para rodar sobre o Hyprland no Arch Linux. Ele substitui barra, launcher, notificações e demais painéis por um conjunto único, leve e totalmente personalizável.

O nome vem do latim *lucerna*, "lamparina": luz sobre o escuro. A ideia guia o projeto inteiro — uma interface escura e discreta, em que os elementos só se acendem quando são necessários.

## Motivação

Shells prontos em Quickshell, como Noctalia, Caelestia e DankMaterialShell, carregam módulos, serviços e telas de configuração que nem sempre são usados. Mexer fundo neles exige primeiro entender a arquitetura de outra pessoa.

Com um shell próprio, só roda o que foi escrito, e cada decisão visual e de comportamento é intencional. Os shells prontos servem como material de estudo, não como base de código.

## Princípios

- **Leveza:** nenhum módulo ou serviço entra sem uso real. O custo base é o do Qt; o resto é mínimo.
- **Controle total:** todo o código é próprio e legível, sem camadas de configuração que escondam comportamento.
- **Específico para Hyprland:** integração nativa com o IPC do Hyprland via `Quickshell.Hyprland`, sem scripts externos. Outros compositores ficam fora, pelo menos por enquanto.
- **Feature-first:** o código se organiza por funcionalidade; cada feature pode ser adicionada, trocada ou removida sem afetar as outras.
- **Camadas bem definidas:** interface, estado e serviços são separados, e as dependências só apontam para baixo.

## Requisitos

- **Hyprland 0.56 ou mais novo, com configuração em Lua** (`hyprland.lua`). O formato `.conf` sai na 0.57, e o modo Lua muda o IPC: `dispatch` passa a receber código Lua (`hl.dsp.focus({ workspace = 2 })`) e `keyword` é substituído por `eval`. O Lucerna fala só o dialeto Lua.
- **Quickshell 0.3.1 ou mais novo**, que detecta o modo Lua do Hyprland (`Hyprland.usingLua`).
- **Fonte de ícones:** `ttf-material-symbols-variable`, do repositório oficial do Arch. É a única dependência de pacote além do Hyprland, do Quickshell e do `lucernad`.
- **Obrigatório: o `lucernad`**, o daemon do Lucerna, de onde vêm CPU, memória, rede, discos, temperatura e GPU, o espectro do som, o histórico da área de transferência, o brilho das telas (a integrada e os monitores externos por DDC/CI), o histórico e os perfis de energia e as letras e o clima (sem ele, esses componentes mostram "indisponível" ou não aparecem).
- Serviços do sistema usados quando presentes: PipeWire (áudio), UPower (bateria), NetworkManager (rede), o logind (brilho da tela integrada) e o power-profiles-daemon (perfis de energia), estes três pelo `lucernad`. Na falta de um deles, o componente correspondente simplesmente não aparece.
- **Mínimo de dependências de terceiros:** o que o Qt e o Quickshell já oferecem vem primeiro (`QtQuick.Shapes`); as leituras do `/proc` e do `/sys` (CPU, memória, rede, discos, temperatura e GPU) e as requisições à internet (letras e clima) vêm do `lucernad`. Quando algo crescer a ponto de pedir C++, a saída é um plugin próprio, em repositório separado, e não uma biblioteca externa. Os candidatos estão em [`Lucerna — Plugins Próprios.md`](<Lucerna — Plugins Próprios.md>).

## Identidade visual

O Lucerna terá vários temas pré-configurados, trocáveis a qualquer momento por um seletor em carrossel. O tema padrão é o **Catppuccin Mocha**: pastel escuro, malva sobre grafite azulado, cartões sólidos e a fonte Rubik.

- **Tema como dado:** cada tema é um arquivo em `themes/` com cores, fontes, raios, espaçamentos e wallpaper. Criar um tema novo é adicionar um arquivo, sem tocar em código.
- **Um ponto de verdade:** um `ThemeManager` (singleton) carrega o tema ativo e expõe os tokens (cores, fontes, raios, espaçamentos, durações de animação e altura da barra); nenhum componente usa cor, fonte ou espaçamento fixo. As dimensões estruturais de cada painel, como a largura do launcher, ficam no próprio componente.
- **Temas embutidos:** os dez esquemas mais populares, nas paletas oficiais: Catppuccin Mocha (padrão), Tokyo Night, Gruvbox Dark, Rosé Pine, Nord, Everforest, Kanagawa, Dracula, Matte Black e Decay Green, mais as versões claras oficiais Catppuccin Latte e Rosé Pine Dawn (`"dark": false`). Cada um tem um papel estático e um efeito animado que combinam com ele. Os arquivos dos temas e os papéis estáticos são gerados por `dev/themes.py`, a partir das paletas.
- **Cartões:** sólidos e sem contorno, destacados pelo tom (como no Material 3), com raio de 22 px. O contorno é um token do tema (`surfaces.outline`) e pode ser ligado nas configurações.
- **Fontes do tema:** um tema pode trazer fontes em `themes/fonts/`, carregadas pelo `FontLoader` sem instalar nada no sistema.
- **Troca ao vivo:** no seletor em carrossel, as setas giram a fila e o tema do card central é aplicado de verdade em toda a interface, com transição suave, depois de uma espera curta (setas seguidas aplicam só o último). Enter mantém a escolha, que fica salva para a próxima sessão; Esc ou clique fora voltam ao tema de antes.
- **Ajustes do usuário por cima do tema:** transparência, desfoque e velocidade das animações podem ser mudados na tela de configurações. Ficam na config como sobreposições do tema (o `ThemeManager` junta os dois), então valem para qualquer tema e podem ser desfeitos.
- **Integração com o Hyprland:** a troca também ajusta bordas e arredondamento do compositor via `hyprctl eval`, para o visual ficar coeso fora do shell.
- **Ícones:** Material Symbols Rounded, com o eixo de preenchimento animado para estados ativos e hover (o ícone "se acende").
- **Vidro:** painéis translúcidos (`transparency` no tema), com o desfoque feito pelo Hyprland por uma regra de camada que o shell aplica sozinho (`hl.layer_rule` com `ignore_alpha`, para o véu escuro atrás dos painéis não ser desfocado). A tela de bloqueio desfoca o próprio wallpaper com o `MultiEffect` do Qt.
- **Interação:** "state layer" do Material 3 em todo botão: véu no hover e onda (ripple) a partir do ponto do clique. Seleções (launcher, menu de energia, abas) são um destaque único que desliza com mola até o item escolhido; no seletor de temas, é a fila que gira com mola.
- **Movimento:** as curvas e durações do Material 3, as mesmas do Caelestia, em `ThemeManager.anim`, usadas pelos componentes `Anim` e `ColorAnim`. As curvas "expressivas" dão o efeito de mola em movimento e tamanho; opacidade e cor usam curvas que não passam do alvo. O tema só ajusta a velocidade geral (`animation.scale`).

## Escopo

O Lucerna cresce por módulos, começando pelo essencial.

| Componente | Função |
| --- | --- |
| Barra | Uma aba centralizada, fundida à borda de cima de uma moldura fina que aparece nos quatro lados da tela junto com ela (um modelo só; nas configurações, só o conteúdo). Workspaces, hora e data (abre o painel superior), rede, volume e bateria (abrem as ações da central) e notificações (abrem as notificações da central). Sempre se esconde sozinha, sem reservar espaço: aparece ao encostar o mouse no topo, ao trocar de workspace e na área de trabalho vazia (por monitor), e some com um painel centralizado aberto; com o painel superior ou a central, fica à mostra e clicável |
| Painel superior | Desce do topo: visão geral (usuário com atalhos para configurações e energia, relógio, calendário, recursos, mídia com o espectro em volta da capa), mídia (capa redonda com o espectro em volta, controles, letra sincronizada), desempenho (CPU, GPU, memória, disco, rede) e clima. Abas reordenáveis; pode ficar aberto por cima das configurações |
| Central | Um bloco que sai da borda direita da moldura, sobre a área de trabalho, sem escurecer: ações em cima e notificações embaixo. Cada um abre e fecha sozinho (`Super+A`, `Super+N`), e os dois podem ficar abertos juntos (`Super+C`); sozinhas, as notificações sobem e ocupam a altura toda. `Esc` e o clique fora fecham os dois. As ações são tiles em duas colunas (Wi-Fi, Bluetooth, saída de áudio, bateria, microfone, luz noturna, não perturbe e não apagar a tela; o corpo liga e desliga, a setinha abre a página do recurso: redes, dispositivos, saídas e o volume de cada app com áudio aberto, entradas, bateria e perfil de energia) e os sliders de volume e brilho; a engrenagem abre as configurações. O ícone da barra escolhe a página que já vem aberta |
| Launcher | Três estilos: **compacto** (padrão; busca e lista curta de apps e ações), **completo** (categorias de aplicativos, arquivos por tipo e web, favoritos, grade e detalhes do app: ações do `.desktop`, descrição, versão e desenvolvedor) e **tela cheia** (gaveta de apps por categoria). Apps ordenados por uso |
| Configurações | Tópicos à esquerda e opções à direita: aparência, papel de parede, monitores, tela e ociosidade, luz noturna, mouse, teclado, área de transferência, captura de tela, transparência e desfoque, notificações, painéis, launcher, barra, painel superior, energia e bateria, atalhos e sobre |
| Monitores | Disposição arrastando num canvas (encaixe nas bordas, sempre num bloco só) e, por monitor, resolução, taxa, escala, rotação, espelhamento, VRR e 10 bits. Aplicar pede confirmação em todas as telas e volta sozinho em 15 s. Um arranjo salvo por conjunto de monitores, reaplicado ao conectar. Opcionalmente gravado em `~/.config/hypr/lucerna-monitors.lua`, que o `hyprland.lua` inclui, para valer desde o login |
| Mouse e teclado | Velocidade, aceleração, rolagem, touchpad e velocidade por mouse; layouts, repetição e opções do xkb. Botões extras do mouse e teclas extras mapeados para ações (painéis, mídia, janelas, enviar atalho, rodar comando) e teclas remapeadas de verdade (keymap gerado e validado). Só o que muda vai por cima do `hyprland.lua` |
| Luz noturna | Temperatura de cor por horário: do pôr ao nascer do sol (calculado localmente, pela cidade do clima), fixo ou sempre, com rampa de 30 min e "até a próxima virada" pelos tiles da central. Aplicada pelo `hyprsunset` (CTM do Hyprland) |
| Papel de parede | Por tema: o próprio (imagem e efeito animado em shader), só a imagem, qualquer um dos dez efeitos (nas cores do tema), uma imagem ou um vídeo/GIF do usuário. Vídeos convertidos uma vez por tela para tocar pela GPU. 30 ou 60 fps, no ritmo da tela; pausa com tela cheia, bloqueio e tela apagada |
| Notificações | Servidor de notificações próprio; popups num bloco que sai do canto superior direito, e a lista na central |
| Área de transferência | Histórico próprio (texto, imagem e arquivos, pelo módulo `clipboard` do `lucernad`), num painel à parte: busca, filtro, fixar, apagar, colar direto; persistente e limitado. Ignora senhas marcadas pelos gerenciadores |
| Visão geral | Workspaces em miniatura com as janelas no lugar (`ScreencopyView`, capturadas ao abrir, não ao vivo), ir, mover arrastando e fechar |
| Captura de tela | Seleção própria (área com alças, janela, tela), sem `slurp`; foto pelo `grim` e vídeo pelo `wf-recorder` (VA-API quando há), com espera, cursor e som. Aviso com abrir e mostrar na pasta; tempo de gravação na barra |
| Tela de bloqueio | Bloqueio próprio, no visual do tema ativo |
| Seletor de temas | Carrossel na parte de baixo da tela: as setas aplicam o tema do card central ao vivo, Enter mantém e Esc desfaz |
| OSD | Indicadores de volume e brilho, saindo da borda direita da tela |
| Ociosidade | Escurecer, desligar a tela, bloquear e suspender por tempo sem uso (`IdleMonitor`), com tempos na tomada e na bateria. Segura com mídia tocando, tela cheia e "Não apagar a tela". Substitui o `hypridle` |
| Menu de energia | Bloquear, suspender, reiniciar e desligar |
| Energia | Sem interface própria: avisos de bateria baixa, crítica, carga completa e carregador; ação no nível crítico; perfil de energia automático; modo leve na bateria (tudo configurável) |

O controle de ociosidade é do próprio shell; com ele, o `hypridle` deve ficar desligado. O shell é específico para o Hyprland; suporte a outros compositores não é objetivo, pelo menos por enquanto.

## Arquitetura

A arquitetura é feature-first com separação por camadas. Cada feature vive em sua própria pasta e se divide internamente em camadas; o que é compartilhado fica em `core/` e `services/`.

| Camada | Responsabilidade | Pode depender de |
| --- | --- | --- |
| `ui/` | Componentes visuais em QML, sem lógica de negócio | `state/`, `core/` |
| `state/` | Estado e lógica da feature (equivalente a um view model) | `services/`, `core/` |
| `services/` | Integração com o sistema: Hyprland, áudio, rede, bateria, brilho, notificações, sessão | Apenas Quickshell e o sistema |
| `core/` | Motor de temas, painéis, widgets base e configuração compartilhados | Apenas Quickshell |

Regras:

- As dependências só apontam para baixo, e uma feature nunca importa outra.
- A comunicação entre features passa por `services/` ou `core/`. Exemplo: o botão do launcher na barra chama `Panels.toggle("launcher")` em `core/panels/`, e o launcher reage a `Panels.isOpen("launcher")`. Os modais (launcher, temas, energia e a central) abrem sozinhos; o painel superior pode ficar aberto por cima das configurações (configurável em Configurações → Painéis).
- Toda conversa com o Hyprland fica em `services/Hypr.qml`.
- Os imports usam o sistema de módulos do Quickshell, em que cada pasta vira um módulo (`import qs.core.theme`, `import qs.features.bar.state`). Por isso os nomes de pasta são identificadores QML válidos: `themeSwitcher`, e não `theme-switcher`.

O repositório inteiro é a configuração do shell. Fora do código do shell ficam `dev/` (o ambiente de teste), `ci/` e `tests/` (os checks do CI), `.github/` e a documentação.

```
lucerna-shell/
├── shell.qml                   # ponto de entrada, monta as features
├── core/
│   ├── theme/ThemeManager.qml  # carrega o tema ativo e expõe os tokens; papel de parede por tema
│   ├── panels/Panels.qml       # quais painéis estão abertos; ponte entre features
│   ├── widgets/                # botões, ícones, medidores, abas, switch, slider, Select, EffectView, Anim, painéis base
│   ├── input/InputActions.qml  # o que um botão ou tecla pode fazer, nomes de teclas e botões
│   ├── input/ShellShortcuts.qml # atalhos do shell: padrões e comparação de combinações
│   ├── launcher/SearchEngines.qml # buscadores da web do launcher
│   ├── format/Format.qml       # números, tamanhos e tempos em pt-BR
│   ├── time/Sun.qml            # nascer e pôr do sol, sem rede
│   ├── nightlight/NightSchedule.qml # horário da luz noturna (central, configurações e a feature)
│   └── config/Config.qml       # preferências persistidas
├── services/
│   ├── Hypr.qml                # IPC do Hyprland (dialeto Lua)
│   ├── Audio.qml
│   ├── Network.qml
│   ├── Battery.qml
│   ├── Brightness.qml
│   ├── Notifications.qml
│   ├── Session.qml             # bloquear, suspender, reiniciar, desligar
│   ├── Bluetooth.qml           # adaptador e dispositivos (BlueZ)
│   ├── DevMode.qml             # simula ações que mudariam o sistema do host
│   ├── SystemStats.qml         # adaptador do módulo system do lucernad
│   ├── Lucernad.qml            # a conexão permanente com o lucernad
│   ├── lucerna/LucernaClient.qml # cliente do protocolo do Lucerna (JSON-RPC num socket Unix)
│   ├── Media.qml               # players MPRIS
│   ├── Web.qml                 # o módulo web do lucernad: configuração, busca de cidade
│   ├── Lyrics.qml              # adaptador do módulo web do lucernad (a letra)
│   ├── Weather.qml             # adaptador do módulo web do lucernad (o clima)
│   ├── Clipboard.qml           # adaptador do módulo clipboard do lucernad
│   ├── Capture.qml             # captura (grim), gravação (wf-recorder) e janelas visíveis
│   ├── NightLight.qml          # temperatura de cor pelo hyprsunset
│   ├── Monitors.qml            # monitores e arranjos (hl.monitor)
│   ├── Input.qml               # opções de entrada, binds e keymap (xkbcli)
│   ├── VideoWallpapers.qml     # vídeos convertidos por tela, em fila
│   ├── AppInfo.qml             # versão e desenvolvedor dos apps (pacman, AppStream)
│   ├── FileSearch.qml          # busca de arquivos do launcher (fd ou find)
│   └── scripts/                # video-wallpaper, app-info, file-search
├── features/
│   ├── bar/
│   ├── workspaces/             # visão geral dos workspaces (Super+Tab); IPC overview
│   ├── capture/                # painel de captura e gravação (Print); IPC capture
│   ├── clipboard/              # painel do histórico (Super+V); IPC clipboard
│   │   ├── ui/
│   │   └── state/
│   ├── dashboard/
│   ├── displays/               # reaplica o arranjo de monitores salvo
│   ├── energy/
│   ├── nightlight/             # leva a temperatura ao hyprsunset; IPC nightlight
│   ├── idle/                   # escurecer, apagar, bloquear e suspender por ociosidade
│   ├── input/                  # aplica mouse e teclado; ações dos binds (IPC action)
│   ├── settings/
│   ├── launcher/
│   ├── notifications/
│   ├── central/
│   ├── lockscreen/
│   ├── wallpaper/
│   ├── themeSwitcher/
│   ├── osd/
│   └── powerMenu/
├── themes/
│   ├── catppuccin-mocha.json   # um arquivo por tema (o padrão)
│   ├── wallpapers/             # papéis estáticos
│   ├── shaders/                # efeitos animados (.frag e .qsb), catálogo e textura de ruído
│   └── fonts/
├── ci/                         # os checks do CI (lint, rules, unit, smoke); o dev/ci.sh roda local
├── tests/                      # testes de unidade (runner.qml e *.test.js) e o escopo da cobertura
└── dev/                        # ambiente de teste e geradores (não é carregado pelo shell)
    ├── Dockerfile
    ├── hyprland.lua
    ├── run.sh
    ├── lucernad.sh             # compila o lucernad numa revisão fixa (container e fumaça)
    ├── lucernad.rev            # a revisão (SHA) do lucernad usada
    ├── ci.sh                   # roda os checks do CI no archlinux:latest, como no GitHub
    ├── test.sh                 # conferência visual: container lucerna-polish com a janela na tela
    ├── themes.py               # gera os temas e os papéis estáticos
    └── shaders.sh              # compila os efeitos
```

## Controle externo

Scripts e outros programas falam com o shell por `IpcHandler`. Os atalhos do shell não precisam: ele mesmo os registra no Hyprland (`hl.bind`), a partir de Configurações → Atalhos, e tira do `hyprland.lua` o que estiver nas mesmas teclas.

```sh
qs -c lucerna ipc call panels toggle launcher   # launcher, dashboard, settings, central, themes, power, clipboard, capture, overview (dismiss fecha só um)
qs -c lucerna ipc call central open rede        # as duas; bluetooth, som, energia, microfone, notificacoes ("" = sem trocar a página); toggle, close
qs -c lucerna ipc call controls toggle som      # só as ações, na página da entrada; open, close
qs -c lucerna ipc call notifications toggle     # só as notificações; open, close
qs -c lucerna ipc call dashboard open weather   # overview, media, performance, weather
qs -c lucerna ipc call session lock
qs -c lucerna ipc call brightness up            # up, down, set <0-100>
qs -c lucerna ipc call theme set nord           # get, list
qs -c lucerna ipc call notifications clear      # toggleDnd, count
qs -c lucerna ipc call launcher open files ""   # apps, documents, images, music, videos, web
qs -c lucerna ipc call wallpaper mode animated  # auto, static, toggle; modeFor <monitor> <modo>
qs -c lucerna ipc call monitors identify
qs -c lucerna ipc call action run play-pause    # as ações dos botões e teclas mapeados
```

Quem mudar o volume por fora (`wpctl`) também vê o OSD: o shell reage à mudança pelo PipeWire.

## Serviços externos

Dois recursos dependem de internet. Quem faz as requisições é o módulo `web` do `lucernad` (com cache em disco); o shell só manda a faixa e a configuração e mostra o que chega (`Lyrics`, `Weather` e `Web` são adaptadores). Cada busca só sai enquanto a aba que a mostra está aberta (o clima também pelo "Atualizar agora" das configurações):

| Serviço | Uso | O que é enviado |
| --- | --- | --- |
| [Open-Meteo](https://open-meteo.com) | Previsão do tempo, busca de cidade | Nome da cidade digitada e as coordenadas dela |
| [LRCLIB](https://lrclib.net) | Letras sincronizadas | Título, artista, álbum e duração da faixa |
| [Vagalume](https://www.vagalume.com.br) | Letras, só com a chave do usuário | Título e artista da faixa |

A localização não é descoberta pelo IP (o Caelestia usa o `ip-api.com` para isso): a cidade é digitada uma vez na aba Clima (ou nas configurações) e fica salva na config.

O **modo offline** (Configurações → Painel superior → Privacidade) desliga os dois de uma vez; a letra também pode ser desligada sozinha.

## Consumo

Os dados do painel só são coletados enquanto a aba que os mostra está visível: `SystemStats` assina os tópicos do `lucernad` (que mede a cada 2 s, só com assinante), a posição da mídia a cada 0,5 s, o pico do áudio só na aba Mídia e o clima a cada 30 min. Com o painel fechado, nada disso roda. A GPU em repouso não é acordada: o `lucernad` só lê a placa ativa e só chama a NVML com a NVIDIA em uso.

## Segurança da tela de bloqueio

- O bloqueio usa o protocolo `ext-session-lock`: se o shell cair, o Hyprland continua bloqueado.
- O estado de bloqueio fica em `PersistentProperties`, então recarregar o shell (por exemplo, ao salvar um arquivo) não desbloqueia a tela.
- A autenticação usa uma configuração PAM própria (`features/lockscreen/pam/password`), só com `pam_unix`, em vez do `login` do sistema.

## Ambiente de desenvolvimento

O sistema de desenvolvimento roda KDE Plasma, não Hyprland. Para testar, o Lucerna roda num **Hyprland aninhado dentro de um container Docker com Arch**, que abre como uma janela na sessão Wayland do host (`dev/run.sh`).

- **Ciclo rápido:** o repositório é montado em `~/.config/quickshell/lucerna` dentro do container, e o Quickshell recarrega sozinho quando um arquivo muda.
- **Dados reais:** o container recebe o socket do PipeWire e o D-Bus do sistema do host, então volume, bateria e rede mostram o estado real da máquina.
- **Modo de desenvolvimento:** `dev/run.sh` define `LUCERNA_DEV=1`. Nesse modo, ações que mudariam o sistema (suspender, reiniciar, desligar; ligar/desligar Wi-Fi e Bluetooth, conectar a redes e dispositivos, trocar o perfil de energia) só registram a ação e mostram uma notificação (`services/DevMode.qml`). Sem isso, elas chegariam ao host pelo D-Bus do sistema.
- **GPU:** só a GPU Intel é repassada; o container não tem os drivers da NVIDIA.
- **Tela de bloqueio:** o usuário do container é `dev`, com a senha `lucerna`.
- **Limitações:** o brilho é só leitura no container, porque ajustá-lo exige uma sessão do logind. A sessão completa (login pelo TTY, `hypridle`, PAM do sistema real) fica para uma VM QEMU com virgl, quando for preciso.

## Qualidade

Todo PR para o `main` passa por quatro checks obrigatórios e só pode ser mesclado com todos verdes; nem o administrador empurra direto no `main`.

- **`lint`**: `qmllint` com a árvore de módulos do Quickshell, sem nenhum aviso aceito; `shellcheck`; `ruff`; os JSON de tema.
- **`rules`**: as camadas desta proposta, acentos, espaços, shaders e temas gerados em dia, links locais e as supressões do `qmllint` (só as três registradas no spec do CI são aceitas).
- **`unit`**: testes de unidade no próprio `qs` (`tests/`), com 100% das funções puras de `core/` e dos serviços chamadas.
- **`smoke`**: o shell num `sway` headless (o Hyprland não sobe sem GPU), com cada painel aberto por IPC e nenhum aviso além dos de ambiente.

Os scripts ficam em `ci/` e rodam igual no GitHub e na máquina (`dev/ci.sh`). O que depende do Hyprland de verdade (workspaces reais, `hyprctl`) fica para o ambiente de teste e para a máquina real.

## Instalação

No sistema com Hyprland, o repositório é ligado ao diretório de configuração do Quickshell e iniciado pelo Hyprland:

```sh
ln -s ~/Documentos/projetos/lucerna-shell ~/.config/quickshell/lucerna
```

```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c lucerna")
end)
```

`dev/hyprland.lua` serve de referência para os atalhos do Hyprland (janelas e workspaces); os do shell ficam com ele.
