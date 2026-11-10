# lucerna-icons — design

Data: 2026-11-09. Fila: depois das cores/barras (`feat/cores-barras`), antes dos testes ponta a ponta.

## Por quê

Os ícones do Material Symbols funcionam bem no shell, mas o Lucide combina melhor com os apps. No Lucerna Files, por exemplo, os ícones de música, imagem e vídeo ficam melhores no Lucide. Para shell e apps terem o mesmo visual, o Lucerna ganha um pacote de ícones próprio, baseado no Lucide, e o shell troca o Material por ele.

## Objetivos

1. Um repositório próprio, **`lucerna-desktop/lucerna-icons`**, com **licença MIT**, usado pelo shell e pelas GUIs Qt dos apps.
2. **Só os ícones usados**: os do shell hoje (131 nomes em `core/widgets/Icons.qml`, alguns em listas de estados, uns ~205 glifos ao todo). O pacote cresce sob demanda, quando um ícone novo for preciso.
3. Cada ícone **com área para preencher** (bateria, sino, pasta, coração…) tem **contorno e preenchido**; o Lucide só tem contorno, então o preenchido é desenhado por nós. Os **sem área** (fechar, check, setas, chevrons, atualizar) usam o **próprio contorno** como preenchido, como o Material (decisão do usuário, 2026-11-09): no manifesto `"filled": "outline"`, sem `svg/filled/<nome>.svg`, e o build aponta a ligadura `<nome>-fill` para o glifo do contorno.
4. **Variações iguais às do Material**: onde o Material tem mais estados, desenhamos os que faltam. Exemplos: 8 níveis de bateria contra os 5 do Lucide, os níveis do Wi-Fi, o volume.
5. Os ícones que o Lucide não tem são desenhados por nós, na mesma linguagem do Lucide (grade de 24, traço 2, pontas e junções redondas).
6. A **animação do preenchimento** continua: o ícone "enche" quando algo fica ativo, como hoje com o eixo FILL (`core/widgets/Icon.qml`).

## Fora do escopo

- A TUI do explorador, que continua com a Nerd Font, o padrão do terminal.
- Ícones de aplicativos e de tipos de arquivo do tema do sistema (os que vêm do `.desktop`). Este pacote é só de ícones de interface.
- O conjunto inteiro do Lucide.

## Anti-objetivos

- Aprovar um ícone sem o usuário ver. **Nenhum ícone entra no pacote sem ser aprovado**, em lotes (ver "Revisão").
- Perder legibilidade nos tamanhos do shell (16–28 px), sobretudo nos preenchidos com detalhe interno.
- Um pacote pesado: nada de incluir o Lucide inteiro "por via das dúvidas".

## Licença e créditos

O Lucide usa a licença ISC. Os ícones que vieram do Feather (lista no LICENSE do Lucide) usam MIT, de Cole Bemis. A exigência é manter o aviso de copyright e o texto da licença em todas as cópias, inclusive nas editadas. Não é preciso crédito visível. No repositório:

- `LICENSE`: MIT, "Copyright (c) 2026 Lucerna".
- `LICENSE-LUCIDE`: o texto integral do LICENSE do Lucide (ISC + MIT do Feather), copiado sem alterações.
- README: "Baseado no [Lucide](https://lucide.dev)", e quais ícones são derivados e quais são originais. O manifesto registra isso.
- Shell: a página de créditos (ver `tests/credits.test.js`) troca o Material Symbols pelo lucerna-icons e pelo Lucide.

## Como é feito (decisões)

- **O SVG é a fonte da verdade.** Cada ícone tem `svg/outline/<nome>.svg` e `svg/filled/<nome>.svg`, na grade de 24.
- **`manifest.json`** guarda uma entrada por ícone com:
  - `name`: nome do Lucerna, em kebab-case, igual ao do Lucide quando derivado;
  - `origin`: `"lucide:<nome>"` ou `"lucerna"`;
  - `material`: a ligadura do Material que ele substitui;
  - `status`: `"pendente"` ou `"aprovado"`;
  - as variações, quando existem.
- **Fonte gerada** pelo build, a partir dos SVGs aprovados:
  - família **"Lucerna Icons"**;
  - por ligadura, como o Material: `<nome>` dá o contorno e `<nome>-fill` dá o preenchido. Assim o `Text` do `Icon.qml` continua funcionando;
  - os traços viram contornos no build.
  O repositório também instala os SVGs, para os apps Qt usarem com `QIcon`, se preferirem.
- **A animação do preenchimento fica no QML.** Uma fonte variável com eixo FILL, montada a partir de ícones de traço, exige contornos compatíveis entre os dois estados e seria difícil de manter. No `Icon.qml`, o contorno e o preenchido ficam sobrepostos, com transição de opacidade e escala (`fill` de 0 a 1). A API do `Icon` não muda (`icon`, `size`, `filled`, `fill`).
- **Pesos pelo tamanho (tamanho óptico).** O traço 2 do Lucide na grade de 24 fica fino nos ícones pequenos (1,1 px em 13 px) e grosso nos grandes (6 px em 76 px). A fonte tem **4 pesos**, gerados dos mesmos SVGs (contorno e preenchido): traço **2,5 / 2 / 1,5 / 1**. O `Icon.qml` escolhe sozinho pelo tamanho: **até 16 px → 2,5; 17–24 → 2; 25–40 → 1,5; acima de 40 → 1**. O `weight: 600` (ênfase; hoje `Switch.qml` e `AppearancePage.qml`) sobe um degrau a partir do automático. Decisão do usuário, 2026-11-09. A galeria mostra os 4 pesos de cada ícone.
- **Tamanhos padronizados.** O shell usa uns 15 tamanhos de ícone para poucas funções. Viram tokens do tema (`ThemeManager.icon.*`, escalados pelo `px()`), usados também pelos apps:

  | Token | px | Uso | Traço |
  |---|---|---|---|
  | `xs` | 14 | selos, indicadores (hoje 13/14/16) | 2,5 |
  | `sm` | 16 | controles pequenos (interruptor, segmentos) | 2,5 |
  | `md` | 20 | central, listas, OSD, bloqueio (hoje 18/20) | 2 |
  | `lg` | 24 | cabeçalhos, busca, notificações (hoje 22/24) | 2 |
  | `xl` | 32 | destaque em cartões, mídia, menu de energia (hoje 26–32) | 1,5 |
  | `empty` | 40 | estados vazios (hoje 36/40) | 1,5 |
  | `display` | 64 | grade do lançador, mídia, clima (hoje 52–76) | 1 |

  **Em aberto, decidir vendo:** a barra (hoje 18, barra de 44 px) ganha token próprio `bar: 18` ou passa a `md: 20`; e se clima/mídia ficam em 72 em vez de `display`. A migração do shell traz capturas das duas opções da barra para o usuário escolher. Decisão do usuário (2026-11-09): padronizar; esses dois pontos, na prática.
- **Instalação:** segue o padrão dos outros repositórios da org (o lucernad), com um alvo de instalação para `/usr/share/fonts` e `/usr/share/lucerna-icons/svg`. O container de teste (`dev/test.sh`) e o CI do shell instalam o pacote no lugar do Material Symbols.

## Revisão (o processo com o usuário)

Esse é o centro do trabalho e acontece em conversa, **em lotes de 10–15 ícones** (decisão do usuário, 2026-11-09), cada um com a família inteira:

1. Escolho o próximo lote da lista do `manifest.json`.
2. Para cada ícone do lote, monto todas as variações: contorno, preenchido e os estados (os 8 da bateria, por exemplo). Quando o ícone vem do Lucide, mostro o original ao lado.
3. Apresento numa **página de galeria local** gerada pelo repositório (`tools/gallery`, HTML estático). A página mostra:
   - o ícone em 16, 20, 24 e 28 px;
   - o tema escuro e o claro;
   - o ícone dentro de um bloco ativo, com o tom de contêiner da `feat/cores-barras`;
   - a animação do preenchimento;
   - o Material atual ao lado, para comparar.
4. O usuário aprova o lote ou separa os que quer ajustar; os ajustados voltam no lote seguinte. Só um ícone aprovado vira `"aprovado"`.

A ordem sugerida começa pelos mais visíveis e pelos que exigem mais desenho: a bateria, o Wi-Fi, o volume, o Bluetooth, os blocos da central, a barra e depois o resto. O usuário pode mudar a ordem.

## Migração do shell

Feita depois de **todos** os ícones usados estarem aprovados, numa branch do shell:
- todo `Icon`/`IconButton` passa a usar um token de tamanho (sem `px(N)` solto);
- `Icons.qml` passa a apontar para os nomes do lucerna-icons;
- `Icon.qml` passa às duas camadas;
- `font.icon` dos 12 temas vira "Lucerna Icons";
- os créditos, o README e as dependências do container e do CI são atualizados;
- o Material Symbols sai.

Capturas de antes e depois nas telas principais.

## Testes

- No repositório lucerna-icons:
  - um check de CI que valida o manifesto: todo ícone tem o SVG do contorno e, salvo `"filled": "outline"`, o do preenchido, nomes únicos e `origin` válido;
  - o build da fonte gera uma ligadura por SVG aprovado;
  - os SVGs estão na grade de 24 e não têm `fill`/`stroke` fixos de cor.
- No shell:
  - um teste unitário confere que todo nome em `Icons.qml` existe no manifesto aprovado;
  - lint, unitários e fumaça passando;
  - capturas.

## Decisões de quem escreveu (conferir)

- **Inventário inicial = só o shell.** Os ícones do Lucerna Files entram quando o app for construído (pacote cresce sob demanda).
- **Cada estado é um glifo com nome e ligadura próprios** (`battery-3`, `wifi-2`), como no Material. No manifesto, a entrada de uma família tem `variants` com os nomes dos estados, e a família é aprovada junto.
- **A galeria é independente do shell:** copia um retrato das cores de um tema escuro (catppuccin-mocha) e de um claro (catppuccin-latte), com o tom de contêiner já calculado, e usa o Material Symbols instalado no sistema só para comparar. Sem dependência entre os repositórios.

## Fica com quem implementa

- A ferramenta de build da fonte (fontforge, fantasticon, picosvg etc.) e de conversão de traço em contorno.
- A forma da página de galeria.
- A curva da transição contorno → preenchido, desde que pareça "encher" e não piscar.
