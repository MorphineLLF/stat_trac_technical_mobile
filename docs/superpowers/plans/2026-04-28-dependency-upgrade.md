# Dependency Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade all major-version dependencies in Stat_Trac-Technical-app in five sequential groups, each verified clean before the next begins.

**Architecture:** Sequential group approach — pubspec bump → pub get → (build_runner for Riverpod group) → targeted source fixes → flutter analyze gate → commit. No group starts until the previous group's analyze gate passes with zero errors.

**Tech Stack:** Flutter/Dart, Riverpod 3, riverpod_generator 4, build_runner, flutter_secure_storage 10, mobile_scanner 7, local_auth 3, fl_chart 1

---

## Files Modified

| File | Groups |
|---|---|
| `pubspec.yaml` | All groups |
| `lib/features/work_orders/presentation/providers/work_order_providers.dart` | Group 1 |
| `lib/features/auth/presentation/providers/auth_providers.dart` | Group 2 |
| `lib/features/assets/presentation/screens/asset_barcode_scanner_screen.dart` | Group 3 |
| `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | Group 5 |
| `lib/features/auth/presentation/providers/auth_providers.g.dart` | Regenerated in Group 1 |
| `lib/features/work_orders/presentation/providers/work_order_providers.g.dart` | Regenerated in Group 1 |
| `lib/features/dashboard/presentation/providers/dashboard_providers.g.dart` | Regenerated in Group 1 |
| `lib/features/assets/presentation/providers/asset_providers.g.dart` | Regenerated in Group 1 |
| `lib/sync/sync_notifier.g.dart` | Regenerated in Group 1 |

---

## Task 1: Group 1 — Riverpod + offline_sync_kit + package_info_plus

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/features/work_orders/presentation/providers/work_order_providers.dart:47`
- Regenerate: all five `.g.dart` files (via build_runner — do not hand-edit)

- [ ] **Step 1.1: Update pubspec.yaml — Group 1 constraints**

In `pubspec.yaml`, apply these exact changes:

```yaml
# Change these lines under dependencies:
  flutter_riverpod: ^3.3.1       # was ^2.6.1
  riverpod_annotation: ^4.0.2    # was ^2.6.1
  package_info_plus: ^9.0.1      # was ^8.1.3

# Change these lines under dev_dependencies:
  riverpod_generator: ^4.0.3     # was ^2.6.3
  build_runner: ^2.14.1          # was ^2.4.13
```

`offline_sync_kit: ^1.5.3` should already be present from a prior session. Confirm it is listed under `dependencies:`.

- [ ] **Step 1.2: Resolve packages**

Run from `Stat_Trac-Technical-app/`:
```bash
flutter pub get
```

Expected: resolves cleanly with no version-conflict errors.

If `offline_sync_kit` reports a conflict (e.g. it requires `riverpod ^2.x`), stop here. The conflict must be resolved — either pin a compatible `offline_sync_kit` version or remove it temporarily — before continuing.

- [ ] **Step 1.3: Regenerate all Riverpod code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected output ends with something like:
```
[INFO] Succeeded after Xs with N outputs
```

All five `.g.dart` files are rewritten. The deprecated `*Ref` typedef aliases (`AutoDisposeProviderRef<X>`, `AutoDisposeFutureProviderRef<X>`, etc.) disappear from generated code — this is expected.

- [ ] **Step 1.4: Fix self-refresh in work_order_providers.dart**

In `lib/features/work_orders/presentation/providers/work_order_providers.dart`, replace line 47:

Old:
```dart
Future<void> refresh() => ref.refresh(todaysWorkOrdersProvider.future);
```

New (Riverpod 3 AsyncNotifier self-refresh pattern):
```dart
Future<void> refresh() {
  ref.invalidateSelf();
  return ref.future;
}
```

- [ ] **Step 1.5: Verify Group 1 — zero analyzer errors**

```bash
flutter analyze
```

Expected: `No issues found!`

If errors appear, they will be in the generated or source provider files. Fix each reported error before proceeding. Common errors at this step:
- Any remaining use of old `*Ref` typedefs in source code → replace with plain `Ref`
- Any use of `AutoDisposeNotifier` directly in source → now just `Notifier` (but all notifiers in this codebase extend the generated `_$ClassName`, so this is unlikely)

- [ ] **Step 1.6: Commit Group 1**

```bash
git add pubspec.yaml pubspec.lock \
  lib/features/work_orders/presentation/providers/work_order_providers.dart \
  lib/features/auth/presentation/providers/auth_providers.g.dart \
  lib/features/work_orders/presentation/providers/work_order_providers.g.dart \
  lib/features/dashboard/presentation/providers/dashboard_providers.g.dart \
  lib/features/assets/presentation/providers/asset_providers.g.dart \
  lib/sync/sync_notifier.g.dart
git commit -m "chore: upgrade Riverpod 2→3, riverpod_annotation 2→4, package_info_plus 8→9, offline_sync_kit add"
```

---

## Task 2: Group 2 — flutter_secure_storage

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/features/auth/presentation/providers/auth_providers.dart:19–23`

- [ ] **Step 2.1: Update pubspec.yaml — flutter_secure_storage**

In `pubspec.yaml`:
```yaml
  flutter_secure_storage: ^10.0.0    # was ^9.2.2
```

- [ ] **Step 2.2: Resolve packages**

```bash
flutter pub get
```

Expected: resolves cleanly.

- [ ] **Step 2.3: Fix AndroidOptions usage in auth_providers.dart**

In `lib/features/auth/presentation/providers/auth_providers.dart`, replace lines 19–23:

Old:
```dart
@riverpod
FlutterSecureStorage secureStorage(Ref ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
}
```

New (v10 always encrypts on API 23+; app minSdk is 28 so no options needed):
```dart
@riverpod
FlutterSecureStorage secureStorage(Ref ref) {
  return const FlutterSecureStorage();
}
```

- [ ] **Step 2.4: Verify Group 2 — zero analyzer errors**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 2.5: Commit Group 2**

```bash
git add pubspec.yaml pubspec.lock \
  lib/features/auth/presentation/providers/auth_providers.dart
git commit -m "chore: upgrade flutter_secure_storage 9→10, remove obsolete AndroidOptions"
```

---

## Task 3: Group 3 — mobile_scanner

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/features/assets/presentation/screens/asset_barcode_scanner_screen.dart` (if needed)

- [ ] **Step 3.1: Update pubspec.yaml — mobile_scanner**

In `pubspec.yaml`:
```yaml
  mobile_scanner: ^7.2.0    # was ^6.0.2
```

- [ ] **Step 3.2: Resolve packages**

```bash
flutter pub get
```

Expected: resolves cleanly.

- [ ] **Step 3.3: Verify Group 3 — zero analyzer errors**

```bash
flutter analyze
```

If `No issues found!` — proceed directly to Step 3.5 (no source changes needed).

If errors are reported in `asset_barcode_scanner_screen.dart`, fix them per the analyzer output. The only mobile_scanner symbols used in this file are:
- `MobileScanner` widget — `onDetect:` callback parameter name
- `BarcodeCapture` type — callback argument type
- `capture.barcodes.firstOrNull?.rawValue` — barcode data access

Common v7 changes to watch for:
- If `rawValue` is renamed → the analyzer will report `The getter 'rawValue' isn't defined` — replace with the correct property name from the error message
- If `onDetect` callback signature changed → the analyzer will report a type mismatch — update the `_onDetect` method signature to match

- [ ] **Step 3.4: Re-verify after any fixes**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3.5: Commit Group 3**

```bash
git add pubspec.yaml pubspec.lock \
  lib/features/assets/presentation/screens/asset_barcode_scanner_screen.dart
git commit -m "chore: upgrade mobile_scanner 6→7"
```

(If no source file changed, omit `asset_barcode_scanner_screen.dart` from the add.)

---

## Task 4: Group 4 — local_auth

**Files:**
- Modify: `pubspec.yaml` only — no source files import this package

- [ ] **Step 4.1: Update pubspec.yaml — local_auth**

In `pubspec.yaml`:
```yaml
  local_auth: ^3.0.1    # was ^2.3.0
```

- [ ] **Step 4.2: Resolve packages**

```bash
flutter pub get
```

Expected: resolves cleanly.

- [ ] **Step 4.3: Verify Group 4 — zero analyzer errors**

```bash
flutter analyze
```

Expected: `No issues found!` — no source file imports `local_auth` so there are no API callsites to break.

- [ ] **Step 4.4: Commit Group 4**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: upgrade local_auth 2→3"
```

---

## Task 5: Group 5 — fl_chart

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart` (if needed)

- [ ] **Step 5.1: Update pubspec.yaml — fl_chart**

In `pubspec.yaml`:
```yaml
  fl_chart: ^1.2.0    # was ^0.69.0
```

- [ ] **Step 5.2: Resolve packages**

```bash
flutter pub get
```

Expected: resolves cleanly.

- [ ] **Step 5.3: Verify Group 5 — zero analyzer errors**

```bash
flutter analyze
```

If `No issues found!` — proceed directly to Step 5.5.

If errors are reported in `dashboard_screen.dart`, the affected symbols are all in `_StatsCard.build()` (lines ~259–307). The fl_chart 1.x API changes most commonly seen at these callsites:

- `PieChart(PieChartData(...))` — if the `PieChart` constructor changed, the analyzer will indicate the expected signature
- `PieChartSectionData(value:, color:, radius:, title:)` — if any named parameters were renamed, fix per the analyzer output
- `PieChartData(sections:, centerSpaceRadius:, sectionsSpace:)` — same

Fix each error exactly as the analyzer reports it — the error messages will name the correct replacement symbol.

- [ ] **Step 5.4: Re-verify after any fixes**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 5.5: Commit Group 5**

```bash
git add pubspec.yaml pubspec.lock \
  lib/features/dashboard/presentation/screens/dashboard_screen.dart
git commit -m "chore: upgrade fl_chart 0.69→1.2"
```

(If no source file changed, omit `dashboard_screen.dart` from the add.)

---

## Task 6: Final Verification Gate

- [ ] **Step 6.1: Full codebase analyze**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 6.2: Run test suite**

```bash
flutter test
```

Expected: all tests pass. The test suite covers asset model and repository tests. If any test fails, fix the failure before proceeding — do not skip or comment out tests.

- [ ] **Step 6.3: Debug APK build**

```bash
flutter build apk --debug
```

Expected output ends with:
```
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

If the build fails, fix the compile error reported and re-run.

- [ ] **Step 6.4: Final commit (if any fixes were needed in steps 6.1–6.3)**

```bash
git add -p   # stage only the fix files
git commit -m "chore: fix post-upgrade compile issues found in final gate"
```

---

## Rollback Reference

If any group produces unresolvable errors, revert to the last clean commit:

```bash
git checkout -- pubspec.yaml pubspec.lock
flutter pub get
```

Then investigate the specific package changelog before retrying that group.
