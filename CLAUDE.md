# CLAUDE.md — repository root

This repository holds **two independent projects**. Identify which one the user means before doing anything.

| Folder | Project | Stack | Status |
|---|---|---|---|
| `1Thing/` | "1 Thing" daily-focus app | Kotlin · Compose · Room | Feature-complete, build-verified |
| `NURIVA/` | NURIVA medication management | Flutter · Dart · Firebase | Module 01 complete (v0.1.0) |

## Session start protocol

1. Work out which project the request concerns. If ambiguous, ask — do not guess.
2. **Read that project's state document before anything else:**
   - `1Thing/PROJECT_STATE.md`
   - `NURIVA/docs/NURIVA_MODULE_STATUS.md` ← canonical for NURIVA
3. Resume from the "CURRENT STATE" block at the top of that file.

## NURIVA — module protocol

NURIVA is built **strictly module by module**. The lifecycle for each is:

```
PLAN → DESIGN → IMPLEMENT → BUILD → FUNCTIONAL TEST → FIX → VERIFY
     → TEST BUILD → DOCUMENT → HANDOFF → STOP
```

**After finishing a module, STOP.** Do not begin the next one. The user starts it explicitly with `START MODULE X`.

Hard rules:
- **No advanced testing** (mutation, fuzz, chaos, penetration, load, stress) unless explicitly asked. Basic functional testing only.
- **Premium production UI.** Every screen uses the design system in `NURIVA/app/lib/core/design/`. No screen defines its own colours, radii or spacing.
- **Never commit secrets or binaries.** APKs go to `NURIVA/builds/`, which is gitignored.
- **Healthcare safety:** NURIVA never diagnoses, prescribes, or changes a dosage. AI extracts; a human verifies; a guardian approves. AI must never activate a medication schedule.

## Token discipline

- State documents are small and always worth reading in full.
- `NURIVA/docs/ARCHITECTURE.md` is ~900 lines. Read **only the sections relevant to the current module** — its section index is in `NURIVA_MODULE_STATUS.md`.
- Do not re-read files already summarized in the state document.

## Windows environment gotchas (cost real time before — do not rediscover)

1. **PowerShell 5.1 `Set-Content -Encoding utf8` writes a BOM.** A BOM breaks the Kotlin script compiler (`build.gradle.kts`) and Gradle property files. Use the Write/Edit tools, or `[System.IO.File]::WriteAllText` with `UTF8Encoding($false)`.
2. **.NET APIs ignore PowerShell's `Set-Location`** — they use the process working directory. Always pass absolute paths to `[System.IO.File]`.
3. **Do not pipe long-running commands through `Select-Object`** — it buffers the whole stream, so a working build looks like a hang and errors get truncated. Redirect to a log file.
4. **`cmdline-tools\latest` must remain the CLASSIC rev 19.0.** Gradle shells out to `sdkmanager`; the newer Android CLI crashes on exit (`0xC0000409`) and fails builds.
