# Changelog

What changed in Dynamic Planner, newest first. After updating, type `/reload` (or restart the game if a release says so).

Português (Brasil) mais abaixo.

## 0.1.1 (2026-10-26)

### New: Analyzer, a last-pull review for raid leaders
- New **Planner | Analyzer** switch at the top of the window, or type `/dynplan analyzer`.
- After each boss pull (out of combat) the addon saves what the game lets it read: damage taken per player and per boss ability, deaths with their last hits, pull length. Up to 30 pulls are kept.
- Views: **Overview**, **Deaths**, **Damage taken**, **Mechanics** and **Compare** (two pulls side by side).
- **Overview on one screen**: the result, four key numbers and "What to look at first" (click a line to jump there), the pull timeline, then Deaths, Damage taken and Mechanics columns, each with **See all**. Hovering a death highlights it on the timeline.
- **Zoom and pan the pull timeline**: Ctrl+mouse wheel zooms around the cursor, drag or Shift+wheel moves sideways, and **-**, **Fit pull** and **+** sit in its header. The damage lane is taller, and one big spike no longer flattens the rest.
- **Hover card**: one clean card for everything in the Analyzer. A death shows the killing blow, a "Last hits" table with health before each hit, planned cover, raid cooldowns that were active and recent defensives. Your own realm is left off names.
- **Import pull**: paste a pull string made from a combat log to review a pull with full detail. Imported pulls are tagged "from log".
- **Log converter**: `tools/log2pull.py` (or double-click `tools/Import last pull.bat`) turns the last boss pull of your newest combat log into that string and copies it, with no questions. It finds the Logs folder (and the RaiderIO archive) of the usual install folders on C:, D: and E:. See "How to analyze your last pull" in the README.
- Limits: since Midnight, addons cannot read the combat log or live cooldown use. Cooldown use only shows when it appears in the healing meter ("Seen in meter"). Avoidable damage is only flagged for a few abilities so far.
- A raid member shown as a killer is real: some boss abilities turn a player hostile (mind control), and the card says so.
- **Filter**: a Filter button next to Import pull hides player spells, damage taken abilities or players across the Analyzer. The button shows how many are hidden, and Reset clears it. Saved per character.
- **Time marker**: a thin line follows the cursor over the pull timeline with the exact time (m:ss.s) on the axis.
- **Plan vs pull**: hovering a raid cooldown, cast or planned, says how it went against the plan: "2.5 s late", "1.8 s early", "on time" (within 1 s) or "not used". On pulls saved in game the meter has no cast times, so it says "no trace in the meter" instead.
- **Lane focus**: the timeline lane under the cursor stays bright and the others fade back, so Raid CDs cast and Planned raid CDs are easy to tell apart.
- **Player cards in Damage taken**: hovering a player (in the Damage taken view or the Overview column) shows their total and share, top abilities with avoidable ones marked, their death and how they compare with their role's average.

### Header
- **Import note** (from clipboard), **Read from NSRT** and **Send to NSRT** are now icon buttons next to the Note menu. They fade and explain why when NSRT is missing or too old.
- The Note menu keeps Copy raid CDs, Preview note, Share with raid and Clear CDs.
- Dropdown buttons have a real down arrow instead of the letter "v".
- Buttons in a group (for example "By ability" and "By category") no longer touch; groups have more room between them.

### Fixes
- While dragging a cooldown, the yellow line on the preview card now lines up with the yellow line on the timeline (it was about 20 px off).
- Imported pulls on fights with more than one boss could show "Wipe at 0%" when one boss had died first. Paste such pulls again to get the right number.

## 0.1.0 (2026-10-26), first public release

### Matches the web planner
- Spell list grew from 230 to 331 spells, with English and Portuguese tooltips for all 556 entries.
- Personal spells only members plan for themselves are hidden from the raid plan.
- **Saved plans per fight**: keep several named plans for each boss and switch between them.
- **Filters** panel with tabs: Spells, Boss track, Phases.
- **Coverage** bar: shows which boss abilities have a raid cooldown on them.
- **Share with raid** sends the plan to your group.
- **Shortcuts and commands** help sheet (press `?`).
- Alt+click folds and unfolds rows.
- Kick rows with nobody assigned show a "No kicker yet" chip.
- Coiled Altar shows its enrage marker.
- Not included on purpose: the members' "My cooldowns" view and Lorrgs/MRT import (web planner only).

### Faster
- Panning and redrawing use far less memory (panning went from about 6 MB to 0.15 MB per step), so the window should no longer stutter.
- Dragging a cooldown starts as soon as the mouse moves 3 px, with no delay, and follows the cursor on the same frame. A click still just selects.
- `/dynplan perf` turns on a small profiler (off by default).

### New and redesigned
- **Two-row header**: plan and boss on top, view controls below. The header buttons are clickable again (the window's drag strip was catching the clicks).
- **Preview note** (Note menu, or the `N` key): the NSRT note as a readable sheet grouped by phase and time, with a list of anything that cannot be placed, a raw text toggle and Copy.
- **Drag preview card**: the Boss, Player and Allies lanes have a baseline, abilities at the same moment group into a "+N" chip, and the "+-0.0 s" label is fixed.
- **Notes on casts**: a cast with a note gets a gold dot and a small note chip that never covers icons; the full note shows on hover.

### Fixes
- Help sheet labels (such as "Essentials" and "Close") were blank; they show again.
- Sharing waits when the game blocks addon messages during encounters and slows down if it is throttled.
- Keyboard shortcuts never take over the keyboard in combat.
- The addon list now shows a Portuguese title, a category and an icon.
- A texture leak while scrolling the timeline was fixed.
- The release contains no player names or private data; the roster starts empty.

---

# Changelog (Português)

O que mudou no Dynamic Planner, do mais novo para o mais antigo. Depois de atualizar, use `/reload`.

## 0.1.1 (2026-10-26)

### Novo: Analisador, revisão do último pull para líderes de raide
- Nova chave **Planejador | Analisador** no topo da janela, ou `/dynplan analyzer`.
- Depois de cada pull de chefe (fora de combate) o addon salva o que o jogo deixa ler: dano recebido por jogador e por habilidade do chefe, mortes com os últimos golpes, duração do pull. Guarda até 30 pulls.
- Telas: **Resumo**, **Mortes**, **Dano recebido**, **Mecânicas** e **Comparar** (dois pulls lado a lado).
- **Resumo numa tela só**: o resultado, quatro números principais e "o que olhar primeiro" (clique numa linha para ir até ela), a linha do tempo do pull, e colunas de Mortes, Dano recebido e Mecânicas, cada uma com **Ver tudo**. Passar o mouse numa morte destaca ela na linha do tempo.
- **Zoom e arraste na linha do tempo do pull**: Ctrl+roda do mouse dá zoom em volta do cursor, arrastar ou Shift+roda move para os lados, e **-**, **Pull inteiro** e **+** ficam no cabeçalho dela. A faixa de dano ficou mais alta, e um pico grande não achata mais o resto.
- **Card de hover**: um card limpo para tudo no Analisador. Uma morte mostra o golpe final, uma tabela de últimos golpes com a vida antes de cada um, a cobertura planejada, os cooldowns de raide ativos e os defensivos recentes. O seu próprio reino sai dos nomes.
- **Importar pull**: cole um texto de pull gerado a partir de um combat log para ver o pull com todos os detalhes. Pulls importados aparecem como "do log".
- **Conversor de log**: `tools/log2pull.py` (ou dois cliques em `tools/Import last pull.bat`) transforma o último pull de chefe do combat log mais novo nesse texto e copia, sem perguntas. Ele acha a pasta Logs (e o arquivo do RaiderIO) nas pastas de instalação comuns em C:, D: e E:. Veja "Como analisar o seu último pull" no README.
- Limites: desde Midnight, addons não leem o combat log nem o uso de cooldowns ao vivo. O uso de cooldowns só aparece quando vem no medidor de cura ("Seen in meter"). Dano evitável só é marcado em poucas habilidades por enquanto.
- Um membro da raide aparecendo como quem matou é real: algumas habilidades de chefe deixam um jogador hostil (controle mental), e o card avisa.
- **Filtro**: um botão Filtro ao lado de Importar pull oculta magias de jogador, habilidades de dano recebido ou jogadores em todo o Analisador. O botão mostra quantos estão ocultos e Redefinir limpa. Salvo por personagem.
- **Marcador de tempo**: uma linha fina segue o cursor na linha do tempo do pull, com o tempo exato (m:ss.s) no eixo.
- **Plano vs pull**: passar o mouse num cooldown de raide, usado ou planejado, diz como foi em relação ao plano: "2,5 s atrasado", "1,8 s adiantado", "no tempo" (até 1 s) ou "não usado". Em pulls salvos no jogo o medidor não tem horários de uso, então diz "sem rastro no medidor".
- **Foco na faixa**: a faixa da linha do tempo sob o cursor fica acesa e as outras esmaecem, para separar fácil CDs de raide usados e planejados.
- **Card de jogador em Dano recebido**: passar o mouse num jogador (na tela Dano recebido ou na coluna do Resumo) mostra o total e a parte da raide, as principais habilidades com as evitáveis marcadas, a morte e a comparação com a média da sua função.

### Cabeçalho
- **Importar nota** (da área de transferência), **Ler do NSRT** e **Enviar ao NSRT** viraram botões de ícone ao lado do menu Note. Ficam apagados e explicam o motivo quando o NSRT falta ou está desatualizado.
- O menu Note mantém Copiar CDs, Pré-visualizar nota, Compartilhar com a raide e Limpar CDs.
- Botões de lista têm uma seta para baixo de verdade no lugar da letra "v".
- Botões em grupo (por exemplo "Habilidade" e "Categoria") não ficam mais colados; grupos têm mais espaço entre si.

### Correções
- Ao arrastar um cooldown, a linha amarela do card de prévia agora alinha com a linha amarela da linha do tempo (estava uns 20 px fora).
- Pulls importados em lutas com mais de um chefe podiam mostrar "Wipe at 0%" quando um chefe morria antes. Cole esses pulls de novo para ver o número certo.

## 0.1.0 (2026-10-26), primeira versão pública

### Igual ao planejador web
- Lista de feitiços foi de 230 para 331, com tooltips em inglês e português para as 556 entradas.
- Feitiços pessoais que só os membros planejam para si ficam fora do plano da raide.
- **Planos salvos por luta**: vários planos com nome para cada chefe, com troca entre eles.
- Painel de **Filtros** com abas: Feitiços, Trilha do chefe, Fases.
- Barra de **Cobertura**: mostra quais habilidades do chefe têm cooldown de raide.
- **Compartilhar com a raide** envia o plano para o grupo.
- Folha de **Atalhos e comandos** (tecla `?`).
- Alt+clique recolhe e expande linhas.
- Linhas de kick sem ninguém mostram "Sem kicker ainda".
- Coiled Altar mostra o marcador de enrage.
- Fora de propósito: a tela "My cooldowns" dos membros e a importação Lorrgs/MRT (só no planejador web).

### Mais rápido
- Arrastar a vista e redesenhar usam muito menos memória (de uns 6 MB para 0,15 MB por passo), sem engasgos.
- Arrastar um cooldown começa quando o mouse anda 3 px, sem atraso, e acompanha o cursor no mesmo quadro. Um clique só seleciona.
- `/dynplan perf` liga um pequeno medidor de desempenho (desligado por padrão).

### Novo e redesenhado
- **Cabeçalho em duas linhas**: plano e chefe em cima, controles de vista embaixo. Os botões do cabeçalho voltaram a responder ao clique (a faixa de arrastar a janela pegava os cliques).
- **Pré-visualizar nota** (menu Note, ou tecla `N`): a nota do NSRT como folha legível agrupada por fase e tempo, com a lista do que não dá para posicionar, opção de texto bruto e Copiar.
- **Card de prévia ao arrastar**: as faixas do chefe, do jogador e dos aliados têm uma linha de base, habilidades no mesmo momento se agrupam num chip "+N", e o rótulo "+-0.0 s" foi corrigido.
- **Notas nos casts**: um cast com nota ganha um ponto dourado e um chip pequeno que nunca cobre ícones; a nota inteira aparece no hover.

### Correções
- Rótulos da folha de ajuda (como "Essenciais" e "Fechar") estavam em branco; voltaram.
- O compartilhamento espera quando o jogo bloqueia mensagens de addon durante encontros e desacelera se for limitado.
- Atalhos de teclado nunca tomam o teclado em combate.
- A lista de addons mostra título em português, categoria e ícone.
- Corrigido um vazamento de texturas ao rolar a linha do tempo.
- A versão não traz nomes de jogadores nem dados privados; o roster começa vazio.
