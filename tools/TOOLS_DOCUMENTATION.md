# HCM Implementation Kit — Tools Documentation

> **Starting point:** [`run_all_scripts.dart`](#1-run_all_scriptsdart) orchestrates the full setup pipeline by sequentially executing the four core scripts described below.

---

## Table of Contents

1. [run\_all\_scripts.dart](#1-run_all_scriptsdart) ← _Start here_
2. [script\_tracker.dart](#2-script_trackerdart)
3. [create\_env\_overrides.dart](#3-create_env_overridesdart)
4. [remove\_language\_selection.dart](#4-remove_language_selectiondart)
5. [init\_implementation.sh](#5-init_implementationsh)
6. [run\_initial\_setup\_commands.dart](#6-run_initial_setup_commandsdart)
7. [install\_bricks.sh](#7-install_brickssh)
8. [import\_packages.sh](#8-import_packagessh)
9. [Module Package Import Scripts](#9-module-package-import-scripts)
   - [attendance\_package\_imports.dart](#attendance_package_importsdart)
   - [checklist\_package\_imports.dart](#checklist_package_importsdart)
   - [closed\_household\_package\_imports.dart](#closed_household_package_importsdart)
   - [complaints\_package.dart](#complaints_packagedart)
   - [digit\_data\_model\_imports.dart](#digit_data_model_importsdart)
   - [digit\_dss\_imports.dart](#digit_dss_importsdart)
   - [digit\_scanner\_imports.dart](#digit_scanner_importsdart)
   - [inventory\_package\_imports.dart](#inventory_package_importsdart)
   - [referral\_reconciliation\_imports.dart](#referral_reconciliation_importsdart)
   - [registration\_delivery\_imports.dart](#registration_delivery_importsdart)
10. [Utility Scripts](#10-utility-scripts)
    - [clean\_build.sh](#clean_buildsh)
    - [run\_build\_runner.sh](#run_build_runnersh)
    - [get\_dependencies.sh](#get_dependenciessh)
    - [generate-apk.sh](#generate-apksh)
    - [combine\_coverage.sh](#combine_coveragesh)
    - [localization\_json\_convertor.ts](#localization_json_convertorts)

---

## Setup Pipeline Overview

```
run_all_scripts.dart
│
├─── 1. create_env_overrides.dart      → Creates .env, .env-qa, .env-prod, pubspec_overrides.yaml
├─── 2. remove_language_selection.dart → Patches app_router.dart (skips language screen)
├─── 3. init_implementation.sh         → Interactive module wizard + mason code gen + melos bootstrap
└─── 4. run_initial_setup_commands.dart
         ├── install_bricks.sh         → Activates mason, adds bricks, generates entity models
         ├── flutter pub get
         ├── flutter clean
         └── flutter pub run build_runner build
```

---

## 1. `run_all_scripts.dart`

**Type:** Dart script  
**Run:** `dart tools/run_all_scripts.dart` (from repo root)

### Purpose
The **entry point** for the full project setup. Sequentially runs the four setup tasks below, stopping immediately on any failure (`exit(exitCode)`).

### Tasks Executed (in order)

| # | Task Name | Script |
|---|-----------|--------|
| 1 | Create Environment Files | `tools/create_env_overrides.dart` |
| 2 | Update App Router | `tools/remove_language_selection.dart` |
| 3 | Packages setup | `tools/init_implementation.sh` |
| 4 | Health App Setup | `tools/run_initial_setup_commands.dart` |

### How It Works
- Defines a `ScriptTask` class with a `name` and `path`.
- `runScript()` detects the file type (`.dart` → `dart <path>`, `.sh` → `bash <path>`).
- Runs each script with `ProcessStartMode.inheritStdio` so interactive prompts pass through to the terminal.
- Prints ✅ SUCCESS or ❌ FAILED per task.

---

## 2. `script_tracker.dart`

**Type:** Dart library (not run directly)  
**Used by:** Other scripts that need idempotency.

### Purpose
Provides a `ScriptTracker` utility class to persist and check whether a named script has already been executed, preventing duplicate runs across sessions.

### Storage
State is stored as JSON in `.dart_tool/scripts_state.json` (git-ignored by default).

### API

| Method | Description |
|--------|-------------|
| `ScriptTracker.hasRun(String scriptName)` | Returns `true` if the script has already run |
| `ScriptTracker.markAsRun(String scriptName)` | Records the script as completed |

### Usage Example
```dart
if (await ScriptTracker.hasRun('my_script')) {
  print('Already ran, skipping.');
  return;
}
// ... do work ...
await ScriptTracker.markAsRun('my_script');
```

---

## 3. `create_env_overrides.dart`

**Type:** Dart script  
**Run:** `dart tools/create_env_overrides.dart`

### Purpose
Bootstraps environment configuration for the `health_campaign_field_worker_app` by creating four files. **Skips any file that already exists** (safe to re-run).

### Files Created

| File | Location | Description |
|------|----------|-------------|
| `.env` | `apps/health_campaign_field_worker_app/` | DEV environment variables |
| `.env-qa` | `apps/health_campaign_field_worker_app/` | QA environment variables |
| `.env-prod` | `apps/health_campaign_field_worker_app/` | Production environment variables |
| `pubspec_overrides.yaml` | `apps/health_campaign_field_worker_app/` | Stub for local dependency overrides |

### Environment Variables Set (all envs)

| Variable | Purpose |
|----------|---------|
| `BASE_URL` | Backend API base URL |
| `MDMS_API_PATH` | MDMS v2 search endpoint path |
| `TENANT_ID` | Tenant identifier (default: `ng`) |
| `ACTIONS_API_PATH` | Actions MDMS endpoint path |
| `SYNC_DOWN_RETRY_COUNT` | Retry attempts for sync-down |
| `RETRY_TIME_INTERVAL` | Delay between retries (seconds) |
| `CONNECT_TIMEOUT` / `RECEIVE_TIMEOUT` / `SEND_TIMEOUT` | HTTP timeouts (ms) |
| `CHECK_BANDWIDTH_API` | Bandwidth check endpoint |
| `HIERARCHY_TYPE` | Admin hierarchy type |
| `ENV_NAME` | Human-readable env label (DEV / QA / PROD) |

> ⚠️ Do **not** commit `.env` files or `pubspec_overrides.yaml` to version control.

---

## 4. `remove_language_selection.dart`

**Type:** Dart script  
**Run:** `dart tools/remove_language_selection.dart`

### Purpose
Patches `apps/health_campaign_field_worker_app/lib/router/app_router.dart` to **skip the language selection screen** on first launch and route directly to Login.

### Changes Made

| Change | Detail |
|--------|--------|
| Comment out `LanguageSelectionRoute` | Wraps the entire `AutoRoute(page: LanguageSelectionRoute.page, ...)` block in `//` comments |
| Make `LoginRoute` the initial route | Inserts `initial: true` into the `LoginRoute` `AutoRoute` definition |

### Safety
- Only modifies the file if the patterns are found.
- Prints a warning if either route is not found (does not crash).

---

## 5. `init_implementation.sh`

**Type:** Bash script (interactive)  
**Run:** `bash tools/init_implementation.sh`

### Purpose
An **interactive TUI wizard** that guides a developer through selecting and setting up a campaign module for the Health Campaign Field Worker App.

### Interactive Steps

1. **Select Module Type** — presents a numbered menu:

   | # | Module Type |
   |---|-------------|
   | 1 | Registration Module |
   | 2 | Service Delivery Module |
   | 3 | Attendance Module |
   | 4 | Inventory Management Module |
   | 5 | Survey / Checklist Module |
   | 6 | Complaint Management Module |
   | 7 | Dashboard Module |
   | 8 | Closed Household Module |

2. **Additional Packages** — optionally add extra Flutter packages one by one; each is installed immediately via `import_packages.sh --main-app <package>`.

3. **Confirmation** — shows a summary and asks to confirm before proceeding.

### Module-Specific Actions
- **Dashboard** → runs `dart digit_dss_imports.dart`
- **Closed Household** → runs `dart closed_household_package_imports.dart`
- All other modules → logged with placeholder for future automation (directory creation, routing, localization)

### Options

| Flag | Description |
|------|-------------|
| `-h`, `--help` | Show usage |
| `-i`, `--interactive` | Run in interactive mode (default) |

---

## 6. `run_initial_setup_commands.dart`

**Type:** Dart script  
**Run:** `dart tools/run_initial_setup_commands.dart`

### Purpose
Performs the **post-code-gen Flutter setup** for the health app. Runs four commands sequentially using the current working directory as the repo root.

### Steps Executed (in order)

| Step | Command | Directory |
|------|---------|-----------|
| 1 | `bash install_bricks.sh` | `tools/` |
| 2 | `flutter pub get` | `apps/health_campaign_field_worker_app/` |
| 3 | `flutter clean` | `apps/health_campaign_field_worker_app/` |
| 4 | `flutter packages pub run build_runner build --delete-conflicting-outputs` | `tools/` |

### Notes
- Cross-platform: uses `cmd.exe /c` on Windows and `bash -c` on Unix/macOS.
- Exits with the failing command's exit code on any error.

---

## 7. `install_bricks.sh`

**Type:** Bash script  
**Run:** `bash tools/install_bricks.sh` (or invoked automatically by `run_initial_setup_commands.dart`)

### Purpose
Bootstraps Mason brick tooling and generates Dart entity models from JSON config files.

### Steps Executed (in order)

1. Activates `mason_cli` globally: `dart pub global activate mason_cli`
2. Activates `melos` globally: `dart pub global activate melos`
3. Runs `melos run generate-hooks` (compiles Mason hook dependencies)
4. Adds `digit_entity` brick from `./mason_templates/digit_entity` globally
5. Adds `freezed_bloc` brick from `./mason_templates/freezed_bloc` globally
6. Iterates over every `*.json` file inside `apps/health_campaign_field_worker_app/lib/models/model_configs/` and runs `mason make digit_entity` on each, outputting generated code into the app `lib/` directory
7. Runs `melos clean` then `melos bootstrap` from repo root

---

## 8. `import_packages.sh`

**Type:** Bash script  
**Run:** `bash tools/import_packages.sh [options] package1 package2 ...`

### Purpose
A general-purpose Flutter package installer with smart conflict resolution. Validates package names, checks pub.dev availability, and falls back to `pubspec_overrides.yaml` on version conflicts.

### Options

| Flag | Description |
|------|-------------|
| `-d`, `--dev` | Add as dev dependency |
| `-p PATH`, `--path PATH` | Custom path to `pubspec.yaml` |
| `-v VER`, `--version VER` | Pin specific version for all packages |
| `-g URL`, `--git URL` | Add from a Git repository URL |
| `-r REF`, `--ref REF` | Git branch/tag/commit reference |
| `--workspace` | Install in all Melos workspace packages |
| `--main-app` | Install only in `apps/health_campaign_field_worker_app` |
| `--dry-run` | Preview actions without making changes |
| `--force-override` | Force write into `pubspec_overrides.yaml` |
| `--list-packages FILE` | Read package names from a file (one per line, `#` comments supported) |
| `-h`, `--help` | Show help |

### Conflict Resolution
When `flutter pub add` fails due to a version conflict, the script automatically:
1. Adds the package to `pubspec_overrides.yaml`
2. Runs `flutter pub get` to verify the override resolves the conflict
3. Rolls back the override entry if it still fails

### FVM Support
Automatically uses `fvm flutter` instead of `flutter` if an `.fvm` folder is detected in the project or workspace root.

### Examples
```bash
bash tools/import_packages.sh http dio
bash tools/import_packages.sh --main-app flutter_bloc
bash tools/import_packages.sh --dev build_runner json_annotation
bash tools/import_packages.sh --dry-run --workspace provider
bash tools/import_packages.sh -v "^3.0.0" shared_preferences
bash tools/import_packages.sh --force-override conflicting_pkg
bash tools/import_packages.sh --list-packages my_packages.txt
```

---

## 9. Module Package Import Scripts

All module import scripts follow the **same pattern**:
- Run from the **repo root** (or `tools/` directory, depending on the script).
- Read source files from `apps/health_campaign_field_worker_app/lib/`.
- Inject imports, singletons, BLoC providers, router registrations, entity mapper cases, localization delegates, and repository providers.
- Use **idempotent insertions** — each insertion checks for existing content before writing.
- Format modified files with `dart format` at the end.

### Common Files Modified by Module Scripts

| File | What Gets Added |
|------|----------------|
| `pages/home.dart` | Import, singleton init, local/remote repo reads, home item card, showcase key, items label |
| `router/app_router.dart` | Module route import + `AutoRoute` registration |
| `data/local_store/no_sql/schema/entity_mapper.dart` | New `case` entries for module entity types |
| `data/repositories/sync/sync_down.dart` or `sync_up.dart` | New `case DataModelType.X` sync logic |
| `widgets/network_manager_provider_wrapper.dart` | Local + remote `RepositoryProvider` entries |
| `utils/localization_delegates.dart` | Module localization import + delegate call |
| `utils/constants.dart` | Module singleton configuration |
| `utils/utils.dart` | Mapper initializer registration |
| `app.dart` | BLoC providers, service definition repo wiring |

---

### `attendance_package_imports.dart`

**Package:** `attendance_management`  
**Run:** `dart tools/attendance_package_imports.dart` (from repo root)

Integrates the **Attendance Management** module. Adds:
- `ManageAttendanceRoute` to the router
- `AttendanceSingleton` initialization
- `AttendanceLogModel` sync-down case
- Attendance entity mapper cases
- Attendance localization delegate
- Attendance repo providers in network manager wrapper
- Attendance constants and mapper registrations

---

### `checklist_package_imports.dart`

**Package:** `checklist`  
**Run:** `dart tools/checklist_package_imports.dart` (from `tools/` directory)

Integrates the **Survey / Checklist** module. Adds:
- `ServiceDefinitionModel` and `ServiceModel` repository wiring in `app.dart`
- `ChecklistSingleton().setBoundary(...)` in `context_utility.dart`
- `ServiceBloc` provider in `authenticated.dart`
- Checklist router and home item
- Entity mapper, localization delegate, repo providers
- Constants and mapper registrations

---

### `closed_household_package_imports.dart`

**Package:** `closed_household`  
**Run:** `dart tools/closed_household_package_imports.dart` (from repo root)

A **minimal script** that only updates:
- `utils/localization_delegates.dart` — adds the `ClosedHouseholdLocalization` delegate

Runs `dart format` on the localization file after modification.

---

### `complaints_package.dart`

**Package:** `complaints`  
**Run:** `dart tools/complaints_package.dart` (from repo root)

Integrates the **Complaint Management** module. Adds:
- `ComplaintsInboxWrapperRoute` to the router and home screen
- `ComplaintsSingleton` initialization with tenant, user, and complaint-type config
- `PgrServiceModel` sync-up case
- PGR entity mapper cases
- Complaints localization delegate
- PGR repo providers
- Boundary wiring in `context_utility.dart` and `extensions.dart`
- Constants and mapper registrations

---

### `digit_data_model_imports.dart`

**Package:** `digit_data_model`  
**Run:** `dart tools/digit_data_model_imports.dart` (from repo root)

Registers the **core data model layer** shared by all modules. Adds:
- Base repository providers for: `IndividualModel`, `FacilityModel`, `ProjectModel`, `ProjectStaffModel`, `ProjectFacilityModel`, `ServiceDefinitionModel`, `ServiceModel`, `ProjectResourceModel`, `ProductVariantModel`, `BoundaryModel`, `PgrServiceModel`
- Remote repository providers for all the above plus `UserModel`, `ProductModel`
- `DigitDataModelSingleton` configuration in `constants.dart`
- `digit_data_model` mapper initializer in `utils.dart`

> ℹ️ This script imports helpers from `attendance_package_imports.dart`.

---

### `digit_dss_imports.dart`

**Package:** `digit_dss`  
**Run:** `dart tools/digit_dss_imports.dart` (from repo root)

Integrates the **Dashboard (DSS)** module. Adds:
- `DashboardBloc` provider in `app.dart`
- `UserDashboardRoute` to the router and home screen
- `DashboardSingleton` initialization with project, tenant, and app version config
- DSS localization delegate
- DSS constants and mapper registrations

---

### `digit_scanner_imports.dart`

**Package:** `digit_scanner`  
**Run:** `dart tools/digit_scanner_imports.dart` (from repo root)

A **minimal script** that only updates:
- `utils/localization_delegates.dart` — adds the `ScannerLocalization` delegate

Runs `dart format` on the localization file after modification.

> ℹ️ The `DigitScannerBloc` registration into `app.dart` is handled by other module scripts (e.g., `inventory_package_imports.dart`, `registration_delivery_imports.dart`) that depend on the scanner.

---

### `inventory_package_imports.dart`

**Package:** `inventory_management`  
**Run:** `dart tools/inventory_package_imports.dart` (from repo root)

Integrates the **Inventory Management** module. Adds:
- `DigitScannerBloc` in `app.dart` (scanner dependency)
- `InventorySingleton().setBoundaryName(...)` in `context_utility.dart`
- `ManageStocksRoute`, `StockReconciliationRoute`, `InventoryReportSelectionRoute` to the router and home screen
- Inventory sync-down cases for stock and stock reconciliation entity types
- Inventory entity mapper cases
- Inventory localization delegate
- Inventory repo providers
- Inventory constants and mapper registrations

---

### `referral_reconciliation_imports.dart`

**Package:** `referral_reconciliation`  
**Run:** `dart tools/referral_reconciliation_imports.dart` (from repo root)

Integrates the **Referral Reconciliation** module. Adds:
- `DigitScannerBloc` in `app.dart` (scanner dependency)
- `ReferralReconSingleton().setBoundary(...)` in `context_utility.dart`
- `SearchReferralReconciliationsRoute` to the router and home screen
- Referral sync-down cases
- Referral entity mapper cases
- Referral localization delegate
- Referral repo providers
- Referral constants and mapper registrations

---

### `registration_delivery_imports.dart`

**Package:** `registration_delivery`  
**Run:** `dart tools/registration_delivery_imports.dart` (from repo root)

Integrates the **Registration & Delivery** module (the primary beneficiary module). Adds:
- `DigitScannerBloc` in `app.dart` (scanner dependency)
- `RegistrationDeliverySingleton` initialization with full configuration (gender options, ID types, deletion reasons, delivery comments, symptoms, referral reasons)
- `RegistrationDeliveryWrapperRoute` to the router and home screen
- Local repos for: `HouseholdModel`, `ProjectBeneficiaryModel`, `HouseholdMemberModel`, `TaskModel`, `SideEffectModel`, `ReferralModel`
- Sync-down cases for all the above entity types
- Entity mapper cases
- Localization delegate
- Remote repo providers
- Constants and mapper registrations

---

## 10. Utility Scripts

### `clean_build.sh`

**Run:** `bash tools/clean_build.sh`

Performs a deep clean of the iOS and Flutter build caches, then re-fetches all dependencies.

**Steps:**
1. `pod deintegrate` + `pod install` + `pod repo update` in `apps/health_campaign_field_worker_app/ios/`
2. `flutter clean`
3. `flutter pub cache repair`
4. `flutter pub get`
5. `melos clean`
6. `melos bootstrap`

> Use this when facing build issues after switching branches or updating packages.

---

### `run_build_runner.sh`

**Run:** `bash tools/run_build_runner.sh`

Runs `flutter pub run build_runner build --delete-conflicting-outputs` across the root and all sub-packages (`packages/forms_engine/`, `packages/digit_components/`).

Internally calls `get_dependencies.sh` first to ensure packages are up-to-date.

---

### `get_dependencies.sh`

**Run:** `bash tools/get_dependencies.sh`

Runs `flutter clean && flutter packages get` for the root and all sub-packages (`packages/forms_engine/`, `packages/digit_components/`).

---

### `generate-apk.sh`

**Run:** `bash tools/generate-apk.sh`  
**Env vars:** `BUILD_CONFIG` (`release` | `profile`, default: `release`)

Builds an Android APK for the health app.

**Steps:**
1. Runs `tools/install_bricks.sh` (ensures code gen is complete)
2. Changes to `apps/health_campaign_field_worker_app/`
3. Runs `flutter build apk --release` or `flutter build apk -t lib/main_driver.dart --profile` based on `BUILD_CONFIG`

**Example for CI/CD:**
```bash
BUILD_CONFIG=release bash tools/generate-apk.sh
BUILD_CONFIG=profile bash tools/generate-apk.sh
```

---

### `combine_coverage.sh`

**Run:** Typically invoked by Melos as a post-test step for each package.

Merges per-package `lcov.info` coverage files into a single combined report at `$MELOS_ROOT_PATH/coverage_report/lcov.info`.

- Only processes packages that contain both `pubspec.yaml` with `flutter` and a `coverage/` directory.
- Rewrites relative `SF:lib/...` paths in lcov to absolute paths so reports can be combined across packages.
- Deletes each package's local `coverage/` directory after merging.

---

### `localization_json_convertor.ts`

**Type:** TypeScript  
**Run:** `npx ts-node tools/localization_json_convertor.ts` (or compile and run with Node)

Converts a bulk localization input format (with all locales as columns) into the DIGIT platform's expected API upsert format (one record per locale per key).

**Input format:**
```json
{ "module": "hcm-common", "code": "CORE_COMMON_CONTINUE", "en_MZ": "Continue", "pt_MZ": "Prosseguir" }
```

**Output format (per locale):**
```json
{ "code": "CORE_COMMON_CONTINUE", "message": "Continue", "module": "hcm-common", "locale": "en_MZ" }
```

The script processes a hard-coded `input` array and generates output arrays for each locale. Use it to prepare bulk localization data for the DIGIT MDMS localization API.

---

## Quick Reference

| Goal | Command |
|------|---------|
| **Full project setup** | `dart tools/run_all_scripts.dart` |
| **Create env files only** | `dart tools/create_env_overrides.dart` |
| **Patch router (skip language screen)** | `dart tools/remove_language_selection.dart` |
| **Interactive module wizard** | `bash tools/init_implementation.sh` |
| **Install bricks & gen code** | `bash tools/install_bricks.sh` |
| **Add a Flutter package** | `bash tools/import_packages.sh --main-app <package_name>` |
| **Integrate Registration & Delivery** | `dart tools/registration_delivery_imports.dart` |
| **Integrate Inventory** | `dart tools/inventory_package_imports.dart` |
| **Integrate Attendance** | `dart tools/attendance_package_imports.dart` |
| **Integrate Complaints** | `dart tools/complaints_package.dart` |
| **Integrate Checklist** | `dart tools/checklist_package_imports.dart` |
| **Integrate Dashboard (DSS)** | `dart tools/digit_dss_imports.dart` |
| **Integrate Referral Reconciliation** | `dart tools/referral_reconciliation_imports.dart` |
| **Integrate Closed Household** | `dart tools/closed_household_package_imports.dart` |
| **Deep clean + rebuild** | `bash tools/clean_build.sh` |
| **Build release APK** | `bash tools/generate-apk.sh` |
| **Run build_runner** | `bash tools/run_build_runner.sh` |
