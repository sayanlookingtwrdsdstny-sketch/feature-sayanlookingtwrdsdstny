# NURIVA — Original brief (binding constraints)

> The user's master prompt, reduced to its **binding** requirements. Structural detail it specified
> (folder layout, module internals, entity fields, phase list) is expanded in `ARCHITECTURE.md` and
> is not duplicated here. Read this when a **scope** question arises, not for implementation detail.

## Role

Lead Software Architect and Senior Full-Stack Mobile Engineer.

## Product vision

A healthcare-**support** application helping patients and guardians manage prescribed medications safely.

Target users: elderly patients; patients needing family assistance; parents managing children's medication; patients recovering after hospitalization; family members monitoring adherence remotely.

## The core workflow (the product's spine)

1. Guardian/patient creates a patient profile
2. Guardian uploads a prescription
3. OCR/AI extracts medication information
4. AI converts it into structured medication data
5. Extracted information is shown to the guardian for verification
6. Guardian compares extraction against the original prescription
7. **Guardian explicitly approves the medication plan**
8. **ONLY after approval do reminders become active**
9. Patient receives reminders
10. Patient selects TAKEN / SNOOZE / SKIPPED / MISSED
11. Unconfirmed dose past a configurable period → notify guardian
12. Guardian monitors adherence
13. System maintains medication history
14. Guardian adds appointment/follow-up reminders
15. Guardian tracks prescription history and medication changes

**The differentiating feature is the Guardian-Approved Medication Plan.**
AI may extract. AI must **never** independently activate a medication schedule.

## Hard safety rules — NURIVA is not a doctor

Never implement features that: diagnose a disease; recommend prescription medicines; change a prescribed dosage; automatically substitute medicines; decide whether a patient should take a medicine; tell users to stop medication; or provide emergency medical diagnosis.

NURIVA only **organizes and reminds** about information provided by authorized users and prescriptions.

### AI-specific prohibitions

The AI must not diagnose, recommend medicine, change dosage, infer missing prescription information as fact, invent a medication, or activate reminders automatically. If information is unclear → `status = NEEDS_REVIEW`. The UI must clearly tell the guardian to verify extracted information against the original prescription.

Never trust raw AI output. Validation order: JSON validation → schema validation → business validation → confidence checking → human verification → guardian approval. Reject malformed or suspicious responses. Display extraction confidence appropriately.

## Technology constraints

- Must be designed to eventually support **Android, iOS and Web**
- Frontend: **Flutter / Dart**. Backend: **Firebase** (Auth, Firestore, Storage, FCM, Functions)
- AI/OCR behind a **replaceable abstraction layer** (`PrescriptionAIService`); not tightly coupled to one provider
- **NEVER expose an AI API key inside the mobile application**

## Architecture principles

Use: Clean Architecture, feature-first modular structure, repository pattern, dependency injection, service abstraction, strong typing, testable components, secure data access, minimal coupling.

Avoid: massive files, god classes, business logic inside UI widgets, hardcoded API keys, hardcoded Firebase paths throughout the app, direct database calls from UI, provider-specific AI logic inside screens.

## Out of scope / explicitly forbidden

Diagnosis, prescribing, modifying prescriptions, autonomous clinical decisions.

## Development rules (process — these govern how sessions run)

1. **Do NOT build the entire application in one response.** Work module-by-module.
2. Before implementing each module: explain the purpose → show architecture → show files to create/change → explain dependencies → implement → write tests → run/analyze tests → fix errors → verify compilation → short completion report → **wait for approval before the next major module**.
3. Never silently modify unrelated modules.
4. Do not rewrite working code unnecessarily.
5. When changing an existing module, explain exactly what changed.

## Definition of done (per module)

Code compiles · architecture is clean · error handling exists · tests exist · security considerations addressed · no hardcoded secrets · existing functionality still works · documentation updated.

## First task (completed 2026-09-14)

Produce 17 architecture deliverables, then **STOP** and wait for the instruction `START MODULE 1`.

Delivered in `ARCHITECTURE.md`: system architecture · architecture diagram · module dependency diagram · Flutter project structure · Firestore data model · authentication architecture · guardian/patient relationship model · prescription→AI→verification→approval workflow · medication scheduling architecture · notification architecture · security architecture · testing architecture · 20-phase roadmap · MVP vs post-MVP classification · recommended packages (each justified) · environment/configuration strategy · CI/CD architecture.

Every recommended technology/package must explain **why** it is needed. No unnecessary dependencies.

## Standing requirement

The project must remain **modular, scalable, secure and maintainable** throughout development.
