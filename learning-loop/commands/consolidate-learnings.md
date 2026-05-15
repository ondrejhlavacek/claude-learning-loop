---
description: Konsoliduje session soubory v plugin data adresáři → updatuje PRINCIPLES.md a archivuje. Žádné edity mimo data adresář, jen flaguje návrhy.
---

## Plugin data directory

Tento plugin pracuje s plugin data adresářem. Na začátku zjisti cestu tímto bash snippetem (zkopíruj přesně):

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

Dál v textu používám `$DATA_DIR` jako tento root path. Struktura:

```
$DATA_DIR/
├── sessions/       # per-session learnings (vstup konsolidace)
├── archive/        # zpracované session soubory
└── PRINCIPLES.md   # konsolidované principy
```

**Nic mimo `$DATA_DIR` automaticky neměň** (žádné edity CLAUDE.md, skillů, hooků). Akce na úpravu jiných souborů jen flaguj jako návrhy.

## 1. Načti vstup

```bash
ls "$DATA_DIR/sessions/"*.md 2>/dev/null
```

Pokud je seznam prázdný, oznam "není co konsolidovat" a skonči.

Přečti všechny session soubory + aktuální `$DATA_DIR/PRINCIPLES.md` (pokud existuje).

## 2. Analýza napříč entries

Sesbírej všechny `### N. ...` entries ze všech session souborů. Pak:

- **Identifikuj duplicity** — entries říkající totéž jinými slovy napříč session
- **Identifikuj příbuzné** — 2-3 entries pokrývající stejnou doménu
- **Identifikuj vzorce** — 3+ entries v různých session ukazujících stejný princip → kandidát na principle
- **Identifikuj zastaralé** — entries superseded novějšími nebo už nerelevantní

## 3. Update PRINCIPLES.md

**Seskup nejdřív podle `origin_cwd` a `tech_stack`** ze frontmatteru jednotlivých session souborů. Některé principy jsou **globální** (platí napříč všemi repos), jiné **repo-specific** (např. konvence v `~/Coding/oncall/`), další **tech-specific** (jen pro React, jen pro Python, ...).

Heuristika:
- Pokud 3+ entries ze 2+ různých `origin_cwd` **a** se stejným/překrývajícím `tech_stack` říkají totéž → **globální princip pro daný stack**
- Pokud 3+ entries ze 2+ různých `origin_cwd` napříč různými stacks → **opravdu globální princip** (neváže se na technologii)
- Pokud 3+ entries z jediného `origin_cwd` → **repo-specific princip**

V `PRINCIPLES.md` udržuj sekce:

```
## Principles — global

- **Krátké pravidlo.** Proč: ... | Zdroj: N entries (YYYY-MM-DD až YYYY-MM-DD)

## Principles — tech: typescript+react

- **Krátké pravidlo platné jen pro tento stack.** Proč: ... | Zdroj: ...

## Principles — repo: /Users/ondra/Coding/oncall

- **Krátké pravidlo specifické pro tento repo.** Proč: ... | Zdroj: ...

## Principles — repo: /Users/ondra/Coding/keboola-foo

...
```

Před přidáním zkontroluj, že stejný/podobný princip tam ještě není (pokud ano, jen update Zdroj/datum).

Pokud principle už není relevantní (superseded jiným, vyřešeno v CLAUDE.md), smaž ho.

PRINCIPLES.md má zůstat **krátký a stabilní** — ideálně do ~30 odrážek. Pokud roste přes to, slučuj agresivněji.

### Pravidla pro formulaci principu

- **Zachovej konkrétní jména** tříd, flagů, API, příkazů a souborů zmíněných v původních entries. Neredukuj na vágní fráze.
  - Špatně: "Při použití test frameworku používej správné flagy."
  - Dobře: "Při `pnpm test` použij `-- <soubor>`, ne workspace-wide testy — workspace timeoutuje subagenta po 2 minutách."
- **Vždy uveď proč** ("Proč: ...") — bez důvodu nelze v budoucnu posoudit, jestli princip stále platí, nebo zda jen reflektoval konkrétní past, kterou už CLAUDE.md řeší.
- **Bez technologického kontextu princip nemá smysl** pokud je tech-specific — buď ho zařaď do `Principles — tech:`, nebo do textu pravidla výslovně uveď stack ("V React projektech: ...").
- Vyhni se obecným banalitám typu "piš čistý kód", "testuj svůj kód" — to už je v CLAUDE.md nebo by mělo být.

## 4. Archivace session souborů

Všechny session soubory, které jsi zpracoval, přesuň do `$DATA_DIR/archive/`:

```bash
mkdir -p "$DATA_DIR/archive"
mv "$DATA_DIR/sessions/<file>.md" "$DATA_DIR/archive/"
```

**Výjimka:** session soubor s `status: open` v frontmatteru, kde žádný entry nebyl použit pro principle ani sloučen — ponech v `sessions/` (může se stát relevantním později spolu s budoucími entries). Označuj střídmě, default je archivovat.

## 5. Report a flagging

Vypiš:

**Konsolidace:**
- Zpracováno session souborů: N (archivováno: M, ponecháno: K)
- Nové principy: N (vypiš titulky)
- Updated principy: N
- Smazané principy (superseded): N

**Návrhy k uživatelovu schválení (NIC neaplikováno):**

Pro každý principle nebo high-impact entry navrhni cílový soubor:

```
1. [PRINCIPLE→CLAUDE.md] "..." → přidat do ~/.claude/CLAUDE.md sekce X
2. [PATTERN→SKILL] entries Y, Z naznačují potřebu skillu pro doménu D
3. [FRICTION→HOOK] friction Q se opakuje → PostToolUse hook s X
```

Na konci se zeptej: "Chceš některý návrh aplikovat?" — čekej na odpověď, neaplikuj nic bez explicitního OK.
