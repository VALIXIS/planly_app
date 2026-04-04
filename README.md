# Planly

Planly is a Flutter task planner with local reminders, a calendar view, focus mode, onboarding, theme customization, and daily reflection.

**Features**
- Create, edit, complete, delete, and bulk-manage tasks
- Set due dates, reminders, priorities, categories, and repeat rules
- View tasks by smart groups, filters, and calendar date
- Use Focus Mode for one-task-at-a-time execution
- Customize dark mode, accent color, splash/home quotes, analytics logs, and personalized ads
- Send feedback through the device email app

**Setup**
1. Install Flutter and a supported Android/iOS toolchain.
2. Run `flutter pub get`.
3. Run `flutter run`.

**Project Structure**
- `lib/main.dart`: app bootstrap and app shell
- `lib/services/`: app state, notifications, analytics, ads, and task actions
- `lib/features/tasks/models/`: Hive task model
- `lib/features/tasks/ui/`: task screens and onboarding/settings flows
- `test/`: widget/unit tests

**Storage And Privacy**
- Tasks and settings are stored locally with Hive.
- Notifications are scheduled locally through `flutter_local_notifications`.
- Analytics is local debug logging only and can be disabled in Settings.
- Google Mobile Ads is used on supported mobile platforms, with a non-personalized ads toggle in Settings.

**Ad Unit IDs**
- Debug/test ads use Google sample ad unit IDs by default.
- For release builds, pass production ad units with `--dart-define=ANDROID_BANNER_AD_UNIT_ID=...` and `--dart-define=IOS_BANNER_AD_UNIT_ID=...`.
