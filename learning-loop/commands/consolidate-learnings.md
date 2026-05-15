---
description: Konsoliduje session soubory v plugin data adresáři → updatuje PRINCIPLES.md a archivuje. Žádné edity mimo data adresář, jen flaguje návrhy.
---

## Plugin data directory

Tento plugin pracuje s adresářem `${CLAUDE_PLUGIN_DATA}`. Na začátku zjisti cestu přes Bash a ulož si do `DATA_DIR`:

```bash
DATA_DIR="${CLAUDE_PLUGIN_DATA:?CLAUDE_PLUGIN_DATA is not set — is this running inside Claude Code as a plugin?}"
echo "$DATA_DIR"
```

Pokud env var prázdná, oznam uživateli chybu prostředí a skonči — žádný fallback, žádné hádání cesty.

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

**Seskup nejdřív podle `origin_cwd`** ze frontmatteru jednotlivých session souborů. Některé principy jsou **globální** (platí napříč všemi repos), jiné **repo-specific** (např. konvence v `~/Coding/oncall/`).

Heuristika:
- Pokud 3+ entries ze 2+ různých `origin_cwd` říkají totéž → **globální princip**
- Pokud 3+ entries z jediného `origin_cwd` říkají totéž → **repo-specific princip**

V `PRINCIPLES.md` udržuj sekce:

```
## Principles — global

- **Krátké pravidlo.** Proč: ... | Zdroj: N entries (YYYY-MM-DD až YYYY-MM-DD)

## Principles — repo: /Users/ondra/Coding/oncall

- **Krátké pravidlo specifické pro tento repo.** Proč: ... | Zdroj: ...

## Principles — repo: /Users/ondra/Coding/keboola-foo

...
```

Před přidáním zkontroluj, že stejný/podobný princip tam ještě není (pokud ano, jen update Zdroj/datum).

Pokud principle už není relevantní (superseded jiným, vyřešeno v CLAUDE.md), smaž ho.

PRINCIPLES.md má zůstat **krátký a stabilní** — ideálně do ~30 odrážek. Pokud roste přes to, slučuj agresivněji.

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
