# 1 Thing - Android App

A minimalist daily-focus app: **One day. One goal. One thing.**

## Overview
"1 Thing" helps you focus on what matters most. Set one goal each day, track completion, and build a streak.

## Architecture

### Tech Stack
- **Kotlin** with Jetpack Compose
- **Material 3** for UI
- **MVVM** architecture with ViewModel + StateFlow
- **Room** for persistent daily goals
- **Coroutines** for async operations
- **Navigation Compose** for routing

### Project Structure
```
app/src/main/
├── kotlin/com/onething/app/
│   ├── data/
│   │   ├── DailyGoal.kt          (Room entity)
│   │   ├── GoalDao.kt             (Room DAO)
│   │   ├── GoalDatabase.kt        (Room DB)
│   │   └── GoalRepository.kt      (Data layer)
│   ├── ui/
│   │   ├── TodayScreen.kt         (Main UI)
│   │   ├── TodayViewModel.kt      (State management)
│   │   ├── GoalEditDialog.kt      (Dialog composable)
│   │   └── theme/
│   │       ├── Theme.kt           (Material 3 theme)
│   │       ├── Color.kt           (Color palette)
│   │       └── Type.kt            (Typography)
│   └── MainActivity.kt            (Entry point)
├── res/
│   ├── values/
│   │   ├── strings.xml
│   │   └── themes.xml
│   └── xml/
│       ├── backup_rules.xml
│       └── data_extraction_rules.xml
└── AndroidManifest.xml
```

## Features (MVP)

### Today Screen
- **Current Date** - Shows formatted date
- **Streak Counter** - Tracks completed goals
- **Your ONE THING** - Main heading
- **Goal Display** - Shows today's goal or empty state CTA
- **Mark Complete** - Button to complete the goal
- **Edit Goal** - Modify or create new goal
- **Empty State** - "What's your ONE THING?" when no goal set

## Build & Run

### Prerequisites
- Android Studio (latest)
- Kotlin 2.0.20+
- Gradle 8.7.0+
- Min SDK: 26, Target SDK: 35

### Setup
```bash
git clone <repo>
cd feature-sayanlookingtwrdsdstny
./gradlew assembleDebug
```

### Run on Emulator/Device
```bash
./gradlew installDebug
adb shell am start -n com.onething.app/.MainActivity
```

## Data Model

### DailyGoal Entity
```kotlin
@Entity(tableName = "daily_goals")
data class DailyGoal(
    val date: String,           // Primary key (YYYY-MM-DD)
    val goal: String,           // Goal text
    val completed: Boolean,     // Completion state
    val completedAt: Long?      // Timestamp when completed
)
```

## State Management
- **TodayViewModel** uses StateFlow to expose immutable state
- **Repository** handles data operations
- Coroutines for non-blocking DB operations
- LiveData/Flow for reactive updates

## UI/UX
- Clean, minimal Material 3 design
- Calm blue color palette (#2C5DAB primary)
- Dark theme support
- Full-screen, distraction-free layout
- Responsive padding and spacing

## Testing
```bash
./gradlew test           # Unit tests
./gradlew connectedAndroidTest  # Instrumentation tests
```

## Future Enhancements
- Streak counter logic (consecutive completed days)
- Push notifications for reminders
- Goal history/analytics
- Settings screen (themes, reminders)
- Cloud sync (Firebase)

## License
MIT

---
Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
