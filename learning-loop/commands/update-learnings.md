---
description: Triáž Claude Code session. Bez argumentů analyzuje aktuální konverzaci. S argumenty (transcript_path output_path) běží headless z hooku.
---

Argumenty: `$ARGUMENTS`

## Plugin data directory

Tento plugin ukládá session learnings do `${CLAUDE_PLUGIN_DATA}/sessions/`. Na začátku zjisti cestu přes Bash:

```bash
echo "${CLAUDE_PLUGIN_DATA:?CLAUDE_PLUGIN_DATA is not set — is this running inside Claude Code as a plugin?}"
```

Pokud env var prázdná, oznam uživateli chybu prostředí a skonči — žádné hádání cesty. Žádný fallback by skrytě fragmentoval data, kdyby Claude Code někdy změnil formát plugin-data ID.

## Mód detekce

Pokud `$ARGUMENTS` obsahuje **2-5 položek oddělených mezerou** (`<transcript.jsonl> <output.md> [cwd] [git_branch] [session_id]`):
- **Headless mód** (volá tě hook): přečti transcript, výstup zapiš do output.md
- Nečti aktuální konverzaci — pracuj jen s daty z transkriptu
- 3. arg = absolutní cesta k repu/cwd kde session běžela (zapiš jako `origin_cwd`)
- 4. arg = git branch (zapiš jako `origin_branch`, vynech řádku pokud prázdné/HEAD)
- 5. arg = full session_id (UUID, zapiš jako `session_id` — slouží k dedup při /resume)

Pokud `$ARGUMENTS` je **prázdné**:
- **Interaktivní mód**: analyzuj aktuální konverzaci
- Výstupní cesta = `<DATA_DIR>/sessions/YYYY-MM-DD-HHMM.md`, kde `<DATA_DIR>` je výsledek bash příkazu výše
- `origin_cwd` = aktuální pracovní adresář (zjisti `pwd`)
- `origin_branch` = aktuální git branch pokud je v gitu (zjisti `git branch --show-current`), jinak vynech
- `session_id` vynech (interaktivní run nemá deterministicky známé session_id)

## 1. Sběr nálezů

Hledej nálezy ve čtyřech kategoriích:

- **skill-gap** — věci, které Claude nezvládl, dělal opakovaně špatně, vyžadovaly víc pokusů
- **friction** — opakované manuální kroky, věci které musel uživatel explicitně říct, ale měly být defaultní
- **knowledge** — fakta o projektu/preferencích/setupu, která Claude neznal a měl by je znát
- **automation** — opakující se vzorce → kandidáti na skill, hook nebo script

**Co NE-zařazovat:**
- Obecné coding best practices (patří do CLAUDE.md, ne do learnings)
- Jednorázové situace
- Věci už dokumentované v kódu/gitu/CLAUDE.md
- Aktuální task progress

Filtr: zařaď jen nálezy s **70%+ šancí** být relevantní v jiné session. Když nemáš co zařadit, vytvoř soubor s prázdnou sekcí Entries — neumělé entries jsou horší než žádné.

V headless módu buď zvlášť opatrný — bez interaktivního kontextu hrozí false positives. Když si nejsi jistý, raději vynech.

## 2. Triáž akce

Pro každý nález urči navrhovanou akci (jen návrh, **nic neaplikuj**):
- **CLAUDE.md (global / project)** — pravidlo aplikovatelné vždy
- **Nový skill** — situational workflow, načítaný on-demand
- **Hook** — event-driven automatizace
- **Auto-memory** — konkrétní fakt (typ user/feedback/project/reference)
- **Nic** — jen zaznamenat

## 3. Zápis

Vytvoř výstupní soubor (cesta dle módu výše) tímto formátem:

```markdown
---
date: YYYY-MM-DD
session_id: 779a15ef-dea0-4814-b682-34ea1b5d2f4b   # vynech v interaktivním módu
origin_cwd: /Users/ondra/Coding/<repo>
origin_branch: main             # vynech pokud nejde o git repo nebo "HEAD"
session_summary: 1 věta o tom, čeho se session týkala
status: open
mode: headless | interactive
---

# Session learnings — YYYY-MM-DD HH:MM

## Entries

### 1. Krátký titulek (max 60 znaků)
- **Kategorie:** skill-gap | friction | knowledge | automation
- **Kontext:** 1-2 věty, co se dělo
- **Insight:** 1-3 věty, co je poznatek (a proč — bez "proč" nelze později posoudit)
- **Akce:** typ + krátká specifikace (např. "CLAUDE.md global: přidat pravidlo X")

### 2. ...
```

Když 0 nálezů, sekce Entries dostane jednu řádku: `_Žádné trvalé insighty v této session._`

## 4. Report

**Headless mód:** žádný report (nikdo to nečte). Stačí zapsat soubor a skončit.

**Interaktivní mód:** vypiš krátce:
- Cesta vytvořeného souboru
- Počet entries (s titulky pokud ≤5; jinak počet po kategoriích)
- Případně 1-2 hraniční nálezy se zeptat zda přidat

Žádné dlouhé summary celé session.
