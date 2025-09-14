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

## Development Workflow

### Pre-commit Hooks

Our project uses automated pre-commit hooks to ensure code quality. These hooks run automatically before each commit to catch issues early.

#### Initial Setup (one-time)

```bash
# Run the setup script to install hooks
./scripts/setup-hooks.sh
```

#### What Gets Checked

1. **Flutter analyze** - Blocks commit if errors are found
2. **Code formatting** - Ensures consistent code style
3. **Unit tests** - Verifies all tests pass
4. **TODO comments** - Warns about remaining TODOs (non-blocking)

#### Manual Checks

Run all CI checks locally before pushing:

```bash
# Full check (mirrors CI pipeline)
./check-local.sh

# Quick check (skips tests for speed)
./check-local.sh --quick

# Auto-fix formatting issues
./check-local.sh --fix
```

#### Bypassing Hooks (Emergency Only)

In rare cases where you need to commit despite failures:

```bash
# Skip all pre-commit hooks
git commit --no-verify -m "Emergency fix: [description]"

# Skip tests only
SKIP_TESTS=1 git commit -m "Your message"
```

⚠️ **Warning**: Bypassing checks may cause CI pipeline failures. Use sparingly.

### VS Code Setup

For the best development experience, VS Code will automatically:
- Format code on save
- Show linting errors inline
- Organize imports automatically
- Provide Flutter-specific features

Install recommended extensions:
1. Open VS Code in the project directory
2. Go to Extensions view (⌘+Shift+X / Ctrl+Shift+X)
3. Search for "@recommended"
4. Install all recommended extensions

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