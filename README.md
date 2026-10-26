# Dynamic Planner

A World of Warcraft addon: a raid cooldown planner with a timeline editor. Plan boss abilities, assign raid cooldowns, read and send NSRT (Northern Sky Raid Tools) notes, and share the plan with your raid. Open it in game with `/dynplan`.

Interface 12.1.5 (Midnight). English and Portuguese (Brazil).

## Install

1. Open the [latest release](../../releases/latest) and download `DynamicPlanner-x.y.z.zip`.
   Do not use GitHub's green "Code > Download ZIP": it unpacks into a wrongly named folder and WoW will not load it.
2. Unzip it into `World of Warcraft/_retail_/Interface/AddOns`, so you end up with `AddOns/DynamicPlanner/DynamicPlanner.toc`.
3. Restart the game, or type `/reload` if you only updated.

## Update

Download the newest release zip and unzip it over the old folder, then `/reload`. Your saved plans stay.

## How to analyze your last pull

The Analyzer (`/dynplan analyzer`, or the Analyzer switch at the top) saves every boss pull on its own. For full detail (cooldown casts, hit times, deaths with every last hit) you can import a pull from your combat log:

1. In game, turn on Advanced Combat Logging (Options, Network) and type `/combatlog` before the pull.
2. After the pull, double-click `tools/Import last pull.bat` from this repo, or run `py tools\log2pull.py`. It needs [Python 3](https://www.python.org/downloads/). It finds your newest log, converts the last boss pull and copies it to the clipboard. If your game is somewhere unusual, add the folder in quotes: `py tools\log2pull.py --wow "D:\Games\World of Warcraft"`.
3. In game: `/dynplan analyzer`, click **Import pull**, press Ctrl+V and click **Import**.

Other options: `--pick` to choose pulls from a list, `--list`, `--pull N`. Run `py tools\log2pull.py --help` for all of them. The tool only reads the log; it never changes it.

## What's new

See [CHANGELOG.md](CHANGELOG.md) for what changed in each release.

## Report a problem

Open an issue on this repo's Issues tab. Say what you clicked, what you expected, and paste any Lua error text.

## Licenses

The bundled fonts are under the SIL Open Font License; the license files are in `DynamicPlanner/Media/Fonts`.

## Português (Brasil)

Planejador de cooldowns de raide para o WoW, com linha do tempo e troca de notas do NSRT. Abra com `/dynplan`.

Instalação: baixe o zip da [última release](../../releases/latest) (não use "Code > Download ZIP"), extraia em `World of Warcraft/_retail_/Interface/AddOns` para ficar `AddOns/DynamicPlanner/DynamicPlanner.toc`, e reinicie o jogo. Para atualizar, extraia o novo zip por cima e use `/reload`. O que mudou em cada versão está no [CHANGELOG.md](CHANGELOG.md).

Como analisar o seu último pull: o Analisador (`/dynplan analyzer`, ou o botão Analisador no topo) salva cada pull de chefe sozinho. Para ver tudo (casts de cooldowns, horário dos golpes, mortes com todos os últimos golpes), importe o pull do combat log:

1. No jogo, ligue o Advanced Combat Logging (Opções, Rede) e use `/combatlog` antes do pull.
2. Depois do pull, dê dois cliques em `tools/Import last pull.bat` deste repositório, ou rode `py tools\log2pull.py`. Precisa do [Python 3](https://www.python.org/downloads/). Ele acha o log mais novo, converte o último pull de chefe e copia para a área de transferência. Se o jogo estiver numa pasta diferente, passe a pasta entre aspas: `py tools\log2pull.py --wow "D:\Games\World of Warcraft"`.
3. No jogo: `/dynplan analyzer`, clique em **Importar pull**, aperte Ctrl+V e clique em **Importar**.
