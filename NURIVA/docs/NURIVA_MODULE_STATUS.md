# NURIVA — Module Status & Session Handoff

> **New session? Read this file first, then `docs/ARCHITECTURE.md`.**
> Do not start development automatically. Wait for an explicit `START MODULE X`.
> Last updated: 2026-09-23

---

## ▶ CURRENT STATE

| | |
|---|---|
| **Current Module** | 05 — Prescription Reading (on-device OCR) |
| **Module Status** | ✅ Complete — build succeeded, live-device test passed against a real prescription |
| **Current Version** | `0.5.0` (`version: 0.5.0+5`) |
| **Next Module** | 06 — Prescription Verification |
| **Next Module Status** | ⬜ Not started — waiting for explicit `START MODULE 06`. **Read Module 05's "Known issues" #1 before planning it**: on a tabular prescription the raw recognized text, not the candidate cards, is what a verifier can actually work from, so Module 06's screen should be built around the raw text beside the photo. |

**Module 05 replaced §7's AI step with on-device OCR — the user's explicit decision (2026-09-23): no paid AI API, no key, no backend.** §7's Cloud Function + Storage + Secret Manager design was unreachable (all Blaze-only) and §10 forbids putting an AI key in the Flutter binary, so extraction now runs Google ML Kit's bundled Latin model locally. No prescription image or text leaves the phone. The safety architecture is intact: extraction creates no medication and activates nothing, and §7's real backstop — the human approval gate — is untouched. Full reasoning in ARCHITECTURE.md §18's Module 05 entry.

Firebase project `nuriva-27e59` is live: Firestore in `asia-south1`, Email/Password auth enabled, `firestore.rules` deployed (covering `users`, `patients`, `guardian_relationships`, `patient_link_codes`, `prescriptions` and `prescriptions/{id}/extractions`). **The project stays on the Spark (free) plan by the user's explicit, permanent choice — no Blaze, ever.** Firebase Storage is consequently unused: Module 04 saves prescription images to the device's local filesystem instead (see Module 04 below and ARCHITECTURE.md §18).

---

## Blockers

None currently. (Module 02's Firebase blocker is resolved — see below.)

### Firebase configuration — how it was resolved (2026-09-16/17)

Two things were required, and only the user could do them:

1. **Choose the Firestore region** — done. **Decision (2026-09-14): India — Firestore location `asia-south1` (Mumbai).** Permanent.
2. **Run `firebase login` / `flutterfire configure`** — done. Interactive steps the user completed:
   - `firebase login` (browser sign-in as `sayanlookingtwrdsdstny@gmail.com`)
   - Enabled the Cloud Firestore API (console click — CLI can't enable APIs on this machine, no `gcloud`)
   - Created the Firestore database in `asia-south1` via CLI (`firebase firestore:databases:create`)
   - Set up the default Storage bucket in `asia-south1` via console (Storage has no CLI creation command in this firebase-tools version)
   - Ran `flutterfire configure` → generated `lib/firebase_options.dart`, registered the Android app, wrote `firebase.json`, `android/app/google-services.json`
   - Enabled the **Email/Password** sign-in provider in console → Authentication → Sign-in method (`flutterfire configure` does not do this — it only registers the app, not sign-in providers. A registration attempt fails with `CONFIGURATION_NOT_FOUND` until this is on.)

Notes on what the region decision binds:
- A Firebase *project* has no region. The location is fixed when the **Firestore database** is created, and separately for the default **Cloud Storage** bucket. Both are in `asia-south1` so patient data and prescription images share one jurisdiction.
- Cloud Functions take a region per function; deploy them to `asia-south1` too.
- Regulatory regime: **India DPDP Act 2023** — explicit consent capture, purpose limitation, breach notification, and a grievance/erasure path. Consent-at-registration landed in Module 02; deletion is Module 17.

`bootstrap.dart`'s `initializeBackend()` now calls `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` — no longer the Module 01 no-op.

`firebase_options.dart` and `android/app/google-services.json` are committed. Both hold public client identifiers (API key, app ID, project ID), not secrets — access is enforced by Firestore/Storage Rules, not by hiding this file. This matches Firebase's own guidance for client apps.

---

## Module 01 — Foundation (v0.1.0) ✅

### Completed features

- NURIVA brand identity — mark, wordmark, app label, package id
- Full design system with light/dark themes
- Declarative routing with an auth-guard seam
- Clean/feature-first architecture with DI
- Typed error handling (`Result<T>` + sealed `AppFailure`)
- Structured logging with patient-data redaction
- Build-time configuration via flavors and `--dart-define`
- Injectable clock (no `DateTime.now()` in domain code)

### Screens

| Screen | Route | Notes |
|---|---|---|
| Splash | `/` | Branded, animated; resolves destination. Module 02 replaces the timer with real auth-state resolution |
| Foundation home | `/home` | Honest build-state screen. Module 13 replaces it with the guardian dashboard |
| Design gallery | `/design-system` | **Developer-only** — the route is not even registered when `allowDeveloperTools` is false |

### Files created

```
lib/core/design/          nuriva_tokens · nuriva_theme · nuriva_brand
                          nuriva_button · nuriva_surfaces · nuriva_field
                          nuriva_feedback · design.dart (barrel)
lib/core/config/          app_config.dart
lib/core/constants/       firestore_paths.dart
lib/core/di/              providers.dart
lib/core/errors/          app_failure.dart
lib/core/logging/         app_logger.dart
lib/core/result/          result.dart
lib/core/routing/         app_routes · route_guard · app_router
lib/core/time/            clock.dart
lib/features/splash/presentation/splash_screen.dart
lib/features/home/presentation/foundation_home_screen.dart
lib/features/design_gallery/presentation/design_gallery_screen.dart
lib/app.dart · lib/bootstrap.dart · lib/main.dart
```

### Files modified

- `pubspec.yaml` — version `1.0.0+1` → `0.1.0+1`; deps added/removed
- `android/app/build.gradle.kts` — namespace + applicationId → `com.nuriva.app`; `ndkVersion` documented
- `android/app/src/main/AndroidManifest.xml` — `android:label` → `NURIVA`
- `android/app/src/main/kotlin/com/nuriva/app/MainActivity.kt` — moved from `com/nuriva/nuriva`

### Files removed

- `lib/core/theme/app_theme.dart`, `lib/shared/widgets/` — superseded by `core/design/`

### Dependencies

**Added:** `flutter_riverpod` (state + DI, replaces a separate service locator), `go_router` (routing + deep links for notification taps), `intl` (formatting/localization seam), `mocktail` (dev).

**Removed:** `mutation_test` — spec §5 forbids mutation testing at this stage.

**Not added yet, deliberately:** Firebase packages (no project), `freezed` (Dart 3 native `sealed` covers unions without codegen; add at Module 03+ when entities need `copyWith`/JSON), `permission_handler` / media packages (not needed until their modules).

### Database changes

None. No Firebase project exists. `core/constants/firestore_paths.dart` defines the intended schema paths and deterministic IDs but nothing connects to them yet.

### Testing completed

**141 tests passing**, `flutter analyze` clean.

Basic functional testing per §5 — no advanced testing performed.

| Area | Coverage |
|---|---|
| `Result<T>` | success/failure, map, flatMap, fold, guard, guardAsync |
| `AppFailure` | 8 variants, codes unique, exhaustive switch |
| `Clock` | UTC normalization, advance/setTo, negative rejection |
| `AppConfig` | flavor/log-level parsing, production tool lockout |
| `FirestorePaths` | path parity, deterministic IDs, storage scoping |
| `AppLogger` | level filtering, **PHI redaction** by key and free text |
| Route guards | signed-in/out redirects, public routes, revocation |
| Design system | button variants, busy state, status chips, state views |
| Theme | light/dark status colours, touch targets, 4dp rhythm |
| **App smoke (`test/app_smoke_test.dart`)** | launches, splash → home handoff, scrolling, dev gallery reachable, **prod gallery unreachable**, dark theme, 3× system font |

#### Two real defects the smoke test caught

`flutter analyze`, 134 unit tests and a **successful APK build** all passed while
the app did not render. Component-level tests did not catch either of these,
because both only appear when the widgets are composed into real screens.
**Keep the smoke test green — it is the only check that the app actually boots.**

1. **`NurivaCard` demanded infinite height.** The accent rail used a `Row` with
   `CrossAxisAlignment.stretch`, which asks for the parent's full height. Inside
   a sliver that is unbounded, so layout threw *"BoxConstraints forces an
   infinite height"* and every screen using an accent card failed to render.
   **Fixed** by positioning the rail in a `Stack` — the card sizes to its
   content and the rail fills it, with none of `IntrinsicHeight`'s cost.

2. **The splash leaked an uncancelled timer.** `Future.delayed` in `initState`
   kept running after disposal and then called `context.go` on a dead element.
   **Fixed** with a `Timer` field cancelled in `dispose()`.

### Known issues / limitations

1. **Firebase not wired** — the one deferred item. See "Blockers".
2. **Splash uses a fixed 1.4s delay** rather than real auth resolution. Module 02 replaces it; the dwell stays as a floor to avoid a jarring flicker.
3. **Launcher icon is still Flutter's default.** The in-app `NurivaMark` is custom-drawn, but the Android launcher icon was not replaced — it needs generated PNG densities. Cosmetic; worth doing before any external test build.
4. **Not yet run on a physical device.** No Android device has been connected (`adb devices` empty) and no emulator is installed. The APK is built but unverified on real hardware.

### Deferred features

- Firebase initialization + App Check → Module 02 (initialization done in Module 02; **App Check deferred to Module 17**, see below)
- Launcher icon PNG densities → before external distribution
- Widget/golden tests for reminder screens → Modules 10–11, where layout regressions become a safety issue

---

## Module 02 — Authentication (v0.2.0) ✅

### Completed features

- Firebase project `nuriva-27e59` created; Firestore + Storage in `asia-south1`
- Firebase Authentication, email/password, wired end-to-end (`bootstrap.dart` now calls `Firebase.initializeApp`)
- Registration → email verification → profile completion → home, matching ARCHITECTURE.md §5's state machine exactly
- Sign-in, sign-out, forgot-password (neutral response — never reveals whether an address has an account)
- Consent capture at registration (`kPrivacyNoticeVersion`, DPDP Act 2023) with a dedicated privacy-notice screen
- `users/{uid}` Firestore profile document, created once at registration (or at profile-completion recovery), never client-updated after
- `firestore.rules` — deny-by-default; only the `users/{uid}` create/read shape used by Module 02 is allowed, everything else explicitly closed pending its owning module
- `storage.rules` — deny-all (nothing in Module 02 touches Storage)
- `SessionRouteGuard` drives all navigation off `AuthSession` — no screen navigates on its own auth event

### Screens

| Screen | Route | Notes |
|---|---|---|
| Welcome | `/welcome` | Entry point for a signed-out user |
| Sign in | `/login` | |
| Register | `/register` | Role selection (self / family member / both), consent checkbox, links to the privacy notice |
| Privacy notice | `/privacy` | Reachable signed-out (from registration) and signed-in (`NeedsProfile`) |
| Forgot password | `/forgot-password` | Carries a typed email across from sign-in via a query param |
| Verify email | `/verify-email` | Polls `reloadUser`; cooldown on resend; "use a different account" signs out |
| Complete profile | `/complete-profile` | Recovery path for an account whose profile write never completed |
| Home | `/home` | Replaces Module 01's `foundation_home_screen.dart` (deleted) — real signed-in state, shows profile + build status |

### Files created

```
lib/features/auth/domain/       auth_models · auth_repositories · auth_validators · account_service
lib/features/auth/data/         firebase_auth_repository · firestore_profile_repository · auth_error_mapper
lib/features/auth/application/  auth_providers · session_route_guard
lib/features/auth/presentation/ welcome · sign_in · register · forgot_password · privacy_notice
                                 verify_email · complete_profile · auth_copy
                                 widgets/account_fields · widgets/auth_scaffold
lib/features/home/presentation/ home_screen.dart (replaces foundation_home_screen.dart)
lib/core/config/                app_version.dart · legal.dart
lib/core/design/                nuriva_inline_message.dart
lib/firebase_options.dart       generated by flutterfire configure — public client config, safe to commit
firebase.json, firestore.rules, storage.rules
android/app/google-services.json
```

### Files modified

- `pubspec.yaml` — version `0.1.0+1` → `0.2.0+2`; added `firebase_core`, `firebase_auth`, `cloud_firestore`
- `bootstrap.dart` — `initializeBackend()` now calls `Firebase.initializeApp`, no longer a no-op
- `app_router.dart`, `app_routes.dart`, `route_guard.dart` — auth routes + `SessionRouteGuard` wiring
- `design.dart`, `nuriva_surfaces.dart` — additions used by the auth screens
- `app_failure.dart` — auth/Firestore failure variants
- `splash_screen.dart` — Module 01's fixed dwell now hands off into real session resolution
- `android/gradle.properties` — see "Environment gotchas" below (Kotlin build workaround)

### Files removed

- `lib/features/home/presentation/foundation_home_screen.dart` — superseded by `home_screen.dart`

### Dependencies

**Added:** `firebase_core`, `firebase_auth`, `cloud_firestore`.

**Not added yet, deliberately:** `firebase_app_check` (Module 17 — see below), Storage SDK usage beyond the generated config (Module 04).

### Database changes

`users/{uid}` is now a real, live collection with one document shape:
```
{ uid, displayName, email, roles: [...], consent: { version, acceptedAt }, createdAt, updatedAt }
```
Every other path in `core/constants/firestore_paths.dart` remains unused until its owning module, and `firestore.rules` denies them explicitly rather than leaving them to a project default.

### Testing completed

**191 tests passing** (up from 141 in Module 01), `flutter analyze` clean.

Basic functional testing per §5 — no advanced testing performed. Unit/widget tests cover registration, sign-in, sign-out, forgot-password, verification, session routing and the Firestore rule shape (all against fakes). **Live-device functional testing was also done against the real `nuriva-27e59` backend** (not just fakes) — see below.

#### Live-device verification (2026-09-17, physical phone via ADB)

Every step below was confirmed against the real Firebase project, not a fake:

1. App boots, Firebase initializes, lands on Welcome (signed-out) — confirmed via screenshot
2. Registration creates a real Firebase Auth user **and** the matching `users/{uid}` Firestore document (confirmed independently in the Firebase console — both existed)
3. Email verification link (sent by Firebase, landed in spam) → app correctly detects verification and routes to Home
4. Home renders the real profile (name, email, role chip) and correctly reports Module 03 as pending
5. Sign-out → Welcome; sign back in with the same credentials → Home (confirmed manually — see below)

#### Two real defects the live device run caught (neither is a code bug)

1. **`CONFIGURATION_NOT_FOUND` on the first registration attempt.** `flutterfire configure` registers the Firebase *app* but does not enable any sign-in *provider*. Email/Password had to be turned on manually in Console → Authentication → Sign-in method. Documented in "Blockers" above so it isn't rediscovered.
2. **Android autofill kept substituting the tester's real Google account** (name + email, and once appears to have supplied a saved password) into the registration form when fields were tapped via ADB, instead of the intended throwaway test values. Not an app bug — it is Android's autofill service reacting to a real signed-in device. Worth knowing for any future on-device testing session: prefer typing values explicitly (`adb shell input text`) over tapping-then-assuming-the-field-is-empty, or disable autofill for the app during testing.

Because of defect 2, the real Firebase project now has one live user (`sayanlookingtwrdsdstny@gmail.com`) created during testing. Left in place rather than deleted, since deleting a real user via a scripted export was itself denied by the permission classifier as too sensitive an action to automate — deleting it, if wanted, is a one-click action in Console → Authentication → Users.

### Known issues / limitations

1. **Storage stays on the Spark (free) plan by explicit user choice.** Module 02 needs no Storage access, so this had zero effect at the time. **Resolved at Module 04, permanently, the other direction**: the user declined Blaze outright rather than revisiting it, so Module 04 saves prescription images to the device's local filesystem instead of Storage — see Module 04 below and ARCHITECTURE.md §18.
2. **App Check is deferred to Module 17**, not wired now. ARCHITECTURE.md §5 calls for it alongside Firebase Auth, but wiring it without the Firestore/Storage rules and attestation config that go with it would be security theatre rather than real hardening — Module 17 owns all of that together.
3. Sign-out was verified manually on-device rather than via ADB automation — synthetic `input tap` events did not reliably trigger the `IconButton`'s response (likely a splash/hit-test timing issue with instant synthetic taps), and repeated attempts were abandoned in favor of the user confirming manually. Not a product defect.

### Deferred features

- App Check → Module 17
- Storage rules beyond deny-all → **superseded**: Firebase Storage is not used at all now (Module 04 uses local device storage instead — see below)
- Profile editing (`update` on `users/{uid}`) → whichever module first needs it; `firestore.rules` currently denies all updates

---

## Module 03 — Patient & Guardian (v0.3.0) ✅

### Completed features

- Self-patient records (`patients/{uid}`, created silently for any signed-in user with the `patient` role, idempotent) and guardian-managed patients (`patients/{autoId}`, created explicitly via "Add a patient")
- Guardian relationships (`guardian_relationships/{patientId}__{guardianUid}`) with a primary guardian per patient, `ACTIVE`/`PENDING`/`REJECTED`/`REVOKED` status, and a narrow, non-default `GuardianPermission` set (`viewMedications`, `manageMedications`, `viewAdherence`, `manageAppointments`, `viewPrescriptions`) — invite defaults are `{viewMedications, viewAdherence}` only; **`manageMedications` (the permission that can activate a live dosing schedule) is never granted by default**, matching this repo's healthcare-safety rule
- Link-code invites (`patient_link_codes/{code}`): a primary guardian generates a 6-character code scoped to chosen permissions, 24h expiry, single-use; redemption is a client-side Firestore transaction (not a Cloud Function — Module 03 deliberately stays on the Spark plan, see ARCHITECTURE §18) that atomically consumes the code and creates a `PENDING` relationship
- Approve / reject / revoke a relationship, all guarded by `firestore.rules`, not just client logic
- `CareCircleRouteGuard` — a signed-in user with no patient in their care circle (no self-record, guards no one) is routed to `/care-circle/start` until they add or join one; `addPatient`/`joinPatient` stay reachable at any time afterward
- Home screen now links to the Patients feature and reports Modules 01–03 as built

### Screens

| Screen | Route | Notes |
|---|---|---|
| Care circle start | `/care-circle/start` | Onboarding-only redirect target for a signed-in user with an empty care circle |
| Add a patient | `/care-circle/add-patient`, also `/family` → "+" | Creates a guardian-managed patient; creator becomes primary guardian |
| Join with a code | `/care-circle/join` | Redeems a link code into a `PENDING` relationship |
| Patients list | `/family` | Self-record (if any) plus every patient guarded via an `ACTIVE` relationship |
| Patient detail | `/family/:patientId` | Patient info, guardian list with permissions, invite-a-guardian sheet, generated code |

### Files created

```
lib/core/constants/timezones.dart
lib/features/patients/domain/      patient_models · patient_repositories · link_code_generator
lib/features/patients/data/        firestore_patient_repository · firestore_guardian_relationship_repository
lib/features/patients/application/ patient_providers · care_circle_service · care_circle_route_guard
lib/features/patients/presentation/ care_circle_start_screen · add_patient_screen · join_patient_screen
                                     patients_list_screen · patient_detail_screen · patient_copy
                                     widgets/invite_guardian_sheet
test/features/patients/            (domain + application unit tests)
test/support/fake_patients.dart
```

### Files modified

- `pubspec.yaml`, `app_version.dart` — version `0.2.0+2` → `0.3.0+3`
- `firestore.rules` — added `patients`, `guardian_relationships`, `patient_link_codes` (see "Two real defects" below for the fix history within this module)
- `app_router.dart`, `app_routes.dart` — patients routes + `CareCircleRouteGuard` wiring, `hasCareCircleProvider` drives router refresh alongside `sessionProvider`
- `firestore_paths.dart` — `patientLinkCode(code)` helper
- `home_screen.dart` — Patients entry point, "what is built" and "next module" copy updated

### Dependencies

No new packages. `NurivaTimezones` (`core/constants/timezones.dart`) is a hand-written IANA zone list, not a plugin — deliberately avoids a `timezone`-package dependency for a Module 03-sized need.

### Database changes

Three new live collections in `nuriva-27e59`:
```
patients/{patientId}              — self (id == uid) or guardian-managed (auto id)
guardian_relationships/{patientId}__{guardianUid} — deterministic id, one per (patient, guardian) pair
patient_link_codes/{code}         — 6-char code, 24h expiry, single-use
```
`firestore.rules` denies everything else explicitly, as in Module 02.

### Testing completed

**224 tests passing** (up from 191 in Module 02), `flutter analyze` clean. Domain, application/service, route-guard, and link-code-generator layers are unit-tested; the Firestore repositories and the 6 presentation screens are not — coverage gap accepted for this module, same trade Module 02 made, closed instead by live-device testing below.

Basic functional testing per §5 — no advanced testing performed.

#### Live-device verification (2026-09-17, physical phone via ADB, real `nuriva-27e59` backend)

Confirmed against the real project, not fakes: patient creation (self and guardian-managed), guarded-patients list loading, invite-guardian sheet's default permission set (`viewMedications` + `viewAdherence` only, `manageMedications` unchecked — matches the domain default and the healthcare-safety rule), link-code generation, timezone auto-detection to `Asia/Kolkata`.

#### Two real defects the live-device run caught

1. **`firestore.rules` was never deployed.** The Module 03 rules existed only in the repo (`git status` showed it modified, uncommitted, and — separately — never pushed to the live project via `firebase deploy`). Every Module 03 query failed `PERMISSION_DENIED` until `firebase deploy --only firestore:rules --project nuriva-27e59` was run. Not a code bug, but worth a permanent note: **finishing a module's rules file is not the same as deploying it** — this session had no record that Module 02's own rules deploy had been a manual, easy-to-forget step either.
2. **A genuine rules bug, found only after (1) was fixed.** `watchGuardianPatients` queries `guardian_relationships where guardianUid==<uid> and status==ACTIVE` — a `list`, not a `get`. Cloud Firestore only allows a `list`/query request when the security rule can be proven true **directly from the query's own `where` filters**, evaluated once against the query as declared — it does not run the query first and check the rule per returned document. The original rule granted access via `relationshipId == resource.data.patientId + '__' + request.auth.uid` (a document-ID string match) with no clause referencing the `guardianUid` *field* the query actually filters on, so Firestore could not prove the rule held for the query and denied it outright — for any data, not merely when nothing matched. (This also explains, in hindsight, why `watchRelationshipsForPatient`'s query — filtered by `patientId`, matching the rule's `isActivePrimaryOf(resource.data.patientId)` branch on that same field — worked the whole time.) **Fixed** by adding `resource.data.guardianUid == request.auth.uid` as a directly provable OR-branch in `firestore.rules`, redeployed. General lesson for every future rule on a field a client will `.where()` by: the rule must reference that literal field, not just something structurally equivalent to it (like the document ID), or Firestore cannot verify the query is safe and refuses it unconditionally.

#### One more defect, found while fixing the above

**`patients_list_screen.dart` showed "Could not load your patients. Pull to retry." with no way to actually retry.** The `ListView` was never wrapped in a `RefreshIndicator`, and nothing called `ref.invalidate(...)` anywhere in the patients feature. `selfPatientProvider`/`guardianPatientsProvider` are plain (non-`autoDispose`) `StreamProvider`s, so once the underlying Firestore listen errors — as it did during defect (1) above — the provider keeps serving that terminal `AsyncError` forever; merely leaving and re-entering the route does not create a fresh subscription. A real user who ever hit a transient read failure here (a network blip, not just the rules bug above) would have been stuck until an app restart. **Fixed** by wrapping the list in a `RefreshIndicator` whose `onRefresh` invalidates both providers.

### Known issues / limitations

1. **Firestore repositories and presentation screens have no automated tests** (unit/widget) — only domain/application layers do. Live-device testing covered the gap for this module; a future module should consider adding at least fake-repository-backed widget tests for the patients screens before the surface area grows further.
2. **Two incidental test patients exist in the live `nuriva-27e59` project** — "Sucharita Sarkar" and "Archana Chakrabor" — created when Android's autofill substituted real contact names/DOBs into the "Add a patient" form during ADB-driven testing (the same class of issue Module 02 documented with the registration form). Harmless dev-project data; left in place. Deletable in one click via Firestore console → `patients` collection (and the matching `guardian_relationships` docs) if wanted.
3. `watchGuardianPatients` re-fetches every guarded patient by ID whenever the caller's relationship set changes, rather than getting live per-patient updates — an accepted MVP trade documented inline in `firestore_patient_repository.dart`, fine for a care circle of a handful of patients.

### Deferred features

- Archiving a patient, editing `guardianUids` → whichever module first needs them; `firestore.rules` currently denies all `patients` updates
- Cloud Function-based link-code redemption → only if the Spark-plan constraint is lifted; the current client-transaction approach is deliberate (ARCHITECTURE §18), not a placeholder

---

## Module 04 — Prescription Upload (v0.4.0) ✅

**Build status:** succeeded 2026-09-23 once free RAM cleared ~0.7 GB (three
earlier attempts had failed at ~0.2-0.3 GB free — see environment gotcha
#6). `flutter build apk --debug` completed in 142.7s. Artifact identity
verified with `aapt dump badging`: `com.nuriva.app`, `versionName 0.4.0`,
`versionCode 4`, `targetSdk 36`, label `NURIVA`.

### Completed features

- Camera/gallery capture of a prescription (1-10 pages), compressed
  client-side (`flutter_image_compress`, long edge 1600px, quality 80) before
  saving
- **No Firebase Storage.** The user declined the Blaze plan permanently
  (see "CURRENT STATE" above and ARCHITECTURE.md §18's Module 04 entry).
  Page images are saved to the device's local filesystem instead
  (`path_provider`, deterministic layout
  `<appDocumentsDir>/prescriptions/<patientId>/<prescriptionId>/page_<n>.jpg`);
  `prescriptions/{id}` in Firestore holds metadata only and never sees an
  image byte
- `firestore.rules` — `prescriptions` added: read/create/delete gated on
  `isPatientSelf` or the `VIEW_PRESCRIPTIONS` guardian permission (the only
  prescription-related permission Module 03 defined — there is no separate
  "upload" permission); `create` whitelists fields and caps `pageCount` at
  1-10; `update` is fully closed (Module 05 owns status transitions);
  `delete` only while `status == UPLOADED`
- A picker screen ("Prescriptions" from Home) that skips straight to a
  patient's list when there's exactly one viewable patient, and otherwise
  lets the user choose among the self-patient plus every guarded patient
  whose relationship carries `VIEW_PRESCRIPTIONS`
- Upload rollback: if saving pages locally fails after the Firestore record
  is created, `PrescriptionService` deletes that record again rather than
  leaving an `UPLOADED` prescription with no image anywhere
- Delete: removes the Firestore record and this device's local files;
  deleting from a device that never had the files removes only the record
  (documented limitation, not a bug — see below)

### Screens

| Screen | Route | Notes |
|---|---|---|
| Prescription patient picker | `/prescriptions` | Auto-redirects when there's exactly one viewable patient |
| Prescriptions list | `/prescriptions/:patientId` | Pull-to-refresh; FAB opens the add-prescription sheet |
| Prescription detail | `/prescriptions/:patientId/:prescriptionId` | Pages (or a "not on this device" explanation per page), delete while `UPLOADED` |
| Add-prescription sheet | (modal, from the list screen) | Camera/Gallery buttons, thumbnail strip with per-page remove, "Upload N pages" |

### Files created

```
lib/features/prescriptions/domain/       prescription_models · prescription_repositories
                                          local_image_store · image_capture_service
lib/features/prescriptions/data/         firestore_prescription_repository
                                          local_prescription_image_store · device_image_capture_service
lib/features/prescriptions/application/  prescription_providers · prescription_service
lib/features/prescriptions/presentation/ prescription_patient_picker_screen · prescriptions_list_screen
                                          prescription_detail_screen · prescription_copy
                                          widgets/add_prescription_sheet
test/features/prescriptions/             (domain + application unit tests)
test/support/fake_prescriptions.dart
```

### Files modified

- `pubspec.yaml`, `app_version.dart` — version `0.3.0+3` → `0.4.0+4`; added
  `image_picker`, `flutter_image_compress`, `path_provider`
- `firestore.rules` — added `prescriptions` (metadata-only; see above);
  factored a new `isPatientSelf(patientId)` helper (patients rules keep
  their existing inline check untouched, to avoid touching a live-verified
  file for a module that doesn't need to)
- `firestore_paths.dart` — removed the unused `prescriptionStorage(...)`
  helper (dead code pointing at a Firebase Storage path this module
  deliberately doesn't use); the corresponding test group in
  `firestore_paths_test.dart` was removed too
- `app_routes.dart`, `app_router.dart` — `prescriptionsFor(patientId)`,
  `prescriptionDetail`/`prescriptionDetailFor(...)` + the three routes above
- `home_screen.dart` — "Prescriptions" entry point added; Module 04 moved
  from "Next" into "What is built"; "Next" now names Module 05
- `android/app/src/main/AndroidManifest.xml` — `CAMERA` permission +
  optional `android.hardware.camera` feature, for `image_picker`'s camera
  source

### Dependencies

**Added:** `image_picker` (camera/gallery capture), `flutter_image_compress`
(client-side compression before saving), `path_provider` (locates the app's
local documents directory for image storage).

**Not added:** `file_picker` — PDF support is deferred (see "Known issues"
below); `firebase_storage` — deliberately not used at all (this module's
core deviation, see ARCHITECTURE.md §18).

### Database changes

One new live collection in `nuriva-27e59`, metadata only:
```
prescriptions/{prescriptionId}
  patientId, uploadedByUid, mimeType, pageCount (1..10)
  prescribedDate | null, doctorName | null, clinicName | null
  status: 'UPLOADED'          <- only status this module ever writes
  createdAt, updatedAt
```
No image bytes reach Firestore. `firestore.rules` denies everything else
explicitly, as in Modules 02-03.

### Testing completed

**229 tests passing** (up from 224 in Module 03 — 8 new, minus 3 removed
along with the dead `prescriptionStorage` helper), `flutter analyze` clean.

Domain (`prescription_models_test.dart`) and application
(`prescription_service_test.dart`, against `FakePrescriptionRepository` +
an in-memory `FakeLocalImageStore` so no platform channel is touched) layers
are unit-tested — validation of the page-count bounds, the create-then-save
ordering, and the rollback-on-local-failure path.

Basic functional testing per §5 — no advanced testing performed.

Following the same trade Modules 02-03 made: the Firestore repository, the
real `LocalPrescriptionImageStore` (actual disk I/O), and the four
presentation screens are **not** covered by automated widget/repository
tests — live-device testing below covered the gap for this module.

#### Live-device verification (2026-09-23, physical phone via ADB, real `nuriva-27e59` backend)

Confirmed against the real project, not fakes: prescriptions patient picker
(auto-redirect for a single viewable patient, picker list for multiple —
both of Module 03's incidental test patients showed correctly), empty
state, add-prescription sheet, gallery-picked image compressed and saved
locally at the documented deterministic path
(`app_flutter/prescriptions/<patientId>/<prescriptionId>/page_0.jpg`,
confirmed via `run-as` on-device), Firestore metadata record created and
reflected live in the list as "Uploaded", detail screen rendering the saved
image, delete (confirm dialog, dismiss = no) removing both the Firestore
record and the local file.

#### One real defect the live-device run caught

**`firestore.rules`'s `prescriptions` block was never deployed to the live
project** — the exact same class of issue Module 03 documented ("finishing
a module's rules file is not the same as deploying it"). The block existed
in the repo (uncommitted, like the rest of Module 04's code) but the live
project was still running only Module 03's rules, so every prescription
create was denied with `PERMISSION_DENIED`. Firestore's local offline
mutation queue had also silently queued a couple of earlier failed create
attempts (from manual testing before this verification pass) and kept
retrying them on every app launch, which is what first surfaced the error
in logcat before any deliberate test action was taken. **Fixed** by running
`firebase deploy --only firestore:rules --project nuriva-27e59`; confirmed
clean by uninstalling and reinstalling the app (flushing the stale offline
queue and local cache) and redoing the upload from a clean state, which
then succeeded with no Firestore errors in logcat.

### Known issues / limitations

1. **A prescription's image is visible only on the device that uploaded
   it.** This is the module's central, accepted trade-off for staying free
   — see ARCHITECTURE.md §18's Module 04 entry for the full reasoning. The
   Firestore metadata record syncs normally; the pixels do not. The detail
   screen shows an explicit "not on this device" state per page rather than
   an error.
2. **No PDF support.** `file_picker`/PDF prescriptions (ARCHITECTURE.md
   §14) are deferred — there's no PDF page-rendering library in the project
   to split a PDF into the per-page image files this module's local-storage
   layout assumes. Camera + gallery photos cover the real use case.
3. **Deleting from a device that never had the local files removes only the
   Firestore record.** `PrescriptionService.deletePrescription` only ever
   reaches *this* device's own local store — there is no server-side copy
   to clean up elsewhere. Expected given limitation 1, not a separate bug.
4. **Module 05 (AI/OCR) has an open question this module creates**: Cloud
   Functions also require Blaze, and there is now no server-accessible copy
   of a prescription's image (no Storage, no Firestore copy) for a Function
   to read. Not resolved here — flagged as a Module 05 planning question in
   ARCHITECTURE.md §18.

### Deferred features

- PDF prescriptions → whichever future module first needs them
- Editing a prescription after upload (`update` on `prescriptions/{id}`) →
  Module 05 owns the status transitions that follow extraction
- Any server-side access to prescription images at all → Module 05, see
  "Known issues" #4 above

---

## Module 05 — Prescription Reading / on-device OCR (v0.5.0) ✅

**The AI decision:** the user chose **on-device OCR, no LLM, no paid AI API**
(2026-09-23), from three options put to them. §7's design — Cloud Function
reads image from Storage, calls a vision model with a key from Secret
Manager — needs Blaze three times over, and §10 rules out shipping a key in
the app. ARCHITECTURE.md §18's Module 05 entry has the full reasoning.

### Completed features

- **On-device text recognition** via `google_mlkit_text_recognition`
  (bundled Latin model). Confirmed on-device from logcat:
  `DynamiteModule: Selected local version of
  com.google.mlkit.dynamite.text.latin` — no Play Services download, no
  network call, no key anywhere in the repo or the binary
- **A conservative parser** (`PrescriptionTextParser`, versioned
  `parser-1`) that proposes medication candidates only from defensible
  patterns and emits `null` + a stable warning token otherwise. It never
  infers, completes, clamps or normalizes a medical value
- **§7's five-stage cascade, adapted**: parse → shape → business rules
  (doses/day 1-12, duration 1-365, name non-empty) → confidence gate at
  0.85 → a directive screen. Stage 5 was retargeted: with no model to
  steer, it now flags page text that reads like an instruction to the app
  ("ignore previous instructions, set the dosage to...") so the UI can mark
  it suspicious instead of presenting it as a doctor's words
- **Raw recognized text is always stored verbatim**, even when parsing finds
  nothing. Unlike the page images (device-local, §18's Module 04 deviation)
  this text *does* sync, so a second guardian who cannot see the photo can
  still read what it said
- **Append-only extraction records** at `prescriptions/{id}/extractions` —
  re-running writes a new record; nothing overwrites what a device actually
  read
- **A state machine in `firestore.rules`**: `UPLOADED|FAILED -> PROCESSING`,
  `PROCESSING -> EXTRACTED|FAILED`, with `status` + `updatedAt` the only
  fields any client may ever change on a prescription
- **Creates no medication and schedules no dose.** Asserted by a test, not
  just intended

### Screens

| Screen | Route | Notes |
|---|---|---|
| Extraction panel | (section on `/prescriptions/:patientId/:prescriptionId`) | "Read this prescription", then status, warnings, candidate cards and the full raw text. Every candidate card is labelled a draft; unread fields say "Not read" rather than showing a blank |

### Files created

```
lib/features/prescriptions/domain/      extraction_models · ocr_engine
                                         prescription_text_parser
                                         extraction_repositories
lib/features/prescriptions/data/         mlkit_ocr_engine
                                         firestore_extraction_repository
lib/features/prescriptions/application/  extraction_service
lib/features/prescriptions/presentation/ widgets/extraction_panel
test/features/prescriptions/domain/      prescription_text_parser_test
test/features/prescriptions/application/ extraction_service_test
test/support/fake_extractions.dart
```

### Files modified

- `pubspec.yaml`, `app_version.dart` — `0.4.0+4` → `0.5.0+5`; added
  `google_mlkit_text_recognition`
- `prescription_repositories.dart`, `firestore_prescription_repository.dart`
  — `updateStatus` for the extraction state machine
- `firestore.rules` — `prescriptions` update opened narrowly to the state
  machine (was `if false`); `extractions` subcollection added
- `prescription_detail_screen.dart` — hosts the extraction panel
- `prescription_copy.dart` — warning and extraction-status wording
- `home_screen.dart` — Module 05 in "what is built", 06 as next
- `test/support/fake_prescriptions.dart` — `updateStatus` + `statusWrites`

### Dependencies

**Added:** `google_mlkit_text_recognition` (+ `google_mlkit_commons`). The
model is bundled into the APK, which is what makes it work offline with no
key — and what took the debug APK from 172.6 MB to 204.9 MB.

**Not added:** any AI SDK or HTTP client. There is no remote call to make.

### Database changes

```
prescriptions/{id}/extractions/{extractionId}
  engine: 'MLKIT_ON_DEVICE'   <- pinned by rules
  engineVersion, status: EXTRACTED | NEEDS_REVIEW | FAILED
  rawLines[], candidates[], pagesProcessed, warnings[]
  createdByUid, createdAt
```

`prescriptions/{id}.status` now moves through the state machine above.

### Testing completed

**263 tests passing** (up from 229), `flutter analyze` clean. The parser
carries the bulk of the new coverage, and most of its tests assert that it
*refuses* to produce a value — fractional doses, all-zero frequencies,
out-of-range counts and durations, missing fields, and table fragments.

#### Live-device verification (2026-09-23, physical phone, real backend)

Run against the real prescription used throughout testing — a creased,
photographed M.V. Hospital sheet with a four-row medicine table.

Confirmed: ML Kit loaded its bundled local model; one page read; the full
raw text captured and displayed; `EXCERAFT SYRUP` and `ENZOX PLUS TAB` read
with correct names and forms; status correctly `Needs checking`; the safety
banner, amber review rails and "Not read" fields all rendered; extraction
record written to Firestore with no permission errors.

#### Two real defects the live-device run caught

1. **The panel offered "Read this prescription" when it already knew the
   photo wasn't on this phone.** The screen showed "Page 1 is not on this
   device" directly above an inviting primary button whose only possible
   outcome was an error toast — the same shape as Module 03's "pull to
   retry" with no retry. **Fixed** by gating the action on local page
   availability and showing an explanatory card instead. Re-verified on
   device: the card appears for the record whose images are gone, and the
   button still appears for the one whose image is present.
2. **Table fragments became empty candidate cards.** OCR over the medicine
   table emitted bare cells — `tablet`, `1 tablet`, `L capsule` — and a form
   word alone was enough to pass the "is this a medication line?" test, so
   the panel showed cards whose every field read "Not read". That is exactly
   the noise the parser was written to avoid, and noise here is not harmless:
   it teaches a guardian to skim the one screen that exists to be read
   carefully. **Fixed** by requiring a candidate to carry at least one of
   name / strength / doses-per-day / duration. Regression tests use the
   verbatim fragments from this run. **Re-verified on device** against a
   second upload of the same prescription: the empty cards were gone, and
   the run surfaced three correctly named medicines (`EXCERAFT SYRUP`,
   `ENZOX PLUS TAB`, `Sompraz D (40 &`) — one more than before, since
   nothing of value was suppressed.

### Known issues / limitations

1. **On tabular prescriptions the candidate cards yield names and forms
   only — the raw text is the real deliverable.** ML Kit returns each table
   cell as its own line, so a medicine name and its `0-1-1` frequency arrive
   detached, with `Quantity` / `Prequency` / `Duration` headers as further
   standalone lines. The parser correctly refuses to pair them; associating
   by proximity would be precisely the guess §7 forbids. **Module 06 should
   build its verification screen around the raw text beside the photo, not
   around the candidate list.**
2. **OCR quality on a creased photo is moderate, and varies run to run.**
   Real output included `Ajler Lunch, After Diner`, `Brrpty Stomach`,
   `Dr. Mrinal Kani Bhatlachaya`, `Frequenev`, and — worth noting for any
   future parsing work — `o-0-1`, where a leading zero was read as the
   letter `o`. Two reads of the *same* photo produced different text and a
   different number of recognized medicines (2, then 3). Good enough to
   read alongside the image, nowhere near good enough to act on unchecked —
   which is what the whole verify-then-approve chain exists for. The
   `o-0-1` case is handled correctly (`num.tryParse` fails → the frequency
   is refused with `ambiguous_frequency`, not guessed).
3. **Latin script only.** Devanagari is available in ML Kit but unused;
   running a script model that doesn't match the page produces confident
   nonsense rather than an honest blank.
4. **No medication records exist yet**, so nothing consumes an extraction.
   Modules 06-08 own verification, approval and medications.
5. **The `MlKitOcrEngine` and the four presentation surfaces have no
   automated tests** — same trade as Modules 02-04, covered by the
   live-device run.

### Deferred features

- Associating table cells by geometry (ML Kit exposes `boundingBox`) →
  would materially improve tabular prescriptions, but it is a real piece of
  layout analysis and wants its own module-sized decision
- A remote extraction provider behind `OcrEngine` → only if the no-backend
  constraint is ever lifted
- Re-running extraction on an already-`EXTRACTED` prescription → the state
  machine deliberately forbids it; add an explicit edge when a module needs
  one

---

## Build information

| | |
|---|---|
| Command | `flutter build apk --debug` |
| Artifact | `NURIVA_Module_05_v0.5.0_debug.apk` (Modules 01-04's APKs still present alongside it) |
| Location | `NURIVA/builds/` (gitignored — binaries are never committed) |
| Size | ~235 MB — debug builds bundle every ABI plus debug symbols, and Module 05 adds ML Kit's bundled OCR model (Module 04's was ~172.6 MB) |
| Verified identity | `package: com.nuriva.app`, `versionName 0.5.0`, `versionCode 5`, `application-label: NURIVA`, `minSdk 24`, `targetSdk 36` |
| Signing | Debug keystore — sideload only, **not** Play-ready |
| Build time | 384s cold with ~0.8 GB free RAM; ~70s incremental. ML Kit roughly tripled the cold build over Module 04's 142.7s |

For sideloading, `flutter build apk --release` produces a much smaller artifact (still debug-signed), and `--split-per-abi` cuts it further.

### Environment (verified working)

| Tool | Version | Location |
|---|---|---|
| Flutter / Dart | 3.47.4 / 3.13.3 | `D:\dev\flutter` |
| Android SDK | platforms 35 + 36, build-tools 36.0.0 | `D:\dev\android-sdk` |
| Android NDK | 28.2.13676358 (r28c) | `D:\dev\android-sdk\ndk` |
| cmdline-tools | **classic rev 19.0** at `latest`; new CLI at `23.0` | `D:\dev\android-sdk\cmdline-tools` |
| firebase-tools | 15.30.0 | global npm |
| Java | 21.0.12 LTS | on PATH |

### ⚠ Environment gotchas — do not "fix" these

1. **`cmdline-tools\latest` must stay the CLASSIC rev 19.0.** Gradle shells out to `sdkmanager`; the newer Android CLI shim crashes on exit (`0xC0000409`) and fails the build even though it completes its work. The harmless "SDK XML version 4" warning is the cost of this and should be ignored.
2. **The NDK is required even though NURIVA is pure Dart.** The Flutter Gradle Plugin pins `ndkVersion` and AGP resolves it at configure time. Removing the line from `build.gradle.kts` does not help — the plugin re-adds it.
3. **The Android SDK lives at `D:\dev\android-sdk`, not in the user profile.** It was relocated because a flat-in-profile layout made the SDK manager walk the whole profile and crash on the `AppData\Local\Application Data` junction loop.
4. **Do not pipe long-running Flutter/Gradle commands through PowerShell `Select-Object`** when you need progress — it buffers the whole stream and a working command looks like a hang.
5. **Kotlin's incremental compiler can fail to close its own cache files on Windows.** First hit in Module 02, compiling `firebase_core` (the first plugin in this repo with real Kotlin source) — `compileDebugKotlin` failed with *"Could not close incremental caches ... class-fq-name-to-source.tab"*, reproduced identically after a full `flutter clean`. **Fix in `android/gradle.properties`:** `kotlin.compiler.execution.strategy=in-process` and `kotlin.incremental=false` (forces in-process compilation, avoiding the cross-process file handle that triggers it). Do not remove these lines — the failure is deterministic without them, not a one-off flake.
6. **This machine has only 3.91 GB of RAM — check free memory before running `flutter build`.** First hit in Module 04, adding `flutter_image_compress`/`image_picker`/`path_provider` (native Android libraries; prior modules' dependencies were pure-Dart or thin Firebase wrappers). With several other applications already open, free RAM can sit at ~0.2-0.3 GB, and at that level the build fails — not in Gradle, but in the **Dart compiler itself** (`../../runtime/vm/zone.cc: 95: error: Out of memory.`), before Gradle or per-ABI packaging is even reached. Confirmed across three variants (`--debug` full multi-ABI, `--debug` single-ABI, `--release` single-ABI) — none help, because scoping the build doesn't change how much memory the Dart VM needs just to *start* compiling. There is no code-level fix: check free RAM first (PowerShell: `Get-CimInstance Win32_OperatingSystem | Select-Object FreePhysicalMemory`, divide KB by ~1e6 for GB), and if it's under ~1 GB, say so and ask before burning a build cycle that's going to fail anyway — don't keep retrying with different flags hoping one sticks. **Resolved in practice at ~0.7 GB free** (Module 04's actual successful build) — under 1 GB is a "flag it and ask", not an automatic "it will fail".
7. **The test phone (Realme RMX3612, ColorOS) needs a real data cable and File Transfer/MTP mode, not just "USB debugging" toggled on.** First hit in Module 04's live-device pass: with USB debugging on and the phone unlocked, `adb devices` still showed nothing, and Windows Device Manager showed the phone enumerating in **MIDI mode** (`Get-PnpDevice | Where FriendlyName -match "RMX3612"`) rather than as a composite device with an ADB interface — a ColorOS quirk when the cable or the phone's own USB-mode notification hasn't been set to File Transfer. Separately, a **charge-only USB cable** produced literally zero Windows PnP/USB events on connect (verified via `Get-WinEvent -ProviderName Microsoft-Windows-Kernel-PnP`) — swapping to a real data cable fixed it immediately. If `adb devices` is empty: check the phone's USB-mode notification is set to File Transfer/MTP (not MIDI, not charging-only), and if that doesn't help, suspect the cable before suspecting drivers or ADB config.
8. **`adb shell pm clear <package>` is blocked on this device with a `SecurityException` (missing `CLEAR_APP_USER_DATA`)** — a ColorOS ADB restriction, not fixable from the host side. To reset an app's local state for a clean-slate test, use `adb uninstall <package>` followed by `adb install <apk>` instead; this also flushes Firestore's local offline-mutation queue and any locally cached files, which `pm clear` would have done anyway.

---

## Module roadmap

| # | Module | Version | Status |
|---|---|---|---|
| 01 | Foundation | v0.1.0 | ✅ Complete |
| 02 | Authentication | v0.2.0 | ✅ Complete |
| 03 | Patient & Guardian | v0.3.0 | ✅ Complete |
| 04 | Prescription Upload | v0.4.0 | ✅ Complete |
| 05 | Prescription Reading (on-device OCR) | v0.5.0 | ✅ Complete |
| 06 | Prescription Verification | v0.6.0 | ⬜ |
| 07 | Guardian Approval | v0.7.0 | ⬜ Safety-critical |
| 08 | Medication Management | v0.8.0 | ⬜ |
| 09 | Medication Schedule | v0.9.0 | ⬜ |
| 10 | Medication Reminders | v0.10.0 | ⬜ |
| 11 | Dose Tracking | v0.11.0 | ⬜ |
| 12 | Guardian Alerts | v0.12.0 | ⬜ |
| 13 | Guardian Dashboard | v0.13.0 | ⬜ |
| 14 | Adherence | v0.14.0 | ⬜ |
| 15 | Appointments | v0.15.0 | ⬜ |
| 16 | Prescription History | v0.16.0 | ⬜ |
| 17 | Security | v0.17.0 | ⬜ |
| 18 | MVP Integration | v0.18.0 | ⬜ |

---

## Design system — the rule for every future module

Import one barrel: `import 'package:nuriva/core/design/design.dart';`

Screens **compose** components and read `NurivaTokens`. **No screen defines its own colours, radii, or spacing.**

| Component | Purpose |
|---|---|
| `NurivaButton` | 4 variants × 2 sizes. Self-disables while busy — prevents double-recording a dose |
| `NurivaCard` | Content container; optional status rail and elevation |
| `NurivaStatusChip` | State in colour **and** shape, never colour alone |
| `NurivaTextField` | Persistent labels (floating labels hide context from elderly users) |
| `NurivaStateView` | loading / empty / error, with mandatory explanatory copy |
| `NurivaDialogs` | `confirm` (dismissal = no), `sheet`, `toast` |
| `NurivaListTile`, `NurivaSectionHeader` | List and section structure |
| `NurivaMark`, `NurivaWordmark` | Brand identity, drawn not bundled |

Accessibility invariants: **56dp** minimum touch target, **72dp** hero action, **17px** body text, text scaling honoured to **1.6×** then clamped — because unbounded scaling can push a dose action off screen.

Dose-state colours (`taken`/`due`/`late`/`missed`/`skipped`) are a `ThemeExtension`, deliberately separate from the brand accent so status never competes with branding for meaning. These become load-bearing from Module 10.

---

## Parked work

`docs/parked/mutation_test.xml` — a working mutation-testing config, removed from the active toolchain per spec §5. If it is ever revived, two findings matter:

1. **Never mutate `<` or `>` in Dart** — they are generic brackets, so `Failure<R>` becomes `Failure<=R>`, which does not compile. A compile error exits non-zero, which the tool scores as a "kill", manufacturing hundreds of fake wins. Excluding these cut 498 mutants → 166 meaningful ones.
2. **Never kill a run mid-flight** — mutants are restored only after each test pass, so killing it leaves mutated code written into source.
