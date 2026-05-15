---
description: Konsoliduje session soubory v ~/Coding/claude-learnings/sessions/ → updatuje PRINCIPLES.md a archivuje. Žádné edity mimo learnings/ adresář, jen flaguje návrhy.
---

Projdi všechny session soubory v `~/Coding/claude-learnings/sessions/` a proveď konsolidaci. **Nic mimo `~/Coding/claude-learnings/` automaticky neměň** (žádné edity CLAUDE.md, skillů, hooků). Akce na úpravu jiných souborů jen flaguj jako návrhy.

## 1. Načti vstup

```bash
ls ~/Coding/claude-learnings/sessions/*.md 2>/dev/null
```

Pokud je seznam prázdný, oznam "není co konsolidovat" a skonči.

Přečti všechny session soubory + aktuální `~/Coding/claude-learnings/PRINCIPLES.md`.

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

Všechny session soubory, které jsi zpracoval, přesuň do `~/Coding/claude-learnings/archive/`:

```bash
mv ~/Coding/claude-learnings/sessions/<file>.md ~/Coding/claude-learnings/archive/
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
