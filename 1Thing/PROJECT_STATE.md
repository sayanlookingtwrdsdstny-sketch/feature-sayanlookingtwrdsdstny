# Project State — "1 Thing" Android App

> **Read this file first in every new session before doing anything else.**
> After finishing meaningful work, update this file (status, % complete, challenges, next step) before ending the session.
> Last updated: 2026-09-10 (unit tests added for `GoalStatsCalculator`; emulator run still blocked — see §5.6)

## 1. What this app is
A minimalist daily-focus Android app ("1 Thing"): one day, one goal, one thing. Deliberately small scope — see "Out of scope" below.
Single Gradle module (`:app`), package `com.onething.app`. Kotlin + Jetpack Compose + Material 3 + Room + MVVM.

## 2. Module / component status

| Component | Path | Status | Notes |
|---|---|---|---|
| `DailyGoal` entity | `data/DailyGoal.kt` | ✅ Done | `id` (PK, autoGenerate), `date` (unique index), `goal`, `completed`, `completedAt`, `createdAt`, `movedToTomorrow` (added 2026-09-10) |
| `GoalDao` | `data/GoalDao.kt` | ✅ Done | `@Upsert`-based, no separate insert/update crash risk |
| `GoalDatabase` | `data/GoalDatabase.kt` | ✅ Done | v3 (bumped 2026-09-10 for `movedToTomorrow`), `fallbackToDestructiveMigration()` (pre-release, no real user data to preserve) |
| `GoalRepository` | `data/GoalRepository.kt` | ✅ Done | today/save/complete/moveToTomorrow/deleteGoal/history/stats/reset |
| `GoalStats` / `GoalStatsCalculator` | `data/GoalStats.kt` | ✅ Done | Pure function: current streak, longest streak, total completed, completion % |
| `UserPreferencesRepository` | `data/UserPreferencesRepository.kt` | ✅ Done | DataStore: reminder enabled/time, theme mode |
| Today screen + VM | `ui/TodayScreen.kt`, `ui/TodayViewModel.kt` | ✅ Done | Duplicate-completion guard, subtle completion animation, "Move to tomorrow" action, delete action (2026-09-10) |
| History screen + VM | `ui/HistoryScreen.kt`, `ui/HistoryViewModel.kt` | ✅ Done | Clean list, `Sep 6 — Goal ✓/✕/→`; per-row delete added 2026-09-10 |
| Stats screen + VM | `ui/StatsScreen.kt`, `ui/StatsViewModel.kt` | ✅ Done | 4 tiles, no charts |
| Settings screen + VM | `ui/SettingsScreen.kt`, `ui/SettingsViewModel.kt` | ✅ Done | Reminder toggle+time, theme radio group, reset-all-data w/ confirm; toggle now synced live to OS notification permission (2026-09-10) |
| Reminder system | `reminder/` (NotificationHelper, ReminderScheduler, ReminderReceiver, BootReceiver) | ✅ Done | AlarmManager self-rescheduling alarm, POST_NOTIFICATIONS runtime request, reboot-safe |
| Navigation | `ui/AppNavigation.kt` | ✅ Done | Bottom nav: Today/History/Stats only. Settings behind top-right gear icon (per spec) |
| String resources | `res/values/strings.xml` | ✅ Done | All UI copy extracted; no hardcoded literals in composables |
| Theme/design pass | `ui/theme/*` | ✅ Done | Dynamic color **disabled** (one deliberate accent, not per-device Material You); custom `Shapes` (16–28dp rounding); centered/seamless top bar; tightened headline tracking |
| Move-to-tomorrow semantics | — | ✅ Done | Explicit user action only; day never auto-carries or auto-completes |
| Unit / instrumentation tests | `app/src/test`, `app/src/androidTest` | 🔶 Started | `GoalStatsCalculatorTest` (10 cases: empty input, blank-goal exclusion, rounding, streak edge cases, duplicate dates, unparseable dates) added and passing via `./gradlew testDebugUnitTest`. Repository/DAO/ViewModel/instrumentation tests still not started |
| CI | — | ❓ Not set up | Manual `./gradlew` checks only so far |

## 3. Out of scope (explicit, per product decision)
No accounts, backend, Firebase/cloud sync, social features, AI, subscriptions, ads, multiple tasks/day, calendar integration, complex analytics, habit tracking, full task management, or onboarding flow. Keep it small.

## 4. Overall progress
- **MVP (all 6 numbered feature areas — Today, Completion, History, Stats, Settings, Notifications — plus data model, navigation restructure, string extraction, and a design pass): fully implemented and build-verified.**
- Verified via `./gradlew compileDebugKotlin` and `./gradlew assembleDebug` — both green, `app-debug.apk` builds successfully.
- **Not yet done:** the rest of the automated tests (repository/DAO/ViewModel, instrumentation), running on an actual device/emulator to eyeball the UI, and a Play-Store-readiness pass (icons, versioning, ProGuard/R8 rules for release).

## 5. Known notes / decisions worth knowing about

### 5.5 2026-09-10 bug report — status
User reported four bugs. Three fixed and build-verified (`compileDebugKotlin` + `assembleDebug` both green); one still open pending more info:

1. **Reminder toggle out of sync with system notification permission — ✅ Fixed.** `SettingsScreen` now rechecks `NotificationManagerCompat.areNotificationsEnabled()` on every `ON_RESUME` (via a `DisposableEffect`/`LifecycleEventObserver`) and after the permission-request callback. The switch's displayed state is `preferences.reminder.enabled && systemNotificationsEnabled`, and if the two disagree (app-level pref is on but the OS has notifications blocked) a warning + "Open notification settings" button appears. DB/DataStore truth (`preferences.reminder.enabled`) is unchanged — only what's displayed/actionable in the UI now reflects OS reality too.
2. **History and Settings pages "showing as same" — ❓ Not reproduced, unresolved.** Read through `AppNavigation.kt`, `HistoryScreen.kt`, `SettingsScreen.kt`, `StatsScreen.kt`, `AppViewModelFactory.kt` — routes, composables, and ViewModel wiring are all distinct and correctly wired; no code-level cause found for the two screens rendering identical content. User confirmed it's "literally identical content," not just a style/visual-similarity complaint, but couldn't say more without a screenshot. Per PROJECT_STATE §2/§4, the app has never actually been run on a device/emulator yet — first real device run may well surface the real cause (or turn out to be a stale/old APK install). **Next step: run on an emulator (see §6), reproduce, and if it still repros, get a screenshot of both screens + the exact repro steps (cold start? after backgrounding? after a specific nav sequence?).**
3. **No way to delete a goal — ✅ Fixed.** Added delete (with confirm dialog) in two places: Today screen (delete today's/current goal) and each History row (a trash-can `IconButton` per entry, with the same confirm dialog). Wired through `GoalRepository.deleteGoal()` → `GoalDao.deleteGoalForDate()`.
4. **Moving a goal to tomorrow makes it vanish from History — ✅ Fixed.** Root cause: `GoalRepository.moveGoalToTomorrow()` deleted today's DB row outright after copying its text to tomorrow, so that day's entry disappeared from History entirely instead of being recorded as "moved." Fix: added `DailyGoal.movedToTomorrow: Boolean` (DB bumped v2→v3, still `fallbackToDestructiveMigration()`); the original day's row is now kept (marked `movedToTomorrow = true`) instead of deleted. History shows a "→" status for moved entries instead of ✓/✕. Today screen shows the persisted "Moved to tomorrow." message for the rest of that day (replacing the old transient/animation-only `justMovedToTomorrow` flag, which was itself silently broken by the delete — it could never actually display because the goal object it depended on had already been nulled out). Editing a moved goal's text (via Edit, still available) clears `movedToTomorrow` and makes it active again.
1. **Local dev environment quirk (fixed):** `local.properties` had a UTF-8 BOM that broke `sdk.dir` parsing, and the original `sdk.dir` value used backslash-escaped syntax that Gradle mis-parsed on this machine. Rewritten with forward slashes and no BOM — if this file gets regenerated by Android Studio and builds start failing with "SDK location not found", check for the BOM/escaping issue again.
   **Updated 2026-09-14:** the Android SDK was moved off the user profile (it had been installed flat into `C:\Users\Sayan`, which broke the SDK manager) to **`D:\dev\android-sdk`**. `local.properties` is now `sdk.dir=D:/dev/android-sdk`, and `compileDebugKotlin` was re-verified green after the move. A harmless "SDK XML version 4" warning now appears because the command-line tools are newer than this project's AGP — it does not affect the build.
2. **Editing an existing goal used to crash** (plain `@Insert` on a table where `date` was the primary key → conflict). Fixed via `@Upsert` + id-preserving fetch-then-copy in `GoalRepository.saveGoal`. Worth knowing if you see old crash reports referencing this.
3. **DB migration strategy is destructive** (`fallbackToDestructiveMigration()`), intentionally, since there's no real user data yet. Before any real release, replace with a proper `Migration(1, 2)` (or whatever the from-version is at that point) so existing users don't lose their history.
4. **Dynamic color is off by default** in `OneThingAppTheme` — deliberate, to keep one consistent brand accent instead of adapting to the device wallpaper (Material You). Don't re-enable it without discussing — it was an explicit design decision, not an oversight.

### 5.6 2026-09-10 — emulator/device run still blocked
Attempted to act on §6's #1 next step (run on emulator to verify design pass and reproduce the History/Settings bug from §5.5.2). Found the dev machine's SDK at `C:\Users\Sayan` has `platform-tools\adb.exe` but **no `emulator.exe` binary**, and no physical device is connected (`adb devices` returns empty). There's a leftover `.android\avd\android-35` folder but it's an empty/incomplete AVD, not a bootable one. User chose to defer the emulator run and do unit tests instead this session (see the `GoalStatsCalculator` row in §2). **Before the emulator run can happen:** either install the Android Studio "Android Emulator" + a system image via `sdkmanager` (untested whether it can render headlessly in this environment — may need a real display/hypervisor), or connect a physical device via USB debugging and re-run `adb devices` to confirm it's picked up.

## 6. Suggested next step
1. **Run the app on an emulator/device** — still blocked in this dev environment (see §5.6); needs either an emulator system image installed or a physical device connected via USB debugging. Needed both to visually verify the design pass (spacing, dark mode, touch targets — still never rendered/screenshotted) and to actually reproduce/diagnose bug #2 from §5.5 (History vs. Settings "showing as same"), which couldn't be confirmed by code review alone.
2. Expand automated tests beyond `GoalStatsCalculator` — repository (`GoalRepository`, especially `moveGoalToTomorrow`/delete semantics) and DAO tests are next highest value, using an in-memory Room DB.
3. Ask the user whether/when to harden the DB migration before any real release.

## 7. How to keep this file useful
- Whenever a module/file moves status, or a new module is added, update the table in section 2.
- Update section 4's progress and section 6's "next step" after each work session — don't let this go stale like it did before this update.
