# Painéis que saem da moldura da tela

**Data:** 2026-10-27
**Repositório:** `lucerna-shell`
**Referência:** o Caelestia Shell (`~/Documentos/projetos/caelestia-lab/shell`, só leitura): `modules/drawers/ContentWindow.qml` (a moldura `BlobInvertedRect` e os fundos `BlobRect` num `BlobGroup`), `modules/drawers/Panels.qml` (de que borda cada painel sai) e `plugin/src/Caelestia/Blobs/shaders/blob.frag` (a união suave por SDF).
**Protótipo:** branch local `spike/painel-barra` (`a737fb0`), descartável; o relatório e as capturas estão no scratchpad da sessão (`spike-painel/`).

## Por quê

Hoje cada painel é um cartão solto que desce ou desliza. O usuário quer a fluidez do Caelestia: a moldura da tela aparece e os painéis "escorrem" dela, como uma peça só, com cantos côncavos na junção.

## Decisões do usuário

- **A barra superior fica só nos estilos centralizados:** saem a Faixa (`strip`, de ponta a ponta) e as Três ilhas (`islands`); ficam a Pílula (`pill`) e a Ilha (`island`), as duas sempre se escondendo sozinhas (a opção de esconder deixa de existir). A página da barra nas Configurações passa a ser só a organização do conteúdo (o que aparece e onde).
- **Moldura que aparece com os painéis:** sem painel aberto, não há moldura. Ao abrir um painel, surge uma moldura fina nos quatro lados da tela (cantos de dentro arredondados, como no Caelestia) e o painel incha a partir dela; ao fechar, o painel recolhe e a moldura some.
- **Variante líquida:** a forma é desenhada por um shader com união suave por SDF (como o do Caelestia), num `ShaderEffect` do QML (sem plugin em C++). O protótipo mediu a variante vetorial e a líquida: desempenho empatado com a `main` (≈ 60 FPS, mesma CPU, sem redesenho parado, sem crescer memória).
- **A pílula se funde à moldura (recomendação aceita):** quando a moldura aparece, a pílula (ou a ilha) sobe e se derrete na borda de cima, virando um trecho mais grosso da moldura; ela continua visível e funcional (hora, workspaces, status) com qualquer painel aberto. Ao fechar tudo, a moldura afina, a pílula se descola e volta a flutuar (e se esconde, se for a hora). *(Substituída pela decisão seguinte.)*
- **Um único modelo de barra, fundido à moldura (decisão de 2026-10-27, depois de ver a fase 2 no container):** a barra superior deixa de flutuar. Há um modelo só, a aba fundida à borda de cima da moldura (a pílula derretida nela, com os cantos côncavos), personalizável só no conteúdo e sempre se escondendo sozinha. Revelar a barra (o mouse na borda de cima, a troca de workspace, o workspace vazio) mostra a moldura nos quatro lados, com a mesma animação dos painéis, junto com a barra fundida, pela mesma forma única do shader; ao sair, tudo recolhe. Abrir o painel superior ou a central também mostra a moldura com a barra. Saem a Pílula e a Ilha como escolha (e o seletor de estilo na página da barra); qualquer `barStyle` antigo no config é ignorado. A página da barra fica com o conteúdo (a data) e com "mostrar com o workspace vazio" e "aparecer ao trocar de workspace". A barra continua clicável por cima dos painéis da moldura.
- **O painel superior é a barra transformada (decisão de 2026-10-27, ao ver a barra fundida no container):** ao abrir o painel superior, a aba da barra se alarga até a largura dele e cresce para baixo, uma peça só (sem vão nem duas formas), com a mesma mola; o conteúdo da barra (workspaces, hora, status) esmaece no começo, e o topo da peça passa a ser o cabeçalho do painel, a fileira de abas, seguida do conteúdo. Ao fechar, a peça encolhe de volta para a aba e o conteúdo da barra reaparece (se a barra ainda tiver motivo para estar à mostra; senão, tudo recolhe). Com o painel superior aberto, a barra não fica clicável por cima dele (ela virou o painel); por cima da central, continua.
- **De onde cada painel sai:**
  - painel superior (dashboard): da própria barra, fundida à moldura de cima (ver acima);
  - central (ações e notificações): da borda direita, um bloco só, como a sidebar do Caelestia;
  - ~~popups de notificação: do canto superior direito; com a central aberta, ficam dentro dela;~~ (saíram da moldura; ver abaixo)
  - OSD de volume e brilho: da borda direita, no meio da altura, vertical.
- **Os popups de notificação saem da moldura (decisão de 2026-10-27, na revisão final):** voltam a ser cartões soltos no canto superior direito, como na `main` (fundo e cantos próprios, a mesma entrada e saída deslizando pela direita), e a chegada de uma notificação não faz a moldura aparecer nem entra na forma do shader. Com a central aberta, continuam escondidos, e a lista dela mostra as mesmas.
- **O mouse no topo sempre traz a barra (decisão de 2026-10-27, na revisão final):** como na `main`, inclusive com uma janela maximizada ou em tela cheia. A troca de workspace e o workspace vazio não trazem a barra por cima de uma janela em tela cheia de verdade (a maximizada não conta).
- **Ficam como estão (centralizados):** launcher, configurações, área de transferência, menu de energia, seletor de temas, visão geral dos workspaces, captura.

## Objetivos

- Uma forma única por monitor (moldura + pílula + fundos dos painéis abertos) com a junção líquida, a cor e a transparência da barra (`ThemeManager.glass(colors.base, 0)`) e o desfoque do Hyprland funcionando, inclusive nos cantos côncavos.
- Animação com as molas de hoje (`ThemeManager.anim`): a moldura engrossa de 0 até a espessura final (≈ 8–10 px) enquanto o painel incha; o conteúdo do painel entra quando a forma já passou de ~70% (era ~60%; subiu na revisão final, pelo quadro de diferença entre a janela da forma e a do conteúdo).
- Desempenho igual ao de hoje: nada redesenha com tudo parado; nenhum crescimento de memória.
- As janelas não mudam de tamanho: a moldura é desenhada por cima da beira da tela, sem reservar espaço.

## Não objetivos

- Barra embaixo ou nos lados; moldura permanente (sem painel aberto).
- Mudar os painéis centralizados.
- Navegação por teclado nova.

## Anti-objetivos

- Dupla transparência na junção (pílula e painel sobrepostos com alfa somado), anel visível em volta da pílula.
- O Hyprland "piscando" a forma (o fade de camada deixava a forma mais clara no começo: o protótipo precisou de `no_anim` nas camadas dos painéis — a versão final faz isso pela regra de camada que o shell já envia ao Hyprland, não à mão).
- Painel preso à pílula/moldura do monitor errado.

## O que fica para o construtor

- A organização das janelas (uma camada de forma por monitor + o conteúdo de cada painel por cima, ou outra divisão), desde que a forma seja uma só por monitor para a fusão funcionar e o clique passe pelas áreas vazias.
- A espessura exata da moldura, o raio dos cantos de dentro e a suavização (`k`) da união, ajustados para parecer o Caelestia.
- A migração da configuração de quem usa `strip`/`islands` (vira `pill`) e do `barAutoHide`.
- ~~O comportamento da Ilha que expande com o mouse enquanto fundida.~~ (A Ilha saiu.)
- Os testes de unidade da lógica nova e o que a fumaça confere.
