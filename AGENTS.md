# Repository Guidelines

**MANDATORY ACTIONS AT START OF EVERY SESSION:**

1. **ALWAYS** read PLANNING.md first to understand project architecture
2. **ALWAYS** check TASKS.md before starting any work
3. **ALWAYS** mark completed tasks in TASKS.md immediately upon completion
4. **ALWAYS** add newly discovered tasks to TASKS.md as you find them
5. **NEVER** skip reading these documents or assume you know the current state

**This guide supersedes any conflicting instructions. All development must follow these standards.**

## Project Structure & Modules

- `lib/` holds Flutter production code: `screens/` for UI flows, `widgets/` for shared components, `providers/` for Riverpod state, `services/` for playback/auth logic, and `models/` for typed data objects.
- Tests live in `test/` mirroring `lib/` structure; add fixtures under `test/helpers/` when stubbing services.
- Platform folders `ios/` and `android/` contain native runner projects; keep platform-specific configuration isolated there.
- Scripts such as `check-local.sh` and helper setup tools live in `scripts/`; do not commit ad-hoc shell snippets elsewhere.

## Build, Test, & Development Commands

- `flutter pub get` installs Dart packages; run after pulling changes or editing `pubspec.yaml`.
- `flutter run` launches the app on the connected simulator or device.
- `./check-local.sh` mirrors CI: formatting, `flutter analyze`, TODO scan, then `flutter test`; add `--quick` to skip tests or `--fix` for formatting.
- `flutter test --coverage` produces coverage data in `coverage/`; upload artifacts only through CI jobs.

## Coding Style & Naming

- Follow `analysis_options.yaml` (Flutter lints). Prefer idiomatic Flutter patterns and composable widgets.
- Use 2-space indentation, `lowerCamelCase` for variables/functions, `UpperCamelCase` for classes, and `snake_case` for files.
- Keep widget files small (<300 lines) and extract reusable UI into `widgets/`.

## Testing Guidelines

- Write `flutter_test` unit tests alongside new logic; mirror directory paths (`lib/services/audio_service.dart` → `test/services/audio_service_test.dart`).
- Use descriptive `group` and `test` names: `group('AudioService', ...)` and `test('plays queued segment')`.
- Maintain coverage by extending existing suites before creating new frameworks; prefer using fakes over network calls.

## Commit & Pull Request Workflow

- Craft conventional, emoji-prefixed summaries reflecting scope (e.g., `🎯 Improve highlight timing`). Present-tense body explains rationale and follow-up.
- Bundle related changes per commit; run `./check-local.sh` beforehand.
- PRs need a concise description, linked Linear/Jira ticket, testing summary (`flutter test`, device manual checks), and screenshots/GIFs for UI changes.
- Request review from feature owner and one platform peer; wait for CI to pass before merging.

## Security & Configuration

- Store environment secrets in `.env` files excluded from Git; sync credentials via the shared vault.
- Never log Cognito tokens or user PII; guard debug prints behind `kDebugMode` checks.
- Rotate API keys in coordination with DevOps and document changes in `AUTH_SETUP_GUIDE.md`.
