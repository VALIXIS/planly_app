# 📝 Planly — Minimalist Task Planner & Focus Assistant

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Database](https://img.shields.io/badge/Storage-Hive%20NoSQL-F89820)](https://pub.dev/packages/hive)
[![Notifications](https://img.shields.io/badge/Alarms-Local%20Notifications-4CAF50)](https://pub.dev/packages/flutter_local_notifications)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Planly** is a distraction-free, privacy-centric task planning and daily productivity mobile application developed in **Flutter**. Engineered to help you organize daily routines, prioritize high-impact goals, and enter deep work sessions without friction, Planly combines local task scheduling, visual calendar tracking, a dedicated Focus Mode, and mindful daily reflection into an elegant, themeable interface.

---

## 🌟 Key Features

### 📋 Intelligent Task & Priority Management
* **Smart Organization**: Create, edit, tag, categorize, and complete tasks with due dates, exact reminder times, and recurring repeat rules (Daily, Weekly, Monthly).
* **Smart Grouping & Dynamic Filters**: Filter instantly by Today, Upcoming, High Priority, Overdue, or custom categories (Work, Personal, Fitness, Study).
* **Bulk Actions**: Batch select tasks to reschedule, reprioritize, or archive with a single gesture.

### 🎯 Deep Work Focus Mode
* **Single-Task Execution**: Minimize cognitive fatigue by eliminating background task clutter and highlighting only your current active priority.
* **Integrated Pomodoro / Work Timer**: Configurable work-rest intervals with subtle audio cues to maintain high mental velocity.

### 📅 Calendar Schedule & Daily Reflection
* **Visual Calendar Grid**: View historical completion streaks and upcoming deadlines across the month.
* **Mindful Daily Reflection**: Built-in prompts to review daily wins, capture evening notes, and set tomorrow's primary intention.

### 🎨 Customization & Theming
* **Fluid Dark & Light Modes**: Seamless system theme synchronization or manual selection.
* **Vibrant Accent Palettes**: Personalize the interface with custom brand accents (Indigo, Emerald, Sunset Orange, Cyber Cyan).
* **Inspirational Quotes**: Dynamic motivational quotes on the home screen and splash banner.

---

## 🏛️ System Architecture

```
lib/
├── features/                # Domain-driven feature modules
│   └── tasks/
│       ├── models/          # Task data entities & Hive adapters
│       │   ├── task_model.dart
│       │   └── task_model.g.dart
│       └── ui/              # Task list, task creation, and detail views
│           ├── focus_mode_screen.dart
│           ├── calendar_view_screen.dart
│           ├── onboarding_screen.dart
│           └── settings_screen.dart
├── services/                # Device and business infrastructure
│   ├── ad_service.dart      # Google Mobile Ads wrapper
│   ├── analytics_service.dart # Local engagement metrics (zero remote telemetry)
│   ├── notification_service.dart # Timed reminders via flutter_local_notifications
│   ├── storage_service.dart # Hive box lifecycle and queries
│   └── task_service.dart    # Task filtering, sorting, and repeat scheduling logic
├── widgets/                 # Reusable cards, date pickers, priority chips
└── main.dart                # App bootstrap & Hive box initialization
```

---

## 🚀 Getting Started

### Prerequisites
* **Flutter SDK**: `^3.10.0` or higher
* **Dart SDK**: `^3.0.0`
* **Android Studio / Xcode**: For device building

### Installation Steps

1. **Clone the Repository**
   ```bash
   git clone https://github.com/smiley-13/planly_app.git
   cd planly_app
   ```

2. **Install Flutter Packages**
   ```bash
   flutter pub get
   ```

3. **Generate Hive Models**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Run the Application**
   ```bash
   # Run in debug mode (uses sample Google ad IDs)
   flutter run

   # Or run with production AdMob identifiers
   flutter run --dart-define=ANDROID_BANNER_AD_UNIT_ID=ca-app-pub-xxx --dart-define=IOS_BANNER_AD_UNIT_ID=ca-app-pub-yyy
   ```

---

## 🧪 Automated Testing

Planly maintains automated unit and widget test coverage:
```bash
# Run test suite
flutter test

# Run static analysis
flutter analyze
```

---

## 🔒 Privacy & Offline Guarantee

* **100% Local Storage**: All tasks, reflection notes, and categories are saved locally on-device inside private Hive NoSQL storage.
* **No Remote Account Required**: Planly functions fully without an internet connection or mandatory account creation.
* **No Third-Party Telemetry**: Planly does not transmit user data, personal notes, or tracking logs to any remote server.

---

## 📄 License

This repository is licensed under the [MIT License](LICENSE).
