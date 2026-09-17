# NURIVA — Module Status & Session Handoff

> **New session? Read this file first, then `docs/ARCHITECTURE.md`.**
> Do not start development automatically. Wait for an explicit `START MODULE X`.
> Last updated: 2026-09-17

---

## ▶ CURRENT STATE

| | |
|---|---|
| **Current Module** | 02 — Authentication |
| **Module Status** | ✅ Complete |
| **Current Version** | `0.2.0` |
| **Build Number** | `2` (`version: 0.2.0+2`) |
| **Next Module** | 03 — Patient & Guardian |
| **Next Module Status** | ⬜ Not started — waiting for explicit `START MODULE 03` |

Firebase project `nuriva-27e59` is live: Firestore + Storage in `asia-south1`, Email/Password auth enabled, `firestore.rules` deployed. **Storage stays on the Spark (free) plan by the user's choice** — see "Known issues / limitations" below; this has no effect on Module 02 and only matters starting Module 04.

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

1. **Storage stays on the Spark (free) plan by explicit user choice.** Module 02 needs no Storage access, so this has zero effect now. It becomes relevant at **Module 04** (prescription image upload), which needs the Blaze plan (Google requires it for any Storage bucket created after late 2024). Revisit then — Blaze still has a real free tier; it requires linking a billing account, not a subscription charge.
2. **App Check is deferred to Module 17**, not wired now. ARCHITECTURE.md §5 calls for it alongside Firebase Auth, but wiring it without the Firestore/Storage rules and attestation config that go with it would be security theatre rather than real hardening — Module 17 owns all of that together.
3. Sign-out was verified manually on-device rather than via ADB automation — synthetic `input tap` events did not reliably trigger the `IconButton`'s response (likely a splash/hit-test timing issue with instant synthetic taps), and repeated attempts were abandoned in favor of the user confirming manually. Not a product defect.

### Deferred features

- App Check → Module 17
- Storage rules beyond deny-all → Module 04 (needs Blaze plan first)
- Profile editing (`update` on `users/{uid}`) → whichever module first needs it; `firestore.rules` currently denies all updates

---

## Build information

| | |
|---|---|
| Command | `flutter build apk --debug` |
| Artifact | `NURIVA_Module_02_v0.2.0_debug.apk` (Module 01's `NURIVA_Module_01_v0.1.0_debug.apk` still present alongside it) |
| Location | `NURIVA/builds/` (gitignored — binaries are never committed) |
| Size | ~169 MB — debug builds bundle every ABI plus debug symbols |
| Verified identity | `package: com.nuriva.app`, `versionName 0.2.0`, `versionCode 2`, `application-label: NURIVA`, `targetSdk 36` |
| Signing | Debug keystore — sideload only, **not** Play-ready |

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

---

## Module roadmap

| # | Module | Version | Status |
|---|---|---|---|
| 01 | Foundation | v0.1.0 | ✅ Complete |
| 02 | Authentication | v0.2.0 | ✅ Complete |
| 03 | Patient & Guardian | v0.3.0 | ⬜ Waiting for `START MODULE 03` |
| 04 | Prescription Upload | v0.4.0 | ⬜ Needs Blaze plan for Storage |
| 05 | AI/OCR | v0.5.0 | ⬜ Also needs AI provider choice |
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
