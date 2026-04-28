# Dependency Upgrade Design — Major Version Bumps

**Date:** 2026-04-28
**Scope:** Riverpod 2→3 plus five other major-version package upgrades, plus `offline_sync_kit` new addition

---

## Goal

Bring all outdated direct dependencies to their latest resolvable versions, eliminating deprecated API usage and discontinued transitive packages (`js`, `build_resolvers`, `build_runner_core`).

---

## Packages Being Changed

| Package | From | To | Type |
|---|---|---|---|
| `offline_sync_kit` | — | `^1.5.3` | New addition |
| `flutter_riverpod` | `^2.6.1` | `^3.3.1` | Major bump |
| `riverpod_annotation` | `^2.6.1` | `^4.0.2` | Major bump |
| `package_info_plus` | `^8.1.3` | `^9.0.1` | Minor bump (safe) |
| `flutter_secure_storage` | `^9.2.2` | `^10.0.0` | Major bump |
| `mobile_scanner` | `^6.0.2` | `^7.2.0` | Major bump |
| `local_auth` | `^2.3.0` | `^3.0.1` | Major bump (no source changes) |
| `fl_chart` | `^0.69.0` | `^1.2.0` | Major bump |
| `riverpod_generator` *(dev)* | `^2.6.3` | `^4.0.3` | Major bump |
| `build_runner` *(dev)* | `^2.4.13` | `^2.14.1` | Minor bump |

---

## Approach

Sequential groups with a hard `flutter analyze` gate after each one. No group starts until the previous one is clean. This keeps the debugging surface small — if a compile error appears, exactly one package introduced it.

---

## Group 1 — Riverpod + new dep

**Packages:** `offline_sync_kit ^1.5.3`, `flutter_riverpod ^3.3.1`, `riverpod_annotation ^4.0.2`, `package_info_plus ^9.0.1`, `riverpod_generator ^4.0.3` *(dev)*, `build_runner ^2.14.1` *(dev)*

**Steps:**
1. Update `pubspec.yaml` with all Group 1 version constraints.
2. Run `flutter pub get`.
   - If `offline_sync_kit` has a transitive dependency that conflicts with Riverpod 3 (e.g. pins `riverpod ^2.x`), stop and resolve before continuing.
3. Run `dart run build_runner build --delete-conflicting-outputs` to regenerate all five `.g.dart` files.
   - The deprecated `*Ref` typedefs (`AutoDisposeProviderRef<X>`, `AutoDisposeFutureProviderRef<X>`, etc.) are removed from generated code automatically.
   - `AutoDisposeNotifier`/`AutoDisposeAsyncNotifier` aliases in generated code are replaced by the unified Riverpod 3 equivalents.
4. Fix the one known source change:
   - **`lib/features/work_orders/presentation/providers/work_order_providers.dart:47`**
     `ref.refresh(todaysWorkOrdersProvider.future)` → Riverpod 3 self-refresh pattern inside an `AsyncNotifier`:
     ```dart
     Future<void> refresh() {
       ref.invalidateSelf();
       return ref.future;
     }
     ```
5. Run `flutter analyze` — must be zero errors before proceeding.

**Affected source files:**
- `lib/features/auth/presentation/providers/auth_providers.dart`
- `lib/features/work_orders/presentation/providers/work_order_providers.dart` *(source fix at line 47)*
- `lib/features/dashboard/presentation/providers/dashboard_providers.dart`
- `lib/features/assets/presentation/providers/asset_providers.dart`
- `lib/sync/sync_notifier.dart`
- All five corresponding `.g.dart` files (regenerated, not hand-edited)

---

## Group 2 — flutter_secure_storage

**Package:** `flutter_secure_storage ^10.0.0`

**Steps:**
1. Update `pubspec.yaml`.
2. Run `flutter pub get`.
3. Fix breaking change in **`lib/features/auth/presentation/providers/auth_providers.dart:19–23`**:
   - In v10, `AndroidOptions(encryptedSharedPreferences: true)` is removed — encryption is always on for API 23+. Since the app targets `minSdk = 28`, simply remove the `aOptions` argument entirely. The `FlutterSecureStorage()` constructor with no arguments is correct.
4. Run `flutter analyze` — gate before Group 3.

**Affected source files:**
- `lib/features/auth/presentation/providers/auth_providers.dart`

---

## Group 3 — mobile_scanner

**Package:** `mobile_scanner ^7.2.0`

**Steps:**
1. Update `pubspec.yaml`.
2. Run `flutter pub get`.
3. Check **`lib/features/assets/presentation/screens/asset_barcode_scanner_screen.dart`** against the v7 changelog:
   - `MobileScanner(onDetect:)` — verify callback signature is unchanged.
   - `capture.barcodes.firstOrNull?.rawValue` — verify `rawValue` is still the correct property name in v7.
   - Fix any renamed properties.
4. Run `flutter analyze` — gate before Group 4.

**Affected source files:**
- `lib/features/assets/presentation/screens/asset_barcode_scanner_screen.dart`

---

## Group 4 — local_auth

**Package:** `local_auth ^3.0.1`

**Steps:**
1. Update `pubspec.yaml`.
2. Run `flutter pub get`.
3. No source changes required — `local_auth` is declared in `pubspec.yaml` but is not imported anywhere in the codebase.
4. Run `flutter analyze` — gate before Group 5.

**Affected source files:** None.

---

## Group 5 — fl_chart

**Package:** `fl_chart ^1.2.0`

**Steps:**
1. Update `pubspec.yaml`.
2. Run `flutter pub get`.
3. Check **`lib/features/dashboard/presentation/screens/dashboard_screen.dart`** against the fl_chart 1.x changelog:
   - `PieChartData`, `PieChartSectionData`, and related properties were renamed in 1.x. Update any renamed properties.
4. Run `flutter analyze` — gate before final verification.

**Affected source files:**
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

---

## Final Verification Gate

After Group 5 passes `flutter analyze`:

1. `flutter analyze` — confirm zero errors across the full codebase.
2. `flutter test` — confirm no test regressions.
3. `flutter build apk --debug` — confirm the app compiles to a debug APK end-to-end.

---

## Out of Scope

- `dio`, `sqflite`, `path`, `shared_preferences`, `intl`, `cupertino_icons` — all within their current major version, no action needed.
- SQLCipher swap (`openDatabase` → `sqflite_sqlcipher`) — tracked separately in CLAUDE.md TODOs.
- Any feature work — this upgrade touches only `pubspec.yaml`, generated files, and the specific source locations listed above.
