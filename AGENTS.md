# SX700 companion

Flutter iOS/Android app (`sx700_remote`) that talks to a Yamaha PSR-SX700 over USB MIDI (`[USB TO HOST]`). GitHub: `Reynold29/sx-companion`.

## Checks

```bash
flutter pub get
flutter analyze
flutter test
```

Do not treat USB TO HOST as a file disk. It is MIDI only.

## Cursor Cloud specific instructions

Cloud VMs are Linux. Use them for Dart analysis, unit/widget tests, and code changes.

- `flutter test` and `flutter analyze` are the verification loop.
- Do not try to build for iOS (`flutter build ios`) or open Xcode. There is no macOS/Xcode here.
- Android APK builds are optional and slow; skip them unless the task is specifically about Android packaging.
- MIDI hardware is not attached. Do not expect live USB device tests to pass in the cloud.
