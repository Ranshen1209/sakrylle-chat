# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> Kelivo (Sakrylle Chat) is a cross-platform Flutter LLM chat client (Android / iOS / macOS / Windows / Linux).

## 1. Repository Facts

- This is a Flutter app repository. Root `pubspec.yaml` declares `name: sakrylle_chat`, `sdk: ^3.8.1`, `flutter.generate: true`.
- Main code lives in `lib/`, tests in `test/`. Local path dependencies exist:
  - `dependencies/mcp_client`
  - `dependencies/tray_manager/packages/tray_manager`
  - `dependencies/flutter_tts`
  - `dependencies/flutter-permission-handler/permission_handler_windows`
  - `dependencies/gpt_markdown`
- The pubspec package name is `sakrylle_chat`. **All package-prefixed imports use `package:sakrylle_chat/...`**. Do not use `package:Kelivo/...` — that form does not exist in this codebase.
  - Most files use relative imports; `package:sakrylle_chat/...` is used mainly for cross-tree references (e.g., secrets, l10n, theme from deep widgets, and in test files).
- Localization is driven by `l10n.yaml`:
  - `arb-dir: lib/l10n`
  - `template-arb-file: app_en.arb`
  - `output-localization-file: app_localizations.dart`
  - `untranslated-messages-file: desiredFileName.txt`
- There are exactly 4 ARB files that must stay in sync:
  - `lib/l10n/app_en.arb`
  - `lib/l10n/app_zh.arb`
  - `lib/l10n/app_zh_Hans.arb`
  - `lib/l10n/app_zh_Hant.arb`
- The following are generated or build artifacts. Never hand-edit them:
  - `lib/l10n/app_localizations*.dart`
  - `lib/core/models/*.g.dart`
  - All other generated logic must go through commands, not manual edits
  - `.dart_tool/**`
  - `build/**`
- Top-level platform entry is `_selectHome()` in `lib/main.dart`:
  - macOS / Windows / Linux -> `DesktopHomePage`
  - Android / iOS / `kIsWeb` -> `HomePage`
- Desktop is NOT "mobile stretched wider":
  - `lib/desktop/desktop_home_page.dart` is the desktop app shell: nav rail, window title bar, hotkeys, desktop settings, translate/storage tabs, and other desktop-level interactions
  - `lib/desktop/desktop_chat_page.dart` is the desktop chat entry, currently reusing `HomePage`
  - `lib/features/home/pages/home_page.dart` only handles the shared chat page, switching internally by width to `home_mobile_layout.dart` or `home_desktop_layout.dart`
  - Therefore "wide/tablet layout" != "desktop app entry". Do not conflate them.
- Reusable UI primitives live in these locations:
  - `lib/shared/widgets/ios_tactile.dart`: `IosIconButton`, `IosCardPress`
  - `lib/shared/widgets/ios_tile_button.dart`
  - `lib/shared/widgets/ios_switch.dart`
  - `lib/shared/widgets/ios_checkbox.dart`
  - `lib/shared/widgets/ios_form_text_field.dart`
  - `lib/desktop/widgets/desktop_select_dropdown.dart`
  - `lib/shared/dialogs/**`
  - `lib/shared/responsive/**`
- Theme and dynamic color follow the repo as-is:
  - `lib/theme/**` is the single source of truth for theming and tokens
  - Android dynamic color is only enabled per-platform in `main.dart`. Do not extrapolate Android visual or interaction rules to desktop.
- Analysis configuration in `analysis_options.yaml`:
  - Extends `package:flutter_lints/flutter.yaml`
  - Disables `package_names` lint
  - Excludes `dependencies/flutter_tts/**` from analysis

## 2. Architecture Overview

### State Management
- Uses the **Provider** pattern (`ChangeNotifierProvider`) throughout — NOT Riverpod, BLoC, or Redux.
- All top-level providers are initialized in `MyApp.build()` via `MultiProvider` in `lib/main.dart`.
- Provider files live in `lib/core/providers/`. Key providers:
  - `ChatProvider` — active conversation state, message streaming
  - `SettingsProvider` — persisted settings (theme, fonts, tray, proxy, etc.)
  - `UserProvider` — user identity, API key storage
  - `McpProvider` — MCP server connections and tool registry
  - `AssistantProvider` — custom AI assistant CRUD
  - `ChatService` — conversation persistence (Hive), CRUD, import/export
  - `McpToolService` — MCP tool execution orchestration
  - `TtsProvider` — text-to-speech engine management
  - `HotkeyProvider` — desktop global hotkey registration
  - Various feature-specific providers (`BackupProvider`, `S3BackupProvider`, `QuickPhraseProvider`, `WorldBookProvider`, `MemoryProvider`, etc.)

### Persistence (Hive)
- Local persistence uses **Hive** (`hive_flutter`). Hive models with code generation live in `lib/core/models/`:
  - `chat_message.dart` + `chat_message.g.dart` — individual messages
  - `conversation.dart` + `conversation.g.dart` — conversation containers
- Other models (non-Hive): `provider_group.dart`, `assistant.dart`, `api_keys.dart`, `token_usage.dart`, `oauth_tokens.dart`, etc.
- After modifying Hive-annotated models, run `dart run build_runner build --delete-conflicting-outputs`.
- Secure storage uses `flutter_secure_storage` via `lib/core/services/auth/secure_storage_service.dart`.

### API / Multi-Provider Abstraction
- The central API service is `lib/core/services/api/chat_api_service.dart` (~1300 lines). It uses **`part` directives** to split provider-specific implementations:
  - `part 'chat_api_service_shims.dart';`
  - `part 'providers/openai_common.dart';`
  - `part 'providers/openai_chat_completions.dart';`
  - `part 'providers/openai_images.dart';`
- Additional standalone provider files in `lib/core/services/api/providers/`:
  - `google_common.dart`, `google_gemini.dart`, `google_vertex.dart`
  - `claude_official.dart`
  - `openai_responses.dart`
- Provider routing logic is in `ChatApiService`, branching on provider type (OpenAI-compatible, Gemini, Vertex, Claude, etc.).
- Search providers live in `lib/core/services/search/providers/` with a similar multi-provider pattern via `search_service.dart`.
- Built-in MCP tools: `lib/core/services/mcp/kelivo_fetch/` and `lib/core/services/api/builtin_tools.dart`.

### Feature Modules
Each feature under `lib/features/` contains its own pages, widgets, and models:
- `chat/` — chat page, message rendering, input bar
- `home/` — home shell, mobile/desktop layout switching, side drawer
- `assistant/` — assistant management
- `provider/` — API provider configuration
- `model/` — model selection and management
- `mcp/` — MCP server configuration
- `search/` — web search provider settings
- `settings/` — app settings pages
- `translate/` — translation features
- `backup/` — WebDAV / S3 backup management
- `quick_phrase/`, `instruction_injection/`, `world_book/` — prompt engineering tools
- `scan/` — QR code scanning
- `stats/` — usage statistics

### Desktop Shell
- `lib/desktop/desktop_home_page.dart` — top-level desktop shell with nav rail
- `lib/desktop/desktop_tray_controller.dart` — system tray icon and menu
- `lib/desktop/desktop_window_controller.dart` — window size/position persistence
- `lib/desktop/hotkeys/` — global hotkey registration
- `lib/desktop/setting/` — desktop-specific settings tabs
- `lib/desktop/widgets/` — desktop-only reusable widgets

### Commands Quick Reference

```bash
# Install dependencies
flutter pub get

# Generate localization code (after ARB edits)
flutter gen-l10n

# Generate Hive adapters (after Hive model edits)
dart run build_runner build --delete-conflicting-outputs

# Format changed files
dart format lib/ test/

# Static analysis (with fatal infos, as CI does)
dart analyze --fatal-infos lib test

# Run all tests
flutter test

# Run a single test file
flutter test test/path/to/specific_test.dart

# Run a single test by name
flutter test --name "test name pattern" test/path/to/file.dart

# Platform builds (release)
flutter build apk --release --split-per-abi
flutter build ios --release --no-codesign
flutter build macos --release
flutter build windows --release
flutter build linux --release

# Check untranslated messages (CI script)
python3 .github/scripts/check_no_new_untranslated.py <base_desiredFileName.txt> desiredFileName.txt
```

### CI Workflows

The repo has several GitHub Actions workflows in `.github/workflows/`:
- `pr-check.yml` — Runs on PRs: `dart format` (changed files), `flutter gen-l10n` + diff check, no-new-untranslated check, `dart analyze --fatal-infos`, `flutter test`
- `build-stable.yml` — Manual multi-platform release build (Android / iOS / macOS / Windows / Linux) with secrets injection
- `build-stable-38.yml`, `build-stable-41.yml` — Older Flutter version build variants
- `build-linux-arm64.yml` — Linux ARM64 build
- `build.yml`, `bulid-stable-38-new.yml` — Additional build variants

When touching build, versioning, or secrets injection, check ALL similar workflow files for sync.

### Android Signing

- Android release APKs are signed with the local alias `cervine`.
- Local signing uses ignored files only: `android/app/cervine.jks` and `android/key.properties`.
- The signing password is stored in the macOS Keychain generic password item named `cervine`.
- CI signing is configured in `.github/workflows/build-stable.yml` via GitHub Secrets: `SIGN_KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, and `KEY_PASSWORD`; `KEY_ALIAS` should be `cervine`.
- Never commit the keystore, `key.properties`, passwords, or decoded CI signing material.

## 3. Working Style

- Communicate in Chinese throughout. Stay focused on the current task. No vague suggestions.
- Facts first. All conclusions must be based on current code, config, tests, build scripts, or git state. No guessing.
- Debug-first. Never add silent degradation, swallowed errors, hidden fallback paths, or fake success branches just to "make it run".
- Default to KISS / YAGNI:
  - Use the most direct, most verifiable approach first.
  - Do not pre-plant extra layers, empty abstractions, or config switches for "architectural completeness" or "might need it later".
- SOLID is a tool, not a goal:
  - Only split responsibilities when it genuinely reduces coupling and improves readability.
  - Do not shatter simple logic into a chain of tiny files just for formal layering.
- Minimal closed loop. Make only the minimum change needed for the current task. Do not fix unrelated issues on the side.
- Parallel context gathering by default during exploration:
  - Independent file reads, `rg` searches, `git status`, config checks, and log inspections should be batched in a single parallel round.
  - Do not serialize what can be parallelized.
- For complex tasks, write a brief Mini Control Contract before touching code:
  - `Primary Setpoint`: What exactly must be achieved
  - `Acceptance`: What command, test, or behavior proves it
  - `Guardrails`: What must not break as a side effect
  - `Boundary`: Which files/modules are in scope
  - `Risks`: 1 to 3 key risks

## 4. Mandatory Rules

### 4.1 All User-Visible Text Must Be Localized

- No user-visible text may be hardcoded in Dart UI code. This includes but is not limited to:
  - Page titles
  - Button labels
  - `SnackBar` / `Dialog` / `Tooltip` content
  - `semanticLabel`
  - Notification text
  - Tray menu text
- When adding or modifying user-visible strings, ALL 4 files must be updated simultaneously:
  - `lib/l10n/app_en.arb`
  - `lib/l10n/app_zh.arb`
  - `lib/l10n/app_zh_Hans.arb`
  - `lib/l10n/app_zh_Hant.arb`
- Updating only `app_en.arb` or only `app_zh.arb` and stopping is not acceptable.
- Placeholders, plurals, selects, and `@key` metadata must be consistent across all four ARB files.
- New keys follow the existing camelCase convention with a feature prefix. Do not use context-free short names like `title1` or `labelText`.
- After ARB changes, run:

```bash
flutter gen-l10n
```

- Never hand-edit `lib/l10n/app_localizations.dart` or `lib/l10n/app_localizations_*.dart`.
- `desiredFileName.txt` is the untranslated messages file. Do not introduce new untranslated entries. If you add a key, provide translations for all languages in the same change.

### 4.2 Generated Code Must Be Maintained Via Commands

- After modifying Hive models, `@HiveType`, `@HiveField`, or `part '*.g.dart'` references, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

- Generated file changes must correspond strictly to source changes. Do not hand-craft `*.g.dart` files.

### 4.3 Format Code Before Finishing

- Any change to Dart/Flutter code requires formatting before completion.
- Prefer formatting only the changed paths. For large changes, format `lib/` and `test/`.

```bash
dart format <changed-paths>
```

- Unformatted code must not be committed.

### 4.4 Minimum Sufficient Verification After Completion

- Default minimum verification loop:

```bash
flutter analyze
flutter test
```

- If the change scope is clearly narrow, at minimum run the relevant test subset and explain in the delivery notes why only a subset was run.
- If the following content types are modified, the corresponding extra action is mandatory:

| Change Type | Required Action |
| --- | --- |
| ARB / localization | `flutter gen-l10n`, check `desiredFileName.txt`, then `flutter analyze` |
| Hive model / generated code | `dart run build_runner build --delete-conflicting-outputs`, then run related tests |
| `pubspec.yaml` / dependencies | `flutter pub get`, then `flutter analyze` and related tests |
| `.github/workflows/**` / build scripts | Check ALL similar workflow files, not just one |
| Platform directories `android/ ios/ macos/ linux/ windows/` | At least one targeted platform verification; if impossible, state why explicitly |
| `dependencies/**` path dependencies | Run analysis/tests in the dependency's own directory, not just the root repo |
| `lib/desktop/**`, desktop hotkeys/tray/window logic | At least one desktop-targeted verification (e.g. `flutter run -d macos`, `flutter build macos`, or the corresponding Windows/Linux target); if only the current machine's platform was verified, state the uncovered platform boundary |

- If local environment limitations prevent completing any verification, the final delivery notes must explicitly state "what was not run, why, and where the risk lies".

### 4.5 Do Not Hand-Edit or Commit What Should Not Be Committed

- Never hand-edit:
  - `.dart_tool/**`
  - `build/**`
  - Content maintained by `flutter gen-l10n` / `build_runner`
- Do not modify unless required by the task:
  - `.idea/**`
  - Platform signing, certificates, personal environment files
  - Workflows unrelated to the current task

### 4.6 Secrets and Fallback Mechanisms

- Never commit real secrets to source code.
- `lib/secrets/fallback.dart` currently contains placeholder implementations. CI injects real values across multiple workflows. Do not write real keys into the repo.
- Do not silently add new fallback keys, fallback APIs, or error-swallowing logic just to "make it run".
- If a fallback mechanism is genuinely needed, it must satisfy ALL of:
  - Explicit toggle
  - Clear logging
  - Can be disabled
  - Reason documented in the task description

### 4.7 Change Boundary and Duplicate Workflows

- This repo has multiple similar GitHub Actions workflow files, especially for builds. When touching build, versioning, or injection logic, check ALL similar workflows for sync.
- Do not expand scope just because you spotted something that "could be unified". Finish the current task first, then decide whether to open a separate refactoring task.
- When touching a path dependency, treat it as an independent module. Do not only patch the surface at the root repo level.

### 4.8 Desktop Tasks: Determine Entry Layer First

- When the task mentions desktop, Windows, macOS, Linux, tray, hotkeys, window, context menu, or desktop settings, first determine which layer the issue belongs to:
  - Top-level desktop app shell: `lib/desktop/**`
  - Shared chat content layer: `lib/features/home/**`
  - Platform services or providers: `lib/core/**`, platform directories, or path dependencies
- For desktop app shell changes, check these first:
  - `lib/main.dart`
  - `lib/desktop/desktop_home_page.dart`
  - `lib/desktop/desktop_settings_page.dart`
  - `lib/desktop/setting/**`
  - `lib/desktop/window_title_bar.dart`
  - `lib/desktop/desktop_tray_controller.dart`
  - `lib/desktop/hotkeys/**`
- Only when the issue clearly belongs to "shared content area reused by desktop chat page" should you prioritize:
  - `lib/features/home/pages/home_page.dart`
  - `lib/features/home/pages/home_desktop_layout.dart`
  - `lib/features/home/widgets/**`
- Do not guess desktop platform behavior in `home_mobile_layout.dart` or mobile branches. Do not stuff desktop-specific control flow into mobile entry points.
- Desktop interactions differ from mobile. For example, chat messages currently use "long-press on mobile, right-click menu on desktop". Desktop tasks must consider hover, right-click, keyboard shortcuts, window size, and title bar -- not just touch gestures.
- If a task spans both the desktop shell and the shared content layer, state the primary landing point in the description first, then apply minimal changes in each respective layer. Do not scatter platform routing across unrelated locations.

### 4.9 UI Component Reuse and Custom iOS Style Boundary

- Before adding new UI, search these directories for existing components instead of hand-rolling a new one inline:
  - `lib/shared/widgets/**`
  - `lib/shared/dialogs/**`
  - `lib/shared/responsive/**`
  - `lib/desktop/widgets/**`
- Prefer reusing or extending existing components, such as:
  - `IosIconButton`
  - `IosCardPress`
  - `IosTileButton`
  - `IosSwitch`
  - `IosCheckbox`
  - `IosFormTextField`
  - `DesktopSelectDropdown`
  - `WindowTitleBar`
- If a new style will appear on two or more pages, do not keep adding page-private widgets (e.g. new `_IosFilledButton`, `_TactileIconButton`, `_CustomDropdown` variants). Extract it to `lib/shared/widgets/` or `lib/desktop/widgets/` as a reusable component.
- Visual and interaction style defaults to "custom iOS style", not Android style:
  - Do not introduce Android ripple, Material default splash, default FAB emphasis, or Android-style button feedback
  - Hover/press feedback should prefer the existing iOS tactile components' approach: color, opacity, subtle scale transitions
  - Desktop allows hover, right-click, and focus states, but the overall feel must remain unified to the custom iOS style, not a Material/Android mashup
- If Material native components must be used for semantic or framework reasons, explicitly suppress off-style default feedback and consolidate styling into shared components instead of patching it piecemeal across pages.
- Icons, spacing, forms, dialogs, and panel styles should follow existing theme tokens and components. Do not mix multiple visual languages on the same page.

### 4.10 Tests and Self-Review Must Be Requirement-Driven

- Tests must be driven by requirements, defect symptoms, or acceptance criteria -- not by chasing implementation details.
- Before writing tests, list the minimum scenario set for this task. At minimum, explicitly cover:
  - Happy path
  - Boundary inputs
  - Error or failure paths
  - State transitions or interaction branches (if applicable)
- When fixing bugs, write a minimal failing case first, then fix. Do not only add an after-the-fact weak-assertion test that "happens to pass".
- Never widen public API surface, expose private internals, or distort production code responsibilities just to make tests easier to write.
- Before completion, perform at least one self-review explicitly checking these dimensions:
  - Maintainability: Is the code easier to read and modify than before?
  - Performance: Any obvious extra rebuilds, IO, traversals, or allocations introduced?
  - Security: Any input validation gaps, secret leaks, path/command injection, or permission boundary errors?
  - Style consistency: Does it match the repo's existing naming, organization, and UI language?
  - Documentation and comments: Does complex intent need minimal explanation?
  - Compatibility boundary: Does it affect existing user data, config, persisted fields, import/export formats, or established interactions?
- Compatibility is not a default-ignore item. When existing data or published behavior is involved, explicitly judge compatibility. If breaking, the delivery notes must state the breakage scope and migration path.

## 5. Recommended Execution Order

1. `git status --short` -- confirm workspace baseline.
2. Read relevant code and config. Write clear acceptance criteria. For desktop tasks, confirm entry topology first: `main.dart` -> `lib/desktop/**` -> shared chat layout.
3. Batch all independent context reads, searches, and status checks in parallel, then decide the minimal change landing point.
4. List requirement scenarios and verification methods first, then make minimal changes. Do not mix in unrelated refactoring.
5. Run the generation, formatting, analysis, and test commands relevant to this task.
6. Self-review `git diff`. Confirm no missed localization, generated files, compatibility risks, or unrelated changes.
7. When delivering, state explicitly:
   - What was changed
   - What commands were run
   - What verification was skipped
   - What residual risks remain

## 6. Pre-Commit Checklist

- All new user-visible text uses `AppLocalizations`.
- All 4 ARB files have been updated in sync.
- `flutter gen-l10n` has been executed and generated files match ARB content.
- If Hive models were touched, `build_runner` has been executed.
- `dart format` has been executed.
- `flutter analyze` has been executed.
- Related `flutter test` has been executed. If no related tests exist, create and run them following official testing standards.
- Test scenarios cover the happy path, boundary values, and failure paths for this task's requirements -- not just a single green run.
- Desktop tasks have confirmed the entry layer. No desktop-only logic leaked into mobile branches.
- New or adjusted UI prioritized reuse of existing shared / desktop components. No near-duplicate widgets created.
- New UI does not introduce unnecessary Android ripple or Material default interaction feedback.
- At least one round of self-review completed, checking maintainability, performance, security, style consistency, and compatibility boundary.
- No real secrets, build artifacts, or unrelated files committed.
- If workflows / platform directories / path dependencies were touched, corresponding extra verification has been done.

## 7. External Best Practices

- Code should follow the Flutter contribution guide:
  - https://github.com/flutter/flutter/blob/main/CONTRIBUTING.md
- Tests should reference:
  - https://github.com/flutter/flutter/blob/main/docs/contributing/testing/Writing-Effective-Tests.md
  - https://github.com/flutter/flutter/blob/main/docs/contributing/testing/Running-and-writing-tests.md
- For Flutter code style, follow the Flutter styleguide first. Follow Effective Dart: Style only when it does not conflict:
  - https://github.com/flutter/flutter/blob/main/docs/contributing/Style-guide-for-Flutter-repo.md
  - https://dart.dev/effective-dart/style
- If the repo ever introduces `engine/`-level changes, add engine test guidance then. The repo currently has no such directory; do not apply it mechanically.
- PR descriptions should include the Pre-launch Checklist from the Flutter PR template when applicable:
  - https://github.com/flutter/flutter/blob/main/.github/PULL_REQUEST_TEMPLATE.md

## 8. Design Principles

- Readability first. Code is for humans to read, not for machines to show off.
- Default against bloated implementations, idle abstractions, and academic over-engineering.
- If you can remove complexity, remove it. If you can avoid a branch, avoid it. If you can skip a layer of indirection, skip it.
- Simple, stable, and verifiable first. "Elegant" comes after.
- Avoid dual state and dual truth. Keep one source of truth.
- Write only what is needed now, but write it right.
- Error messages must be useful -- they should help locate and recover, not just say "failed".
- Mechanisms over hand-picked magic constants. If a threshold must be hardcoded, explain why and state its boundaries.
- When small-step verification is possible, do not make large irreversible changes.

## 9. Historical Pitfall Log

> Record significant pitfalls encountered during development here.

- Recording principles:
  - Only record issues that actually occurred in this repo and have reuse value for future development.
  - Do not write "heard this might happen" hearsay entries.
  - When adding entries, prefer "symptom -> root cause -> fix/constraint". Avoid recording conclusions without context.

## Appendix: Skills Usage Rules

- Before starting a task, scan available skill documents in `.claude/skills/`.
- When activating a skill, declare the skill name and purpose in communication.
- Regular development does not mandate any specific skill. Activate only when semantically matched.


## Sakrylle OIDC Documentation Governance

- `oidc-docs/` in this repository is **product-local** documentation for Sakrylle Chat only.
- Canonical platform docs live in `../sub2api/sakrylle-docs/`, especially:
  - `10-platform-identity/current-state.md`
  - `10-platform-identity/rp-integration-guide.md`
  - `10-platform-identity/commercial-boundaries.md`
  - `10-platform-identity/configuration-isolation.md`
- Local docs are limited to:
  - `oidc-docs/README.md`
  - `oidc-docs/local-integration.md`
  - `oidc-docs/implementation-status.md`
  - `oidc-docs/troubleshooting.md`
  - `oidc-docs/historical/` for preserved old Chat research/plans.
- Do **not** copy OIDC Provider endpoints, claims policy, roadmap, risk register, or design system content into this repository. Link to the center docs instead.
- When changing Flutter OAuth/OIDC login, custom URL schemes, secure token storage, Sakrylle provider defaults, bundle IDs, token logging, id_token validation, refresh/revoke/logout, or Chat rollout status, update local `oidc-docs/` and update center docs if the shared platform contract changes.
