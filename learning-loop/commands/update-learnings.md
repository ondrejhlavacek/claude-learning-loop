---
description: Triáž Claude Code session. Bez argumentů analyzuje aktuální konverzaci. S argumenty (transcript_path output_path) běží headless z hooku.
---

Argumenty: `$ARGUMENTS`

## Plugin data directory

Tento plugin ukládá session learnings do `<DATA_DIR>/sessions/`. Cestu zjisti tímto bash snippetem (zkopíruj přesně):

```bash
resolve_data_dir() {
  if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    printf '%s\n' "$CLAUDE_PLUGIN_DATA"
    return 0
  fi
  # Fallback pro interaktivní run: CLAUDE_PLUGIN_DATA Claude Code do Bash toolu
  # hlavní session neinjektuje (k 2.1.x). Najdeme data dir přes find na plugin name.
  # find použito místo shell glob kvůli zsh/bash kompatibilitě (zsh má 1-based arrays).
  local matches
  matches=$(find "$HOME/.claude/plugins/data" -mindepth 1 -maxdepth 1 -type d -name 'learning-loop-*' 2>/dev/null)
  [ -n "$matches" ] || return 1
  if [ "$(printf '%s\n' "$matches" | wc -l | tr -d ' ')" = "1" ]; then
    printf '%s\n' "$matches"
    return 0
  fi
  return 1
}
DATA_DIR=$(resolve_data_dir) || { echo "Cannot locate learning-loop plugin data directory." >&2; exit 1; }
echo "$DATA_DIR"
```

Pokud snippet selže (chybí data adresář, nebo jich existuje víc kandidátů), oznam uživateli chybu a skonči — neuhádni cestu sám.

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

### Tvrdé triggery — zaznamenej insight POUZE pokud platí alespoň jeden

1. **Uživatel opravil Claude kód** (chybné API, špatná syntax, neexistující funkce, špatný import)
2. **Uživatel explicitně odmítl postup** ("ne, takhle ne", "stop", "nedělej X", "vrať to zpátky", "místo toho udělej Y")
3. **> 2 iterace na triviální cíl** (Claude musel třikrát+ opravovat něco, co mělo být na první pokus — překlepy v názvech souborů, špatné cesty, opakované lint chyby)
4. **Uživatel sdělil neznámý fakt o setupu/projektu** ("u nás se používá X", "pozor, Y je v Z", "máme to v repo W") — fakt, který bys neuhádl z kódu
5. **Opakovaný manuální krok** uživatele, který by mohl být automatizovaný (3+× stejná oprava v session)

Bez splnění alespoň jednoho triggeru → **nezařazuj**. Subjektivní pocity ("uživatel asi preferuje X") nestačí.

**Co NE-zařazovat ani když trigger platí:**
- Obecné coding best practices (patří do CLAUDE.md, ne do learnings)
- Jednorázové situace bez budoucí relevance
- Věci už dokumentované v kódu/gitu/CLAUDE.md
- Aktuální task progress
- Banality ("uživatel preferuje čistý kód", "uživatel chce funkční testy")

Když nemáš co zařadit (žádný trigger nevypálil), vytvoř soubor s prázdnou sekcí Entries — falešné entries jsou horší než žádné.

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
tech_stack: [typescript, react, pnpm]   # technologie session — viz pravidla níže
session_summary: 1 věta o tom, čeho se session týkala
status: open
mode: headless | interactive
---

# Session learnings — YYYY-MM-DD HH:MM

## Entries

### 1. Krátký titulek (max 60 znaků)
- **Kategorie:** skill-gap | friction | knowledge | automation
- **Tech:** [python, fastapi] — pokud entry platí jen pro konkrétní stack; vynech pokud univerzální
- **Kontext:** 1-2 věty, co se dělo
- **Insight:** 1-3 věty, co je poznatek (a proč — bez "proč" nelze později posoudit)
- **Akce:** typ + krátká specifikace (např. "CLAUDE.md global: přidat pravidlo X")

### 2. ...
```

### Pravidla pro `tech_stack`

- Session-level `tech_stack` = primární technologie/jazyky/frameworky session, max 4 položky, lowercase kebab-case (`typescript`, `react`, `pnpm`, `terraform`, `python`, `fastapi`, `keboola-cli`, `sql`, `bash`, ...).
- Per-entry `Tech:` = užší stack, pokud entry platí jen pro něj. Pokud platí univerzálně (např. preferuje češtinu, git workflow), pole vynech.
- Bez tech kontextu by konsolidace neuměla rozhodnout, jestli princip "nepoužívej export default" platí globálně nebo jen v React projektu.

Když 0 nálezů, sekce Entries dostane jednu řádku: `_Žádné trvalé insighty v této session._`

## 4. Report

**Headless mód:** žádný report (nikdo to nečte). Stačí zapsat soubor a skončit.

**Interaktivní mód:** vypiš krátce:
- Cesta vytvořeného souboru
- Počet entries (s titulky pokud ≤5; jinak počet po kategoriích)
- Případně 1-2 hraniční nálezy se zeptat zda přidat

Žádné dlouhé summary celé session.
