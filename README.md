# Planly — Minimalist Task Planner & AI Focus Assistant

[![CI/CD Pipeline](https://github.com/VALIXIS/planly_app/actions/workflows/ci.yml/badge.svg)](https://github.com/VALIXIS/planly_app/actions)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Storage](https://img.shields.io/badge/Storage-Hive%20NoSQL-F89820)](https://pub.dev/packages/hive)
[![AI Engine](https://img.shields.io/badge/AI-Gemini%20Flash%20Deconstructor-4285F4?logo=google&logoColor=white)](https://ai.google.dev)
[![Tests](https://img.shields.io/badge/Tests-87%2F87%20Passing-brightgreen)](https://github.com/VALIXIS/planly_app)
[![License: Proprietary](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)

**Planly** is a high-velocity, privacy-centric task planning and Pomodoro focus management suite in the **VALIXIS Enterprise Suite**. Built on Flutter with an OLED-optimized visual architecture, Planly provides AI-powered task deconstruction, local Hive NoSQL persistence, exact alarm scheduling, interactive habit heatmaps, and 3D task card interactions.

---

## Key Capabilities

### AI-Powered Task Deconstruction
* **Gemini Flash Deconstruction**: Converts complex, ambiguous task statements into ordered, actionable subtasks with time estimates.
* **Offline Mock Fallback**: Automatic hermetic fallback when running in offline environments or CI pipelines without API keys.
* **Inline Subtask Engine**: Track progress dynamically with visual percentage bars and subtask checkboxes.

### Focus Mode & Pomodoro Clock
* **Integrated Pomodoro Engine**: 25/5/15 minute interval timers with audio/haptic transitions and ambient state banners.
* **Single-Task Deep Work**: Isolates current high-priority focus targets while dimming background clutter.
* **Habit Heatmap & Completion Velocity**: GitHub-style activity heatmaps tracking daily completions and streak milestones.

### OLED & Fluid Motion UI
* **True OLED Dark Mode**: Power-efficient true-black interface with configurable neon accent highlights.
* **3D Perspective Cards**: Tilt-responsive task cards with spring physics and elevation depth.
* **Alarm Reliability Wizard**: Guides users through OEM battery optimization settings to prevent missed background alarms.

---

## System Architecture

```
+-----------------------------------------------------------------------------+
|                                 PLANLY APP                                  |
|                                                                             |
|  +--------------------+   +-----------------------+   +-------------------+ |
|  | User Interface     |   | State & Action Engine |   | External Services | |
|  | - Home & Calendar  |-->| - AppStateService     |<--| - Gemini Flash AI | |
|  | - Pomodoro Clock   |   | - TaskActionService   |   | - Local Alarms    | |
|  | - Habit Heatmap    |   | - Theme Controller    |   | - AdMob (Optional)| |
|  +--------------------+   +-----------------------+   +-------------------+ |
|            |                          |                         |           |
|            v                          v                         v           |
|  +------------------------------------------------------------------------+ |
|  |                      Hive NoSQL Persistence Layer                      | |
|  |           (Tasks, Subtasks, Habit Logs, Theme Preferences)             | |
|  +------------------------------------------------------------------------+ |
+-----------------------------------------------------------------------------+
```

---

## Directory Structure

```
planly_app/
├── .devcontainer/                  # VS Code & Codespaces hermetic container
├── .github/
│   └── workflows/
│       ├── ci.yml                 # 4-stage GitHub Actions enterprise pipeline
│       └── valixis_midnight_automerge.yml # Midnight automated bot
├── lib/
│   ├── core/                      # OLED themes, colors, and design tokens
│   ├── features/tasks/
│   │   ├── models/                # Task & subtask Hive data models
│   │   └── ui/                    # Calendar, Focus, Onboarding, & Stats views
│   ├── services/                  # AI deconstructor, Alarms, AdMob & Hive
│   └── main.dart                  # Top-level entry point with crash resilience
├── test/
│   ├── add_task_screen_test.dart  # AI deconstructor widget tests
│   ├── pomodoro_focus_test.dart   # Pomodoro countdown timer tests
│   ├── subtask_engine_test.dart   # Subtask calculation and progress tests
│   └── task_card_3d_test.dart     # 3D interactive widget tests
├── Dockerfile                     # Multi-stage hermetic web build
├── docker-compose.yml             # Local evaluation stack
├── nginx.conf                     # Production SPA routing & security headers
├── pubspec.yaml                   # Dependency specification
└── analysis_options.yaml          # Strict linting & static analysis rules
```

---

## Environment Variables

| Variable | Description | Required | Default |
| :--- | :--- | :---: | :--- |
| `GEMINI_API_KEY` | Google Gemini API key for task deconstruction | No | Empty (Mock fallback) |
| `ADMOB_ANDROID_BANNER_ID` | Production Google AdMob Android unit ID | No | Empty |
| `ADMOB_IOS_BANNER_ID` | Production Google AdMob iOS unit ID | No | Empty |
| `PORT` | Container binding port for Nginx web server | No | `80` (mapped to `8087`) |

---

## Quickstart

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.24.0`)
- [Dart SDK](https://dart.dev/get-dart) (`>= 3.5.0`)
- [Docker & Docker Compose](https://www.docker.com/) (optional)

### Clean-Clone Setup & Local Run

```bash
# Clone the repository
git clone https://github.com/VALIXIS/planly_app.git
cd planly_app

# Install dependencies
flutter pub get

# Run on Chrome
flutter run -d chrome

# Run on Android / iOS
flutter run
```

### Running with Docker

```bash
# Build and launch the container
docker compose up -d --build

# Access the application at http://localhost:8087
```

---

## Testing & Coverage

Run the complete hermetic test suite:

```bash
# Run all 87 automated tests
flutter test

# Generate lcov coverage report
flutter test --coverage

# Run static analysis
dart analyze lib
```

All 87 tests execute offline with zero external network or cloud dependencies.

---

## License

Proprietary © VALIXIS. All rights reserved.
