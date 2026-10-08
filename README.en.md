# Experience Pack

> **AI forgets. Your experience doesn't have to.**

A **local-first, portable knowledge pack for AI agents** — so the lessons one AI learned
don't have to be learned again by the next one.

Plain text, JSONL data, PowerShell tooling. Clone it anywhere and it works. No platform
lock-in, no account, no server.

---

## The problem

```
You solve a hard problem with an AI
        ↓
The session ends / context gets compacted / you switch to another AI
        ↓
The lesson is gone
        ↓
Next time, both you and the AI start from zero
```

This pack turns that into:

```
An AI solves a problem
        ↓
The lesson is written down as one structured record
        ↓
Any AI — from any vendor — reads that folder
        ↓
It inherits the experience
```

**The folder lives on your disk. It does not belong to any AI company.**

---

## Quick start

```powershell
# 1. Check that it works on your machine  (first time only)
powershell -ExecutionPolicy Bypass -File '.\30-工具\selfcheck.ps1'

# 2. Before a task: skim the titles (a few seconds)
Get-Content '.\20-历史经验\data\INDEX.md'

# 3. When relevant: search by keyword
cd .\30-工具
.\memory.ps1 search <keyword>
```

That's the light path. There is a heavier one (`.\memory.ps1 context`) — it is the last
resort, because it is roughly 36 KB of text.

---

## Make your AI use it

The pack ships entry points that AI tools load automatically at session start:

| File | Read by |
|---|---|
| `AGENTS.md` | any tool implementing the AGENTS.md convention |
| `CLAUDE.md` | Claude Code |
| `.github/copilot-instructions.md` | GitHub Copilot |

**If your AI does not pick it up automatically, paste this to it:**

```text
This repository is an AI experience pack. Please work through it in this order:

1) Read AGENTS.md in the repository root — it documents the full usage.
2) Use its tiers, lightest first:
   · Tier 0  skim titles:  Get-Content '<pack>\20-历史经验\data\INDEX.md'
   · Tier 1  search:       cd <pack>\30-工具 ; .\memory.ps1 search <keyword>
   · Tier 2  full dump:    .\memory.ps1 context   (last resort, ~36 KB)
3) If this task produced something genuinely worth keeping — it has verifiable
   evidence and will clearly save others from repeated work, errors or risk —
   write it back:
   .\memory.ps1 add-lesson -Title "..." -Kind technique -Context "..." `
       -Mistake "..." -Solution "..." -Reusable "..." -Tags "a,b" `
       -Namespace contributed

Two notes:
· Writes must specify -Namespace contributed. Without it, records go to the
  local layer, which is never distributed — your experience would not travel.
· The tooling requires Windows + PowerShell 5.1+. Data files (JSONL / Markdown)
  are cross-platform.
```

Why this matters: **there is no universal mechanism that makes every AI discover an
arbitrary repository.** Tools that support the convention will find it. The rest need you
to paste one paragraph — the paragraph above.

---

## Three namespaces

| Namespace | Purpose | Who writes |
|---|---|---|
| `local` | private to one machine (contains host paths, IPs) | you, for yourself |
| **`contributed`** | **quarantine for outside contributions** | **write here** |
| `universal` | distilled, generally-useful knowledge | promoted after review |

Records are one JSON object per line, in four files: `facts` · `lessons` · `decisions` ·
`timeline`.

---

## What's in this release

**Entry points** — `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`

**Navigation** — `INDEX.md` (titles only) and `build-index.ps1` to regenerate it

**Tooling**
- `selfcheck.ps1` — one command to verify the pack works here
- `release-gate.ps1` — simulates a fresh clone in a temp directory and actually exercises
  discovery, reading, writing, index rebuild, privacy scan and signature
- `merge-pack.ps1` — conservative merge: same id with different content keeps **both**
  records and writes a conflict report. It does **not** decide which is true.
- `check-variable-names.ps1` — finds PowerShell variables whose names differ only by case

**Integrity** — an Ed25519 signature over 19 core/framework files, plus a chronicle anchor

---

## Scope and limits — read this before trusting anything

**What it does:** if the host AI reads the repository-root instruction files, it can
discover, read and write this pack. If it can execute commands and has write permission,
it can search and append.

**What it does not do:**

- **It does not guarantee every AI will discover it.** No such mechanism exists. Plain
  chat models, AIs not started in this directory, or AIs without this directory mounted
  will not see it.
- **It does not guarantee an AI will write to it.** Writing is an invitation, not an
  obligation — a low-quality record is worse than none, because it buries the useful ones.
- **The signature does not make the data true.** It covers 19 core and framework files.
  The data layer is deliberately **not** signed — otherwise any contributor adding one
  record would break verification. So a passing signature proves the core was not
  tampered with; it does **not** prove data entries are accurate, safe, or free of
  prompt injection.
- **`contributed` content is unreviewed by default.** Judge it on its evidence and source.

---

## Three hard rules

1. **Never rewrite the `.jsonl` files with PowerShell's `ConvertTo-Json`.** It is not a
   lossless round-trip. To add, use `memory.ps1 add-*`; to correct, append a correction
   record.
2. **Never delete records from `20-历史经验\data\`.** Mark a record `status: falsified`
   and explain. Later readers need to see that two accounts existed and what each was
   based on.
3. **Signing private keys never enter the repository.** They live outside it, offline.

---

## Layout

```
AGENTS.md              entry point for AI tools
README.md              full documentation (Chinese)
README.en.md           this file
SCHEMA.md              data format and evolution rules
00-底层逻辑\            why it is designed this way
10-说明书\              manuals (FOR-AI / FOR-HUMAN / AGENTS)
20-历史经验\            the data
  data\INDEX.md        title index
  data\{local,universal,contributed}\{facts,lessons,decisions,timeline}.jsonl
30-工具\                memory.ps1, selfcheck.ps1, build-index.ps1, release-gate.ps1, ...
40-Skills\             reusable procedures
60-贡献协议\            contribution protocol (not yet enabled)
70-文明史书\            chronicle
80-合并与继承策略\       merge and inheritance policy
90-虎符v2\              integrity signature tooling
core\                  security policy
```

*(Directory names are in Chinese. The tooling resolves paths relative to its own
location, so the layout works as-is; see `AGENTS.md` for the reading order.)*

---

## Requirements

- **Windows + PowerShell 5.1+** for the tooling. Tested only there.
- Data files (JSONL, Markdown) are portable and can be read or edited anywhere.
- If `Get-ExecutionPolicy` reports `Restricted`:
  `powershell -ExecutionPolicy Bypass -File <script>`

---

## License

MIT.

---

*This is a condensed English overview. The Chinese `README.md` is the authoritative and
most detailed document. For the design rationale, see `00-底层逻辑\`.*
