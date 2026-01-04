# Flexify

A lightning-fast, offline-first fitness tracker built with Flutter. Track progressive overload, hit PRs, and visualize your gains—all without an internet connection. **Completely free. No premium tiers. No BS.**

> **Note**: This is a heavily modified fork of [brandonp2412/Flexify](https://github.com/brandonp2412/Flexify). While inspired by the original, this version has been extensively rebuilt with new architecture and features.

## Why Flexify?

- **100% Free Forever**: No ads, no subscriptions, no premium tiers. Every feature unlocked.
- **Offline-First**: Pure SQLite—no internet, no servers, no data mining. Train anywhere.
- **PR Celebrations**: Automatic detection with animated confetti when you hit new maxes.
- **Advanced Analytics**: Training heatmaps, muscle group charts, and progressive overload tracking.
- **Cross-Platform**: Android, iOS, Linux, macOS, Windows—your data follows you everywhere.

## Features

### Workout Management

- **Session Tracking**: Group exercises into complete training sessions with start/end timestamps
- **Active Workout Bar**: Floating indicator shows your current session across all tabs
- **Training Plans & Templates**: Pre-built splits or freeform workouts (Morning/Afternoon/Evening)
- **Exercise Reordering**: Drag-and-drop to reorganize your training on the fly
- **Multi-Select Deletion**: Batch delete old sessions with long-press selection

### Performance Tracking

- **Personal Records**: Tracks best 1RM (Brzycki formula), best volume, and best weight per exercise
- **Custom Celebrations**: Animated notifications with improvement percentages when you break records
- **Progressive Overload Charts**: Visualize strength gains over time with detailed graphs
- **Workout Overview**: Period-based stats (7D, 1M, 3M, 6M, 1Y, All-time)
- **Training Heatmap**: GitHub-style activity calendar showing consistency and adherence
- **Muscle Analytics**: Top 10 muscle groups by volume and set count

### Training Tools

- **5/3/1 Programming**: Built-in support for Wendler's 5/3/1 methodology via exercise notes
- **Hevy Import**: Migrate your entire training history from Hevy seamlessly
- **Custom Rest Timers**: Set per-exercise rest periods with audio and haptic feedback
- **Warmup Sets**: Mark warmup sets separately from working sets for accurate volume tracking
- **Cardio Support**: Track duration, distance, and incline for conditioning work
- **Exercise Notes**: Add training notes, cues, and form reminders during sessions
- **History Toggle**: Switch between workout sessions view and individual sets view

### User Experience

- **Material Design 3**: Clean, modern UI that stays out of your way
- **Real-Time Updates**: Instant UI updates as you log—no lag, no waiting
- **Haptic Feedback**: Satisfying tactile responses when you complete sets
- **Export Ready**: SQLite database for easy backup and migration—your data, your control

## Tech Stack

| Layer            | Technology                  |
| ---------------- | --------------------------- |
| Framework        | Flutter (Dart SDK >= 3.2.6) |
| Database         | Drift 2.28.1 (SQLite ORM)   |
| State Management | Provider 6.1.1              |
| Charts           | fl_chart                    |
| Design           | Material Design 3           |

## Getting Started

### Prerequisites

- Flutter SDK (3.2.6 or higher)
- Dart SDK (included with Flutter)

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/Aquatictw/Flexify flexify
   cd flexify
   ```
2. **Install dependencies**

   ```bash
   flutter pub get
   ```
3. **Generate database code** (if needed)

   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
4. **Run the app**

   ```bash
   flutter run
   ```

### Building for Release

```bash
# Android
flutter build apk

# iOS
flutter build ios

# Desktop (Windows/Linux/macOS)
flutter build windows
flutter build linux
flutter build macos
```

## Architecture Highlights

- **Offline-First**: All data stored locally in SQLite—zero network dependency, train anywhere
- **Session-Based**: Workouts group sets together with start/end timestamps for complete training history
- **Stream-Driven UI**: Real-time updates via Drift's reactive queries—see your progress instantly
- **Provider Pattern**: Global state management for active workouts and timers—seamless UX
- **Migration System**: Schema versioning (currently v50) with step-by-step migrations—data integrity guaranteed

![Screenshot](assets/sakuna.jpg)

## License

Flexify is licensed under the [MIT License](LICENSE.md).

---

**Built for lifters, by lifters.** 100% free. No ads. No subscriptions. No premium features locked behind paywalls. No cloud dependency. Just pure tracking for serious gains.
