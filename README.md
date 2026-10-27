<p align="center"><img src="docs/assets/logo.svg" alt="Lucerna" height="120"></p>

# Lucerna

**Um shell de desktop completo para o Hyprland, escrito em Quickshell.**

Barra, painel superior, central, launcher, notificações, tela de bloqueio e uma tela de configurações que cobre do tema aos monitores, ao mouse e ao teclado. As animações usam as curvas de movimento do Material 3, e tudo sai de um tema em JSON, trocável ao vivo. Tudo em português.

![Painel superior aberto sobre a área de trabalho](docs/screenshots/hero.jpg)

## Destaques

- **Configurações de verdade, sem editar arquivo**: monitores arrastando, mouse, teclado, barra, painéis, energia, transparência e animações. Só o que você muda vai por cima do `hyprland.lua`, e "Voltar ao hyprland.lua" desfaz.
- **Botões e teclas mapeáveis**: os botões extras do mouse e as teclas extras do teclado (F13–F24, macro, mídia) podem abrir painéis, controlar a mídia, trocar de workspace, **enviar um atalho de teclado** para a janela ou rodar um comando.
- **Remapeamento real de teclas**, em qualquer programa e inclusive para modificadores (Caps Lock → Esc, Alt Gr → Super). O Lucerna gera o keymap, confere se ele compila e só então o entrega ao Hyprland.
- **Monitores arrastando**: a disposição se monta num canvas com encaixe magnético. Cada monitor tem resolução, taxa, escala, rotação, espelhamento, VRR e 10 bits. Aplicar pede confirmação em todas as telas e, sem resposta em 15 s, volta ao anterior.
- **Central em dois painéis**: ações (tiles de Wi-Fi, Bluetooth, saída de áudio, bateria, microfone e os liga/desliga, com uma página por recurso, e os sliders de volume e brilho) e notificações, flutuando à direita sobre a área de trabalho, cada um com o seu atalho, sozinhos ou juntos.
- **Os dez temas mais populares**: Catppuccin Mocha, Tokyo Night, Gruvbox Dark, Rosé Pine, Nord, Everforest, Kanagawa, Dracula, Matte Black e Decay Green, e as versões claras Catppuccin Latte e Rosé Pine Dawn, nas paletas oficiais, trocáveis ao vivo.
- **Papel de parede animado e leve**: cada tema tem um efeito em shader que combina com ele (aurora, bokeh, brasas, luar, neve, vaga-lumes, ondas, névoa, chuva digital), nas cores do tema, a 30 ou 60 fps e em meia resolução. Ele pausa sozinho com tela cheia, tela bloqueada ou tela apagada. Cada tema pode trocar o seu por outro efeito, por uma imagem sua ou por um **vídeo ou GIF**. O vídeo é convertido uma vez para a resolução da tela, sem tarjas, quadros repetidos nem áudio, e toca decodificado pela GPU.
- **Vidro de verdade**: o desfoque atrás dos painéis é do próprio Hyprland, e o tema ajusta também as bordas das janelas.
- **Leve por padrão**: cada serviço só coleta dados enquanto alguém mostra. Um modo offline desliga tudo o que usa a internet.

## Galeria

### Área de trabalho

A barra e as janelas com as bordas e o arredondamento que o tema aplica no Hyprland.

![Área de trabalho com a barra e duas janelas](docs/screenshots/desktop.jpg)

### Painel superior

Visão geral, mídia com letra sincronizada, desempenho e clima. Escorre da moldura de cima, logo abaixo da pílula da barra, e a altura acompanha a aba.

Os painéis que saem das bordas (o painel superior, a central, os popups de notificação e o OSD) são uma peça só com a tela: ao abrir o painel superior ou a central, uma moldura fina aparece nos quatro lados, a pílula da barra sobe e se funde a ela, e o painel incha da borda com a junção arredondada, como um líquido; ao fechar, tudo recolhe e a moldura some.

| Mídia | Desempenho |
| --- | --- |
| ![Aba Mídia](docs/screenshots/dashboard-media.jpg) | ![Aba Desempenho](docs/screenshots/dashboard-performance.jpg) |
| **Clima** | **Popups de notificação** |
| ![Aba Clima](docs/screenshots/dashboard-weather.jpg) | ![Notificações](docs/screenshots/notifications.jpg) |

### Central

Um bloco só que sai da borda direita, com as ações em cima e as notificações embaixo, sobre a área de trabalho. Cada painel abre e fecha sozinho (`Super+A` as ações, `Super+N` as notificações, e o sino da barra), e os dois podem ficar abertos juntos (`Super+C` abre o que falta, ou fecha os dois); sozinhas, as notificações sobem e ocupam a altura toda. Os tiles ligam e desligam no corpo e abrem a página do recurso na setinha. O ícone da barra escolhe a página das ações: o de rede abre a do Wi-Fi; o de som, a da saída de áudio; o de bateria, a da bateria; o mesmo ícone de novo fecha só as ações (a pílula fica fundida à moldura e clicável com a central aberta). `Esc` e o clique fora fecham os dois.

![Central: ações e notificações](docs/screenshots/central.jpg)

### Launcher, temas e barra

| Seletor de temas em carrossel | Launcher compacto |
| --- | --- |
| ![Seletor de temas em carrossel](docs/screenshots/themes.jpg) | ![Launcher compacto](docs/screenshots/launcher-compact.jpg) |
| **Gruvbox Dark** | **Nord** |
| ![Tema Gruvbox Dark](docs/screenshots/theme-gruvbox.jpg) | ![Tema Nord](docs/screenshots/theme-nord.jpg) |

A barra flutua no topo em dois estilos: **pílula** (o padrão, tudo à mostra) e **ilha** (só a hora, e expande com o mouse). Fica escondida até o mouse encostar no topo.

![Os dois estilos da barra](docs/screenshots/bars.png)

### Papel de parede

Cada tema tem o seu, e dá para trocar: o próprio, só a imagem parada, qualquer efeito animado (nas cores daquele tema) ou uma imagem, vídeo (MP4, WebM, MKV, MOV) ou GIF do computador, escolhido num navegador com miniaturas. O vídeo é preparado uma vez para tocar gastando o mínimo: vai para a resolução da tela, perde as tarjas pretas, os quadros repetidos e o áudio, e é decodificado pela GPU (VA-API). Um vídeo 4K de 47 MB, por exemplo, virou 537 KB e passou a gastar 1% do motor de vídeo da GPU, contra 8% antes. Cada monitor ganha a sua versão: ao conectar um de outra resolução ou proporção, como um ultrawide, a versão dele é feita em segundos, em segundo plano. Enquanto isso, ele toca a mais parecida. Há também a opção de deixar prontas as resoluções mais comuns.

![Configurações: papel de parede](docs/screenshots/settings-wallpaper.jpg)

| Neve (Nord) | Chuva digital (Decay Green) |
| --- | --- |
| ![Efeito Neve](docs/screenshots/wallpaper-neve.jpg) | ![Efeito Chuva digital](docs/screenshots/wallpaper-chuva.jpg) |

![Efeito Ondas (Kanagawa)](docs/screenshots/wallpaper-ondas.jpg)

### Launcher

Três estilos, escolhidos em Configurações → Launcher. O **completo** tem busca, categorias (aplicativos, arquivos por tipo e web), favoritos, uma grade e os detalhes do app: as ações do `.desktop` com `Ctrl+1…9`, a descrição, a versão e o desenvolvedor. O de **tela cheia** é uma gaveta de apps separada por categoria. O **compacto** é uma busca com lista curta.

| Completo | Tela cheia |
| --- | --- |
| ![Launcher completo](docs/screenshots/launcher-full.jpg) | ![Launcher em tela cheia](docs/screenshots/launcher-grid.jpg) |

### Configurações

| Aparência | Monitores |
| --- | --- |
| ![Configurações: aparência](docs/screenshots/settings-appearance.jpg) | ![Configurações: monitores](docs/screenshots/settings-monitors.jpg) |
| **Teclado** | **Mouse** |
| ![Configurações: teclado](docs/screenshots/settings-keyboard.jpg) | ![Configurações: mouse](docs/screenshots/settings-mouse.jpg) |

### Bloqueio, energia e OSD

| Tela de bloqueio | Menu de energia |
| --- | --- |
| ![Tela de bloqueio](docs/screenshots/lock.jpg) | ![Menu de energia](docs/screenshots/power.jpg) |

![OSD de brilho](docs/screenshots/osd.png)

## O que tem

| Parte | O que faz |
| --- | --- |
| **Barra** | Workspaces, hora e data, rede, som, bateria e notificações. Pílula ou ilha, flutuante, e se esconde sozinha. Na área de trabalho vazia fica sempre à mostra, e aparece por um instante ao trocar de workspace. |
| **Painel superior** | Visão geral (perfil, relógio, calendário, clima, recursos e mídia, com a capa num círculo e o espectro do som em volta, pelo `lucernad`), mídia com letra sincronizada (LRCLIB) e o espectro em volta da capa, desempenho (CPU, GPU, memória, disco e rede) e clima (Open-Meteo, pelo `lucernad`): a cidade e o dia, o nascer e o pôr do sol, o agora e os próximos sete dias. Abas reordenáveis e opção de abrir ao parar o mouse na hora. |
| **Central** | Dois painéis flutuantes na direita, independentes (`Super+A`, `Super+N`, os dois com `Super+C`, ou pelos ícones da barra): ações e notificações. As ações são tiles em duas colunas (Wi-Fi, Bluetooth, saída de áudio, bateria, microfone, luz noturna, não perturbe e não apagar a tela; cheios quando ligados), com uma página por recurso: a lista de redes, com senha; os dispositivos Bluetooth, para parear; as saídas e o volume de cada app com áudio aberto; o microfone e as entradas; a bateria (um card em forma de bateria, cheio até a carga), o perfil de energia (Economia, Equilibrado e Turbo), o consumo da última hora num gráfico e a bateria dos dispositivos Bluetooth. Embaixo, os sliders largos de volume e de brilho da tela em foco, com a porcentagem; a engrenagem abre as configurações. |
| **Notificações** | Popups com ações, pausa no mouse e prazo ajustável, não perturbe e a lista na central. |
| **Launcher** | Três estilos: compacto (busca e lista), completo (categorias de aplicativos, arquivos, documentos, imagens, músicas, vídeos e web, com favoritos, grade e detalhes: ações do app, descrição, versão e desenvolvedor) e tela cheia (gaveta de apps por categoria). Os apps mais abertos vêm primeiro, com os favoritos na frente. Em todos os estilos: clique direito num item para as opções, `Ctrl+F` fixa ou tira dos favoritos e `Ctrl+H` oculta; no compacto e na tela cheia, `/texto` busca arquivos e `?texto` pesquisa na web. A busca de arquivos usa o `fd` quando há, e, sem busca, mostra os recentes. |
| **Área de transferência** | Histórico num painel próprio (`Super+V`), pelo `lucernad`: textos, imagens (com miniatura) e arquivos, busca com o trecho em negrito, filtro, fixar e apagar. Escolher copia e cola na janela em foco (Ctrl+Shift+V nos terminais). Senhas marcadas pelos gerenciadores ficam de fora. |
| **Visão geral** | Os workspaces em miniatura (`Super+Tab`), com as janelas no lugar e a imagem de cada uma (também dos workspaces escondidos). Clicar vai para o workspace ou a janela, arrastar uma janela a leva para outro workspace e o botão do meio a fecha. Setas e Enter, ou 1–9. |
| **Captura de tela** | Painel próprio (`Print`): foto ou vídeo, de uma área (arrastando, com alças), de uma janela (clicando) ou da tela, com espera, cursor e som. A foto vai para a pasta e para a área de transferência, com um aviso que abre o arquivo ou a pasta; a gravação (pela GPU quando dá) mostra o tempo na barra e para ao clicar. Também tela inteira (`Shift+Print`) e janela ativa (`Ctrl+Print`) direto. |
| **Tela de bloqueio** | Relógio e senha (PAM). |
| **Energia** | Menu (bloquear, suspender, sair, reiniciar, desligar). Avisos de bateria baixa e crítica, ação no nível crítico com prazo para cancelar, troca de perfil na tomada e modo leve na bateria. |
| **OSD** | Volume e brilho, saindo da borda direita (não aparece com a central aberta, que já mostra os dois). |
| **Ociosidade** | Escurece, desliga a tela, bloqueia e suspende depois de um tempo sem uso, com tempos próprios na tomada e na bateria, sem precisar do `hypridle`. Segura com mídia tocando, com app em tela cheia e com "Não apagar a tela" (nos tiles da central, para apresentações). |
| **Luz noturna** | Tela mais quente à noite, do pôr ao nascer do sol (pela cidade do clima, calculado sem rede), num horário fixo ou sempre, entrando e saindo aos poucos. Nos tiles da central, liga ou desliga até a próxima virada. Usa o `hyprsunset`, que muda a cor no hardware, sem custo para a GPU. |
| **Papel de parede** | Imagem com transição na troca e efeito animado por cima (shader, a 30 ou 60 fps, no ritmo da tela, e em meia resolução). Pausa com app em tela cheia, tela bloqueada ou tela apagada, e opcionalmente com qualquer janela aberta; no automático, fica parado na bateria. Modo e origem por monitor. |
| **Temas** | Doze prontos, nas paletas oficiais: Catppuccin Mocha (padrão), Tokyo Night, Gruvbox Dark, Rosé Pine, Nord, Everforest, Kanagawa, Dracula, Matte Black e Decay Green, e os claros Catppuccin Latte e Rosé Pine Dawn. Cada um vem com papel estático, efeito animado, fonte própria e bordas do Hyprland. Trocam ao vivo pelo seletor em carrossel (`Super+T`): as setas aplicam o tema do card central depois de uma breve espera, Enter mantém e Esc ou o clique fora desfazem. |

### Configurações

| Tópico | Opções |
| --- | --- |
| **Aparência** | Tema, contorno nos cartões e velocidade das animações. |
| **Papel de parede** | Por tema: o próprio, a imagem parada, um efeito animado ou uma imagem, vídeo ou GIF seu (com preencher ou inteira). Tem ainda o modo de exibição (automático, animado ou parado), modo e papel por monitor, quadros por segundo, parado na bateria, pausar com janelas e resolução cheia. |
| **Monitores** | Disposição arrastando, resolução, taxa de atualização, escala, rotação, espelhar, VRR e cor de 10 bits. Tem "Identificar" e aplicar com confirmação. O arranjo fica salvo por conjunto de monitores e é reaplicado ao conectar; com "desde o login", vai também para um arquivo que o `hyprland.lua` inclui, e vale antes de o shell subir. |
| **Tela e ociosidade** | Brilho de cada tela (inclusive monitores externos por DDC/CI), ligar ou desligar, os tempos de escurecer, desligar a tela, bloquear e suspender (na tomada e na bateria), segurar com mídia ou tela cheia e "Não apagar a tela". Avisa se o `hypridle` estiver rodando. |
| **Luz noturna** | Ligar, temperatura (com prévia ao ajustar) e horário: pôr do sol, fixo ou sempre. |
| **Mouse** | Velocidade, aceleração, canhoto, foco das janelas (ao passar o mouse ou ao clicar), rolagem, touchpad (tocar para clicar, arrastar, desligar ao digitar, clique com dedos, botão do meio), **botões mapeados** e velocidade própria por mouse. |
| **Teclado** | Layouts (até quatro, com variante e atalho para trocar), repetição, Num Lock, teclas especiais (Caps Lock, Compose, trocar Alt e Super) e qualquer opção do xkb, com busca. Também **teclas remapeadas** e **teclas extras e atalhos**. |
| **Área de transferência** | Guardar o histórico, quantos itens, manter ao reiniciar, colar ao escolher e limpar (com ou sem os fixados). |
| **Captura de tela** | Copiar a foto, cursor, quadros por segundo e som da gravação, e as pastas. |
| **Transparência e desfoque** | Opacidade dos painéis e dos cartões e intensidade do desfoque, por cima do tema. |
| **Notificações** | Não perturbe e tempo na tela. |
| **Painéis** | Se o painel superior abre junto das configurações. |
| **Launcher** | Estilo, buscador da web, favoritos (ordem e remoção), apps ocultos e histórico de uso. |
| **Barra** | Pílula ou ilha, data, mostrar na área vazia e ao trocar de workspace. |
| **Painel superior** | Abas, abrir e fechar pelo mouse, cartões, semana, letra, espectro da capa, intervalo do desempenho, GPU, cidade, unidades e **modo offline**. |
| **Energia e bateria** | Porcentagem na barra, avisos, ação no nível crítico, perfil automático, economia abaixo de um nível e modo leve. |
| **Atalhos** | As teclas do shell (painéis, bloqueio, som, mídia e brilho): trocar, acrescentar, tirar e voltar ao padrão. Avisa quando a tecla era de outro atalho, da aba Teclado ou do `hyprland.lua`. |

## Requisitos

- **Hyprland 0.56+**, com a configuração em Lua (`hyprland.lua`)
- **Quickshell 0.3.1+**
- **lucernad** (o daemon do Lucerna): CPU, memória, rede, discos, temperatura e GPU da aba Desempenho e do card de recursos, o espectro do som do player em volta da capa (pelo PipeWire), o histórico da área de transferência (pelo protocolo de controle de dados do Wayland), o brilho das telas (a integrada pelo logind e os monitores externos por DDC/CI, que precisam da regra udev e do módulo `i2c-dev` do README do lucernad), o gráfico de consumo da bateria e os perfis de energia (pelo UPower e pelo power-profiles-daemon, no D-Bus); sem ele, aparecem como indisponíveis, o anel fica parado, o histórico fica desligado e o slider de brilho some. Instalação no [README do lucernad](https://github.com/lucerna-desktop/lucernad#instalação).
- **Fonte de ícones**: `ttf-material-symbols-variable` (repositório oficial do Arch)
- Opcionais, cada um liga uma parte:
  - PipeWire: volume e mídia
  - UPower: bateria e perfis de energia
  - NetworkManager: rede
  - BlueZ: Bluetooth
  - `hyprsunset`: luz noturna
  - `grim` e `wf-recorder`: captura de tela e gravação
  - `fd`: busca de arquivos do launcher mais rápida (sem ele, usa o `find`)
  - `ffmpeg` e `qt6-multimedia-ffmpeg`: papel de parede em vídeo ou GIF. Para a GPU decodificar o vídeo, também o driver VA-API (`intel-media-driver` na Intel, `libva-mesa-driver` na AMD) e o `libva-utils`, que o shell usa para detectar o suporte.
- Serviços na internet, pedidos pelo `lucernad`, só enquanto a aba correspondente está aberta, e desligáveis pelo modo offline: [Open-Meteo](https://open-meteo.com) (clima), [LRCLIB](https://lrclib.net) (letras) e [Vagalume](https://www.vagalume.com.br) (letras, só com a chave do próprio usuário, nas configurações).

O remapeamento de teclas usa o `xkbcli`, que vem com o libxkbcommon, dependência do próprio Hyprland.

## Instalação

```sh
git clone https://github.com/lucerna-desktop/lucerna-shell
ln -s "$PWD/lucerna-shell" ~/.config/quickshell/lucerna
```

No `hyprland.lua`:

```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c lucerna")
end)

-- Opcional, no fim: o arranjo de monitores do Lucerna já no login
-- (Configurações → Monitores → "Usar o arranjo desde o login").
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/lucerna-monitors.lua")
```

Os atalhos do shell vêm prontos e se editam em Configurações → Atalhos:

| Atalho | Ação |
| --- | --- |
| `Super+Espaço` | Launcher |
| `Super+Tab` | Visão geral dos workspaces |
| `Super+V` | Histórico da área de transferência |
| `Print` / `Shift+Print` / `Ctrl+Print` | Captura (painel) / tela inteira / janela ativa |
| `Super+Print` | Gravar a tela ou parar |
| `Super+D` | Painel superior |
| `Super+S` | Configurações |
| `Super+A` / `Super+N` / `Super+C` | Ações / notificações / as duas (se as duas estão abertas, fecha as duas) |
| `Super+T` | Seletor de temas |
| `Super+Esc` | Menu de energia |
| `Super+L` | Bloquear a tela |
| Teclas de volume, mudo, microfone, mídia e brilho | O mesmo, com o OSD |

Mudou: `Super+N` (a ação `notifications`) agora abre só as notificações; a central inteira (ações e notificações) fica em `Super+C`.

O shell fica com essas teclas: se o `hyprland.lua` também tiver alguma delas, a dele sai (até o próximo reload). Então tire do `hyprland.lua` os atalhos antigos do Lucerna, se houver. Os do Hyprland (janelas, workspaces) continuam lá; o [`dev/hyprland.lua`](dev/hyprland.lua) tem um exemplo. As regras de desfoque dos painéis são aplicadas pelo próprio shell, sem mexer no `hyprland.lua`.

## Comandos IPC

Tudo pode ser chamado de fora com `qs -c lucerna ipc call <alvo> <função> [argumentos]`.

| Alvo | Funções |
| --- | --- |
| `panels` | `open <nome>`, `toggle <nome>`, `dismiss <nome>` (fecha só esse), `close` (fecha todos), `get`. Nomes: `launcher`, `dashboard`, `central` (as ações e as notificações juntas), `settings`, `themes`, `power`, `clipboard`, `capture`, `overview` |
| `dashboard` | `open <aba>` (`overview`, `media`, `performance`, `weather`), `toggle` |
| `central` | As ações e as notificações. `open <entrada>` abre as duas (`rede`, `bluetooth`, `som`, `energia`, `microfone` abrem a página do recurso nas ações; `notificacoes`, o estado inicial; `""` não troca a página), `toggle <entrada>` (sem entrada: fecha as duas se as duas estão abertas, senão abre o que falta; com entrada: fecha só se as duas estão abertas por ela), `close` |
| `controls` | Só as ações: `open <entrada>`, `toggle <entrada>` (a mesma entrada, ou `""`, fecha), `close` |
| `settings` | `open <tópico>` (`appearance`, `wallpaper`, `displays`, `idle`, `nightlight`, `launcher`, `clipboard`, `capture`, `mouse`, `keyboard`, `glass`, `notifications`, `panels`, `bar`, `dashboard`, `power`, `shortcuts`, `about`) |
| `notifications` | `open`, `toggle`, `close` (o painel das notificações), `clear`, `toggleDnd`, `count` |
| `launcher` | `open <categoria> <busca>` (`apps`, `files`, `documents`, `images`, `music`, `videos`, `web`; a busca pode ser `""`), `toggle` |
| `session` | `lock`, `isLocked` |
| `theme` | `set <id>`, `get`, `list` |
| `brightness` | `up`, `down`, `set <0-100>` (a tela em foco), `setFor <id> <0-100>`, `list` (as telas e os ids: `backlight`, `ddc:<conector>`, ex.: `ddc:HDMI-A-1`) |
| `monitors` | `identify` |
| `overview` | `toggle` |
| `capture` | `open <shot\|record>` (o painel; `""` = o último), `screen`, `window` (direto), `record` (gravar ou parar), `stop` |
| `clipboard` | `toggle`, `open`, `clear` (menos os fixados), `count` |
| `nightlight` | `enable <true\|false>` (liga ou desliga a função), `toggle` (agora, até a próxima virada do horário), `temperature <K>`, `status` |
| `idle` | `inhibit <true\|false>` (não apagar a tela), `toggle`, `status` |
| `wallpaper` | `mode <auto\|animated\|static\|toggle>`, `modeFor <monitor> <modo>` (`default` volta ao geral), `get` |
| `action` | `run <id>`: as mesmas ações dos botões e teclas mapeados (`launcher`, `play-pause`, `volume-up`, `lock`…; a lista está em [`core/input/InputActions.qml`](core/input/InputActions.qml)) |
| `battery` | `simulate <0-100> <true\|false>` e `real`, só no ambiente de desenvolvimento |

## Temas

Cada arquivo em `themes/*.json` é um tema, e o nome do arquivo é o id. Os temas embutidos são gerados por `dev/themes.py` a partir das paletas (o JSON e o papel estático). Para criar um, acrescente a paleta ao script, ou copie o `themes/catppuccin-mocha.json` (o padrão) e mude as cores e o wallpaper: ele aparece no seletor na hora. Além de cores, fontes, raios e espaçamentos, o tema define:

- `transparency`: `enabled`, `base` (opacidade dos painéis) e `layers` (dos cartões dentro deles).
- `hyprland`: bordas, arredondamento e intensidade do desfoque (`blurSize`, `blurPasses`), aplicados via `hyprctl eval`.
- `wallpaper`: a imagem (`"wallpapers/nord.jpg"`) ou `{ "static": ..., "shader": "shaders/neve.qsb" }` (a taxa de quadros é do usuário, 30 ou 60). Os efeitos ficam em `themes/shaders/`, com a fonte GLSL ao lado do `.qsb` compilado. `dev/shaders.sh` recompila todos, e isso requer o `qsb`, do pacote `qt6-shadertools`. Todo efeito recebe os mesmos uniforms (`time`, `resolution`, `base`, `surface`, `accent`, `text`), então qualquer tema pode usar qualquer efeito, e um efeito novo entra no catálogo em `themes/shaders/effects.json`.
- `animation.scale`: velocidade geral das animações (1 = padrão, 0 = desligadas).
- `fonts`: fontes que o tema traz em `themes/fonts/`, carregadas pelo shell sem instalar nada no sistema. Todos os temas embutidos trazem a Rubik, sob licença OFL.
- `surfaces.outline`: contorno fino nos cartões. O padrão é sem contorno; os cartões se destacam pelo tom.
- `colors.track`: cor opcional dos trilhos de medidores e sliders.

Transparência, desfoque, contorno e velocidade das animações também se ajustam nas configurações, por cima de qualquer tema. "Restaurar padrões do tema" desfaz.

## Onde ficam as preferências

Em `~/.local/state/quickshell/by-shell/<id>/config.json`. Os ajustes de monitores, mouse e teclado guardam **só o que foi mudado**; o resto continua vindo do `hyprland.lua`. O Lucerna reaplica esses ajustes ao iniciar, quando um monitor é conectado e depois de um `hyprctl reload`. O keymap gerado para as teclas remapeadas fica ao lado, em `keymap.xkb`.

## Arquitetura

Organizado por feature, com camadas que só olham para baixo:

```
core/       tema, config, painéis, widgets e o catálogo de ações de entrada
services/   a conversa com o sistema: Hyprland, PipeWire, UPower, NetworkManager,
            BlueZ, MPRIS, notificações, monitores, entrada, clima…
features/   uma pasta por parte do shell (bar, dashboard, central, settings,
            launcher, input, displays, idle, nightlight…), cada uma com state/ e ui/
```

- A `ui` fala com o `state` da própria feature, e o `state` fala com `services` e `core`.
- Uma feature não importa outra. Quando precisam conversar, a conversa passa pelo `core`: por exemplo, o `Panels` diz quais painéis estão abertos.

Os princípios e o desenho completo estão em [`Lucerna — Proposta.md`](<Lucerna — Proposta.md>). O desenho dos wallpapers animados está em [`Lucerna — Proposta do Wallpaper.md`](<Lucerna — Proposta do Wallpaper.md>), os plugins próprios planejados, em [`Lucerna — Plugins Próprios.md`](<Lucerna — Plugins Próprios.md>), e o que falta fazer, na ordem, em [`Lucerna — Pendências.md`](<Lucerna — Pendências.md>).

## Desenvolvimento

O shell roda num Hyprland aninhado, dentro de um container Docker com Arch, que abre como uma janela na sessão Wayland do host. O repositório é montado em `~/.config/quickshell/lucerna` dentro do container, então o Quickshell recarrega sozinho quando um arquivo muda.

```sh
dev/run.sh            # constrói a imagem na primeira vez e abre a janela
dev/run.sh --build    # reconstrói a imagem (ex.: depois de mudar o Dockerfile)
dev/run.sh shell      # abre um bash no container em execução
dev/run.sh log        # segue o log do Quickshell
```

No host é preciso Docker, uma sessão Wayland e o usuário no grupo `docker`.

- Volume, bateria e rede mostram o estado real do host: o PipeWire e o D-Bus do sistema são repassados ao container. A exceção é o que vem do módulo de energia do `lucernad`: com a raiz falsa do brilho (abaixo), ele não fala com o D-Bus do sistema, então os botões de perfil de energia somem e o gráfico de consumo fica em "Medindo".
- Com `LUCERNA_DEV=1`, definido pelo `run.sh`, as ações que chegariam ao host são só simuladas: suspender, reiniciar e desligar, ligar e desligar Wi-Fi e Bluetooth, conectar a redes e dispositivos, e o perfil de energia. A leitura é real.
- O brilho no container é o de uma tela integrada falsa: o `lucernad` sobe com `LUCERNAD_POWER_ROOT=/tmp/lucerna-power` (a árvore criada pelo `ci/power-root.sh`) e os ajustes gravam no arquivo `brightness` dessa árvore, nunca no host (o container vê o `/sys` e o D-Bus do sistema dele). Sem monitores externos.
- A senha da tela de bloqueio no container é `lucerna` (usuário `dev`).
- Para testar a aba Mídia, a imagem tem `mpv` com `mpv-mpris`: rode `dev/run.sh shell` e depois `mpv --no-video arquivo.mp3`.
- Para testar monitores, crie saídas virtuais: `hyprctl output create headless`.

Atalhos no Hyprland aninhado (a tecla de mod é `Alt`, para não brigar com o desktop do host; os do shell usam `Alt` também, no lugar de `Super`):

| Atalho | Ação |
| --- | --- |
| `Alt+Space` | Launcher |
| `Alt+S` | Configurações |
| `Alt+D` | Painel superior (também clicando na hora da barra). Dentro dele, `Tab`/`Shift+Tab` ou `1`–`4` trocam de aba |
| `Alt+A` | Ações da central |
| `Alt+N` | Notificações da central |
| `Alt+C` | As duas |
| `Alt+T` | Seletor de temas |
| `Alt+Esc` | Menu de energia |
| `Alt+L` | Bloquear a tela |
| `Alt+↑` / `Alt+↓` / `Alt+M` | Volume / mudo |
| `Alt+→` / `Alt+←` | Brilho |
| `Alt+Enter` | Abrir o kitty |
| `Alt+Q` | Fechar a janela |
| `Alt+1..5` / `Alt+Shift+1..5` | Ir para o workspace / mover a janela |
| `Alt+Shift+R` | Reiniciar o Quickshell |
| `Alt+Shift+E` | Sair do Hyprland |

### CI

Todo PR para o `main` passa por quatro checks, e só pode ser mesclado com todos verdes:

| Check | O que confere |
| --- | --- |
| `lint` | `qmllint` (qualquer aviso reprova), `shellcheck`, `ruff` e os JSON de tema (pelo menos um tema) |
| `rules` | camadas, acentos, espaços, shaders e temas gerados em dia, links locais e as supressões do `qmllint` (só as três registradas) |
| `unit` | os testes de `tests/` no `qs`, com 100% das funções do escopo de `tests/coverage.json` chamadas |
| `smoke` | o shell num `sway` headless: cada painel aberto por IPC, capturas e nenhum aviso fora de `ci/tolerated.txt` |

Os mesmos scripts de `ci/` rodam no GitHub e aqui, no mesmo container (`archlinux:latest`), e cada job começa num container novo:

```sh
dev/ci.sh              # os quatro
dev/ci.sh unit         # só um (lint, rules, unit, smoke)
dev/ci.sh shell lint   # um bash no container de um check, com o repositório em /src
```

A saída fica em `ci-out/<check>/`. Como escrever um teste e o que a cobertura exige está no [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Créditos

A página Créditos, nas Configurações, traz o mesmo conteúdo, com o link de cada item.

**Inspiração**

- [Caelestia Shell](https://github.com/caelestia-dots/shell): o painel superior (o dashboard que desce da barra, com as abas Painel, Mídia, Desempenho e Clima) e a aba Clima foram inspirados no dashboard dele, assim como as curvas e durações de animação do Material 3 em `ThemeManager.anim`; GPL-3.0. O código do Lucerna foi escrito do zero, com componentes, serviços e recursos próprios; do Caelestia vieram a ideia e a referência visual. Obrigado ao projeto e a quem contribui com ele.

**Dados**

- [Open-Meteo](https://open-meteo.com/): previsão do tempo e busca de cidade; dados sob a licença CC BY 4.0.
- [LRCLIB](https://lrclib.net/): letras sincronizadas.
- [Vagalume](https://www.vagalume.com.br/): letras, só com a chave de quem usa.

**Base**

- [Quickshell](https://quickshell.org/)
- [Hyprland](https://hyprland.org/)
- [Material Symbols](https://fonts.google.com/icons): a fonte dos ícones, do Google; Apache 2.0.

### Aviso sobre o Vagalume

Os termos da API do Vagalume pedem crédito, com link, junto do conteúdo, e dizem que a API não transfere o direito de exibir a letra. O Lucerna é de uso próprio: a chave é de cada usuário e usar o Vagalume é escolha dele. O Lucerna não traz chave nenhuma.

O crédito existe, portanto, de forma indireta: para usar o Vagalume, a pessoa precisa obrigatoriamente entrar no site deles e gerar a própria chave em <https://auth.vagalume.com.br/settings/api/>, e é por essa chave dela que a letra chega. Se o Vagalume pedir, o rótulo com link junto da letra é acrescentado (o `lucernad` já manda a fonte e a página).

## Licença

GPL-3.0. O texto está em [`LICENSE`](LICENSE).
