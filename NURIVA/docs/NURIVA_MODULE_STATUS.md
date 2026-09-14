# NURIVA — Module Status & Session Handoff

> **New session? Read this file first, then `docs/ARCHITECTURE.md`.**
> Do not start development automatically. Wait for an explicit `START MODULE X`.
> Last updated: 2026-09-14

---

## ▶ CURRENT STATE

| | |
|---|---|
| **Current Module** | 01 — Foundation |
| **Module Status** | ✅ Complete |
| **Current Version** | `0.1.0` |
| **Build Number** | `1` (`version: 0.1.0+1`) |
| **Next Module** | 02 — Authentication |
| **Next Module Status** | ⛔ **Blocked** — see "Blockers" below |

**Do not begin Module 02 without resolving the Firebase blocker.**

---

## Blockers

### Firebase is not configured — blocks Module 02

Module 02 is entirely Firebase Auth (login, registration, password reset, session). None of it can be genuinely completed without a Firebase project.

Two things are required, and **only the user can do them**:

1. **Choose the Firestore region.** It is fixed permanently at project creation and depends on jurisdiction:
   - India → `asia-south1` (DPDP Act 2023)
   - EU → `europe-west1` (GDPR: DPA, lawful basis, DSAR tooling)
   - US → `us-central1` (HIPAA; note the **AI provider** also needs a BAA, which many consumer LLM APIs will not sign — this constrains Module 05)
2. **Run `flutterfire configure`** — it needs an interactive Google login.

**Status: user deferred the region decision on 2026-09-14.** Firebase is carried as the single known deferred item.

`bootstrap.dart` has an explicit seam for this: `initializeBackend()` is a documented no-op that logs a warning. It is deliberately not a fake `Firebase.initializeApp()`, which would look configured while talking to nothing.

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

- Firebase initialization + App Check → Module 02
- Launcher icon PNG densities → before external distribution
- Widget/golden tests for reminder screens → Modules 10–11, where layout regressions become a safety issue

---

## Build information

| | |
|---|---|
| Command | `flutter build apk --debug` |
| Artifact | `NURIVA_Module_01_v0.1.0_debug.apk` |
| Location | `NURIVA/builds/` (gitignored — binaries are never committed) |
| Size | **180 MB** — debug builds bundle every ABI plus debug symbols |
| Verified identity | `package: com.nuriva.app`, `versionName 0.1.0`, `versionCode 1`, `application-label: NURIVA`, `targetSdk 36` |
| Signing | Debug keystore — sideload only, **not** Play-ready |

180 MB is awkward to transfer. For sideloading, `flutter build apk --release`
produces ~45 MB (still debug-signed), and `--split-per-abi` cuts it further.

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

---

## Module roadmap

| # | Module | Version | Status |
|---|---|---|---|
| 01 | Foundation | v0.1.0 | ✅ Complete |
| 02 | Authentication | v0.2.0 | ⛔ Blocked on Firebase |
| 03 | Patient & Guardian | v0.3.0 | ⬜ |
| 04 | Prescription Upload | v0.4.0 | ⬜ |
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
