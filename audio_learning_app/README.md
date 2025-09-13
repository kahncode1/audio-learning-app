# Audio Learning Platform

A Flutter-based mobile application that streams narrated audio of educational content with synchronized dual-level word and sentence highlighting for insurance professionals.

## Features

- 🎧 Professional text-to-speech audio streaming
- 📖 Dual-level synchronized highlighting (sentence + word)
- 📱 Cross-platform (iOS and Android)
- 🔐 Enterprise SSO authentication via AWS Cognito
- 💾 Progress tracking and user preferences
- ⚡ High-performance 60fps highlighting
- 🎮 Advanced playback controls with keyboard shortcuts

## Prerequisites

- Flutter SDK 3.x or higher
- Dart SDK 3.x or higher
- iOS development: Xcode 14+, macOS
- Android development: Android Studio, Android SDK

## Setup

1. Clone the repository
2. Copy `.env.example` to `.env` and fill in your API keys
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart           # App entry point
├── models/             # Data models
├── providers/          # Riverpod state management
├── screens/            # UI screens
├── services/           # Business logic
└── widgets/            # Reusable components
```

## Testing

```bash
# Run unit tests
flutter test

# Run integration tests
patrol test

# Generate coverage report
flutter test --coverage
```

## Documentation

See the parent directory for comprehensive documentation:
- `CLAUDE.md` - Development guide
- `PLANNING.md` - Technical architecture
- `TASKS.md` - Development tasks
- `/documentation/` - API and integration guides
- `/implementations/` - Reference implementations