# Sakrylle 迁移收尾 实现计划（OIDC 接入 + 品牌化）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成 Sakrylle Chat 从 Kelivo 的迁移收尾——OIDC 接入补齐 Windows/Linux loopback 登录并与中心契约对齐，品牌化清除用户可见 Kelivo 残留并对持久化常量做安全迁移。

**Architecture:** 三个可独立交付的阶段。Phase 1（品牌化静态/图标/命名/字样，零数据风险）→ Phase 2（持久化常量改名+安全迁移：macOS autosave、通知渠道、字体别名、备份双读）→ Phase 3（OIDC loopback + scope 对齐 + 中心文档同步 + 门禁验收）。每阶段独立可提交、可测试。

**Tech Stack:** Flutter / Dart、Provider、Hive、`flutter_web_auth_2`、`url_launcher`、`dart:io HttpServer`、`flutter_secure_storage`、`jose`；Swift（macOS/iOS）、C++（Linux/Windows）。

**Spec:** `docs/superpowers/specs/2026-06-10-sakrylle-migration-completion-design.md`

**约定：** 所有命令在仓库根 `/Users/cervine/Documents/Sakrylle/Sakrylle Chat` 执行。当前分支 `feat/sakrylle-migration-completion`。

---

# Phase 1 — 品牌化静态文本 / 应用内图标 / 平台命名 / 用户可见字样

> 零数据风险，可独立交付。对应 spec §4.1、§4.2、§4.3、§4.5。

## Task 1: README 品牌名与 App Store 徽章

**Files:**
- Modify: `README.md`
- Modify: `README_ZH_CN.md`

说明：仅改品牌显示文本与移除 App Store 徽章。**含字面量 `kelivo` 的 GitHub URL（releases、kelivo-ohos、issues）保持不变**（用户已确认保留现仓库地址）。

- [ ] **Step 1: 改 `README.md`**

把行 2 `alt="Kelivo Icon"` → `alt="Sakrylle Chat Icon"`，且 `src="assets/app_icon.png"` → `src="assets/sakrylle_icon.png"`：
```html
  <img src="assets/sakrylle_icon.png" alt="Sakrylle Chat Icon" width="100" />
```
把行 3 `<h1>Kelivo</h1>` → `<h1>Sakrylle Chat</h1>`。
删除行 27 整行（App Store 徽章）：
```
[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/us/app/kelivo/id6752122930)
```
把行 79 `Kelivo's interface design is heavily inspired` → `Sakrylle Chat's interface design is heavily inspired`。

- [ ] **Step 2: 改 `README_ZH_CN.md`**

行 2 同上（`assets/sakrylle_icon.png` + `alt="Sakrylle Chat Icon"`）；行 3 `<h1>Kelivo</h1>` → `<h1>Sakrylle Chat</h1>`；删除行 26 App Store 徽章整行；行 79 `Kelivo 的界面设计深受` → `Sakrylle Chat 的界面设计深受`。

- [ ] **Step 3: 校验无遗漏品牌名（GitHub URL 除外）**

Run: `rg -n "Kelivo" README.md README_ZH_CN.md`
Expected: 仅剩 GitHub URL 中的 `kelivo`（如 `github.com/Chevey339/kelivo`、`kelivo-ohos`），无独立品牌名 `Kelivo`/`<h1>Kelivo`。

- [ ] **Step 4: Commit**

```bash
git add README.md README_ZH_CN.md
git commit -m "docs: rebrand README to Sakrylle Chat, drop stale App Store badge"
```

## Task 2: web/manifest.json 应用名

**Files:**
- Modify: `web/manifest.json`

- [ ] **Step 1: 改名**

```json
    "name": "Sakrylle Chat",
    "short_name": "Sakrylle Chat",
```
（替换原 `"name": "kelivo"` 与 `"short_name": "kelivo"`）

- [ ] **Step 2: Commit**

```bash
git add web/manifest.json
git commit -m "chore(web): set PWA name to Sakrylle Chat"
```

## Task 3: 应用内品牌图标重指向 sakrylle_icon.png

**Files:**
- Modify: `lib/features/settings/pages/about_page.dart:331`
- Modify: `lib/desktop/setting/about_pane.dart:276`
- Modify: `lib/desktop/desktop_home_page.dart:312`
- Modify: `lib/desktop/desktop_tray_controller.dart:96`
- Modify: `linux/runner/my_application.cc:33`
- Modify: `pubspec.yaml`（assets 增列 sakrylle_icon.png）

说明：保留旧 `assets/app_icon.png`、`assets/icons/kelivo.png` 不删（仍被 .ico/打包资源间接依赖）。仅把应用内显示引用改指新图标。`.ico`（tray:92 / Runner.rc / pubspec:161）暂不动（无法在本任务内由 png 生成 ico，列入 Phase 1 末尾的可选 Task 6）。

- [ ] **Step 1: 确认 pubspec 已声明 sakrylle_icon.png**

Run: `rg -n "sakrylle_icon.png" pubspec.yaml`
Expected: 若无输出，则在 `flutter:` 的 `assets:` 列表（`pubspec.yaml:160` 附近 `- assets/app_icon.png` 下一行）新增：
```yaml
    - assets/sakrylle_icon.png
```

- [ ] **Step 2: 改 Dart 引用（4 处）**

`lib/features/settings/pages/about_page.dart:331`、`lib/desktop/setting/about_pane.dart:276`：把 `'assets/app_icon.png'` → `'assets/sakrylle_icon.png'`。
`lib/desktop/desktop_home_page.dart:312`：把 `'assets/icons/kelivo.png'` → `'assets/sakrylle_icon.png'`。
`lib/desktop/desktop_tray_controller.dart:96`：把 `'assets/icons/kelivo.png'` → `'assets/sakrylle_icon.png'`。

- [ ] **Step 3: 改 Linux 窗口图标加载路径**

`linux/runner/my_application.cc:33`：把 `"app_icon.png"` → `"sakrylle_icon.png"`（该处通过 assets 路径加载窗口图标）。

- [ ] **Step 4: 分析**

Run: `flutter analyze lib/features/settings/pages/about_page.dart lib/desktop/setting/about_pane.dart lib/desktop/desktop_home_page.dart lib/desktop/desktop_tray_controller.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml lib/features/settings/pages/about_page.dart lib/desktop/setting/about_pane.dart lib/desktop/desktop_home_page.dart lib/desktop/desktop_tray_controller.dart linux/runner/my_application.cc
git commit -m "feat(brand): point in-app icons to sakrylle_icon.png"
```

## Task 4: Linux 窗口标题 + 图标名 + iOS LiveActivity 重命名

**Files:**
- Modify: `linux/runner/my_application.cc:51,83,87`
- Rename: `ios/Runner/KelivoGenerationActivityAttributes.swift` → `ios/Runner/SakrylleGenerationActivityAttributes.swift`
- Modify: `ios/GenerationActivityExtension/GenerationActivityExtension.swift`
- Modify: `ios/Runner/AppDelegate.swift`
- Modify: `ios/Runner.xcodeproj/project.pbxproj`

- [ ] **Step 1: Linux 标题与 icon_name**

`linux/runner/my_application.cc`：
- 行 51 `gtk_window_set_icon_name(window, "kelivo");` → `gtk_window_set_icon_name(window, "com.sakrylle.chat");`
- 行 83 `gtk_header_bar_set_title(header_bar, "kelivo");` → `gtk_header_bar_set_title(header_bar, "Sakrylle Chat");`
- 行 87 `gtk_window_set_title(window, "kelivo");` → `gtk_window_set_title(window, "Sakrylle Chat");`

- [ ] **Step 2: 重命名 iOS LiveActivity 源文件（git mv 保留历史）**

```bash
git mv ios/Runner/KelivoGenerationActivityAttributes.swift ios/Runner/SakrylleGenerationActivityAttributes.swift
```
编辑新文件，把 `struct KelivoGenerationActivityAttributes` → `struct SakrylleGenerationActivityAttributes`。

- [ ] **Step 3: 全量替换类型引用**

在以下文件把所有 `KelivoGenerationActivityAttributes` → `SakrylleGenerationActivityAttributes`：
```bash
sed -i '' 's/KelivoGenerationActivityAttributes/SakrylleGenerationActivityAttributes/g' \
  ios/GenerationActivityExtension/GenerationActivityExtension.swift \
  ios/Runner/AppDelegate.swift \
  ios/Runner.xcodeproj/project.pbxproj
```
并把 `project.pbxproj` 中 `path = KelivoGenerationActivityAttributes.swift;` 一并改为 `path = SakrylleGenerationActivityAttributes.swift;`（上述 sed 已覆盖该字符串）。
另把 `ios/Runner/AppDelegate.swift:222` 的后台任务标签 `"KelivoBackgroundGeneration"` → `"SakrylleBackgroundGeneration"`。

- [ ] **Step 4: 校验无残留**

Run: `rg -n "KelivoGenerationActivityAttributes|KelivoBackgroundGeneration|\"kelivo\"" ios/ linux/runner/my_application.cc`
Expected: 无输出。

- [ ] **Step 5: Commit**

```bash
git add -A ios/ linux/runner/my_application.cc
git commit -m "refactor(ios,linux): rename Kelivo LiveActivity type and window title to Sakrylle"
```

## Task 5: 用户可见字样（MCP 显示名 + 导出文件名前缀）

**Files:**
- Modify: `lib/core/providers/mcp_provider.dart:771`
- Modify: `lib/features/chat/widgets/image_preview_sheet.dart:150,1027`
- Modify: `lib/features/chat/pages/image_viewer_page.dart:614,695,710,934,1473`
- Modify: `lib/shared/widgets/markdown_with_highlight.dart:2633,2683,2721,3697`
- Modify: `lib/shared/widgets/mermaid_bridge_stub.dart:734`
- Modify: `lib/core/providers/tts_provider.dart:652,952`
- Modify: `lib/desktop/setting/providers_pane.dart:5611`

说明：`kelivo_fetch`（工具 id）、`KelivoFetchMcpServerEngine`（类名）**不动**，仅改显示名与导出文件名前缀。

- [ ] **Step 1: MCP 显示名**

`lib/core/providers/mcp_provider.dart:771`：`name: 'Kelivo MCP'` → `name: 'Sakrylle Fetch'`。

- [ ] **Step 2: 导出文件名前缀**

把上述各文件中导出/临时文件名字面量前缀 `kelivo-` 与 `kelivo_`（仅文件名场景，例 `'kelivo-${...}'`、`'kelivo_${...}.png'`、`'kelivo-table'`、`'kelivo-mermaid-'`、`'kelivo-provider-qr.png'`、`'kelivo_tts_'`、`'kelivo_clip_'`）改为对应的 `sakrylle-` / `sakrylle_`。逐文件按行号定位替换。

> 注意：不要误改 `kelivo_fetch`、`kelivoin`、`kelivo_backup*`、`kelivo_local_*`、`kelivo_tmp_`、`kelivo_data_sync` 等（备份/字体/临时目录在 Phase 2 或属保留项）。本任务只动「导出文件默认名」前缀。

- [ ] **Step 3: 分析**

Run: `flutter analyze lib/core/providers/mcp_provider.dart lib/features/chat/widgets/image_preview_sheet.dart lib/features/chat/pages/image_viewer_page.dart lib/shared/widgets/markdown_with_highlight.dart lib/shared/widgets/mermaid_bridge_stub.dart lib/core/providers/tts_provider.dart lib/desktop/setting/providers_pane.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/
git commit -m "feat(brand): rename MCP display name and export filename prefixes to Sakrylle"
```

## Task 6（可选）: 由 sakrylle_icon.png 生成 app_icon.ico 并替换托盘/Windows 图标

**Files:**
- Modify: `assets/app_icon.ico`（重新生成内容）

- [ ] **Step 1: 生成 .ico**

若本机有 ImageMagick：
```bash
magick assets/sakrylle_icon.png -define icon:auto-resize=256,128,64,48,32,16 assets/app_icon.ico
```
（无 ImageMagick 则跳过本任务，托盘/Windows 图标暂留旧 .ico，记入交付说明。）

- [ ] **Step 2: Commit（仅当已生成）**

```bash
git add assets/app_icon.ico
git commit -m "chore(brand): regenerate tray/windows .ico from Sakrylle icon"
```

## Phase 1 收尾验证

- [ ] Run: `flutter analyze` → Expected: No issues.
- [ ] Run: `flutter test` → Expected: All pass（Phase 1 未改逻辑，应全绿）。

---

# Phase 2 — 持久化常量改名 + 安全迁移

> 对应 spec §4.4。每项均有迁移策略，确保不破坏已存用户数据。

## Task 7: macOS 窗口 autosave key 改名 + 迁移

**Files:**
- Modify: `macos/Runner/MainFlutterWindow.swift`

- [ ] **Step 1: 改 autosaveName 常量**

把 `private let autosaveName = NSWindow.FrameAutosaveName("KelivoMainWindowFrame")` →
```swift
  private let autosaveName = NSWindow.FrameAutosaveName("SakrylleMainWindowFrame")
```

- [ ] **Step 2: 在 awakeFromNib 启用 autosave 前插入迁移**

在 `awakeFromNib()` 中 `_ = self.setFrameAutosaveName(autosaveName)` 这一行之前插入：
```swift
    // Migrate window frame from the legacy Kelivo autosave key (one-time, lossless).
    let defaults = UserDefaults.standard
    let legacyKey = "NSWindow Frame KelivoMainWindowFrame"
    let newKey = "NSWindow Frame SakrylleMainWindowFrame"
    if defaults.object(forKey: newKey) == nil,
       let legacyValue = defaults.string(forKey: legacyKey) {
      defaults.set(legacyValue, forKey: newKey)
    }
```

- [ ] **Step 3: 目标平台验证（本机 macOS）**

Run: `flutter build macos --debug`
Expected: 构建成功。手动验证：旧版启动调整窗口大小 → 升级后窗口位置/大小保留。

- [ ] **Step 4: Commit**

```bash
git add macos/Runner/MainFlutterWindow.swift
git commit -m "feat(macos): rename window autosave key to Sakrylle with lossless migration"
```

## Task 8: 通知渠道改名 + 删旧渠道迁移

**Files:**
- Modify: `lib/core/services/notification_service.dart:9,33-34`

- [ ] **Step 1: 改渠道 id**

`lib/core/services/notification_service.dart:9`：`'kelivo_bg_chat_v2'` → `'sakrylle_bg_chat'`（第一个位置参数即 channel id）。

- [ ] **Step 2: 创建新渠道前删除旧渠道**

在 `ensureInitialized()` 内 `await android.createNotificationChannel(_channel);` 之前插入：
```dart
      // Remove the legacy Kelivo channel so it doesn't linger in system settings.
      await android.deleteNotificationChannel('kelivo_bg_chat_v2');
```

- [ ] **Step 3: 分析**

Run: `flutter analyze lib/core/services/notification_service.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/core/services/notification_service.dart
git commit -m "feat(notify): rename Android channel to sakrylle_bg_chat, delete legacy channel"
```

## Task 9: 字体本地别名改名（无需迁移）

**Files:**
- Modify: `lib/core/providers/settings_provider.dart:1383,1404,1465,1476`

说明：alias 仅是运行时字体注册的内部 family 名，每次启动从持久化字体路径重注册，从不在 UI 显示；持久化的是派生 family，旧值在新版仍用同路径重注册可用。直接改字面量即可。

- [ ] **Step 1: 替换四处字面量**

`settings_provider.dart`：行 1383 与 1465 `'kelivo_local_app'` → `'sakrylle_local_app'`；行 1404 与 1476 `'kelivo_local_code'` → `'sakrylle_local_code'`。

- [ ] **Step 2: 分析**

Run: `flutter analyze lib/core/providers/settings_provider.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/core/providers/settings_provider.dart
git commit -m "chore(font): rename local font alias prefix to sakrylle (runtime-only, no migration)"
```

## Task 10: 备份双读迁移 — 文件名解析（先写失败测试）

**Files:**
- Create: `test/core/services/backup/backup_prefix_compat_test.dart`
- Modify: `lib/core/services/backup/data_sync.dart`（新增可测的纯静态解析函数 + 改写内部调用）

说明：把「从备份文件名解析时间戳」的逻辑抽成可测的公开静态函数 `DataSync.parseBackupTimestamp(name)`，同时识别 `kelivo_backup_*` 与 `sakrylle_backup_*`。这是双读兼容的核心断言点。

- [ ] **Step 1: 写失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sakrylle_chat/core/services/backup/data_sync.dart';

void main() {
  group('parseBackupTimestamp dual-prefix', () {
    test('parses legacy kelivo_backup filename', () {
      final t = DataSync.parseBackupTimestamp(
          'kelivo_backup_2025-01-19T12-34-56.123456.zip');
      expect(t, isNotNull);
      expect(t!.year, 2025);
      expect(t.month, 1);
      expect(t.day, 19);
    });

    test('parses new sakrylle_backup filename', () {
      final t = DataSync.parseBackupTimestamp(
          'sakrylle_backup_2026-06-10T08-09-10.000111.zip');
      expect(t, isNotNull);
      expect(t!.year, 2026);
      expect(t.month, 6);
      expect(t.day, 10);
    });

    test('returns null for unrelated filename', () {
      expect(DataSync.parseBackupTimestamp('random.zip'), isNull);
    });
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/services/backup/backup_prefix_compat_test.dart`
Expected: FAIL（`parseBackupTimestamp` 未定义）。

- [ ] **Step 3: 新增静态解析函数**

在 `data_sync.dart` 的 DataSync 类内（紧邻其他 static 工具方法）新增：
```dart
  /// Parse the timestamp embedded in a backup zip filename.
  /// Accepts both the legacy `kelivo_backup_*` and the new `sakrylle_backup_*`
  /// naming so existing remote backups remain readable after the rebrand.
  static DateTime? parseBackupTimestamp(String name) {
    final match = RegExp(
      r'(?:kelivo|sakrylle)_backup_(\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.\d+)\.zip',
    ).firstMatch(name);
    if (match == null) return null;
    try {
      final timestamp = match.group(1)!.replaceAll(
            RegExp(r'T(\d{2})-(\d{2})-(\d{2})'),
            r'T$1:$2:$3',
          );
      return DateTime.parse(timestamp);
    } catch (_) {
      return null;
    }
  }
```

- [ ] **Step 4: 改内部调用复用该函数**

把 `data_sync.dart:420-437` 的内联解析块替换为：
```dart
      // If mtime is null, try to extract from filename (kelivo_/sakrylle_ prefix).
      if (mtime == null) {
        mtime = parseBackupTimestamp(name);
      }
```

- [ ] **Step 5: 运行确认通过**

Run: `flutter test test/core/services/backup/backup_prefix_compat_test.dart`
Expected: PASS（3 个用例）。

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/backup/data_sync.dart test/core/services/backup/backup_prefix_compat_test.dart
git commit -m "feat(backup): dual-prefix backup filename timestamp parsing (kelivo+sakrylle)"
```

## Task 11: 备份新写命名 / 临时清理 / S3 manifest 双读 / 默认值改名

**Files:**
- Modify: `lib/core/services/backup/data_sync.dart:123,126,214,217`
- Modify: `lib/core/services/backup/s3_client.dart:13,88`（manifest 双读）
- Modify: `lib/core/models/backup.dart`（默认值）
- Modify: backup UI 占位符/默认值：`lib/features/backup/pages/backup_page.dart`、`lib/desktop/setting/backup_pane.dart`

- [ ] **Step 1: 新备份文件名改前缀**

`data_sync.dart:123` `'kelivo_backup_$timestamp'` → `'sakrylle_backup_$timestamp'`；`:126` `'kelivo_backup_$timestamp.zip'` → `'sakrylle_backup_$timestamp.zip'`。

- [ ] **Step 2: 临时清理识别两套前缀**

`data_sync.dart:214,217` `_cleanupPreviousBackupTempFiles` 内：把 `name.startsWith('kelivo_backup_')` 改为同时识别两前缀，例：
```dart
        final isBackupDir = name.startsWith('kelivo_backup_') ||
            name.startsWith('sakrylle_backup_');
        final isBackupZip = (name.startsWith('kelivo_backup_') ||
                name.startsWith('sakrylle_backup_')) &&
            name.endsWith('.zip');
        if (ent is Directory && isBackupDir) {
          await _deleteDirectoryQuietly(ent);
        } else if (ent is File &&
            (isBackupZip ||
                name == '_bk_settings.json' ||
                name == '_bk_chats.json')) {
          await _deleteFileQuietly(ent);
        }
```

- [ ] **Step 3: S3 manifest 双读**

`s3_client.dart:13` 把单常量替换为新旧两个：
```dart
  static const String _manifestObjectName = '.sakrylle_backups_manifest.json';
  static const String _legacyManifestObjectName = '.kelivo_backups_manifest.json';
```
在 `_manifestKey`（行 87-89）下方新增 legacy key 构造：
```dart
  static String _legacyManifestKey(S3Config cfg) {
    return '${_normalizePrefix(cfg.prefix)}$_legacyManifestObjectName';
```
（注意补全闭合大括号 `}`。）
在 `_readManifest`（行 528-534）把开头的单次 GET 改为「新名缺失则回落旧名」：
```dart
  Future<List<BackupFileItem>?> _readManifest(S3Config cfg) async {
    var res = await _sendSigned(
      cfg,
      method: 'GET',
      uri: _buildObjectUri(cfg, _manifestKey(cfg)),
      headers: {'accept': 'application/json'},
    );
    if (_isMissingObjectResponse(res)) {
      // Fall back to the legacy Kelivo manifest for pre-rebrand backups.
      res = await _sendSigned(
        cfg,
        method: 'GET',
        uri: _buildObjectUri(cfg, _legacyManifestKey(cfg)),
        headers: {'accept': 'application/json'},
      );
      if (_isMissingObjectResponse(res)) return null;
    }
    // (其余 status / decode / items 解析逻辑不变)
```
写入路径 `_writeManifest` 不变（始终写新名 `_manifestObjectName`）。

- [ ] **Step 4: 默认值改名（forward-only，安全）**

`lib/core/models/backup.dart`：`WebDavConfig.path` 默认（行 20、59）与 `S3Config.prefix` 默认（行 99、156）`'kelivo_backups'` → `'sakrylle_backups'`。
> 安全性：`cfg.path`/`cfg.prefix` 按用户持久化，老用户配置已存旧值不受影响；仅新装机用新默认。同一文件夹内列举返回所有 `.zip`，新旧备份都可见、可恢复（依赖 Task 10 的双前缀解析）。

- [ ] **Step 5: UI 占位符/默认显示改名**

把 `lib/features/backup/pages/backup_page.dart` 与 `lib/desktop/setting/backup_pane.dart` 中作为占位符/默认值的字面量 `'kelivo_backups'` 改为 `'sakrylle_backups'`（这些是 hint/默认填充，不影响已存配置）。

- [ ] **Step 6: 分析 + 全量备份测试**

Run: `flutter analyze lib/core/services/backup lib/core/models/backup.dart lib/features/backup lib/desktop/setting/backup_pane.dart`
Expected: No issues.
Run: `flutter test test/core/services/backup/`
Expected: All pass。若 `s3_bucket_list_fallback_test.dart` 等用例断言旧 `kelivo_backups` 路径，确认其作为「读旧前缀」场景仍应通过；如断言新写前缀，更新为 `sakrylle_backup_*`。

- [ ] **Step 7: Commit**

```bash
git add lib/core/services/backup lib/core/models/backup.dart lib/features/backup lib/desktop/setting/backup_pane.dart
git commit -m "feat(backup): write sakrylle_* backups, dual-read legacy kelivo_* + manifest fallback"
```

## Phase 2 收尾验证

- [ ] Run: `flutter analyze` → Expected: No issues.
- [ ] Run: `flutter test` → Expected: All pass.
- [ ] Run: `flutter build macos --debug` → Expected: 成功（覆盖 autosave 迁移编译）。

---

# Phase 3 — OIDC：Windows/Linux loopback + scope 对齐 + 文档同步

> 对应 spec §3。代码可独立交付；真实登录联调依赖中心注册 `sakrylle-chat` client（门禁）。

## Task 12: shouldUseLoopback 纯函数 + 测试

**Files:**
- Modify: `lib/core/services/auth/sakrylle_oauth_service.dart`（新增顶层函数）
- Create: `test/core/services/auth/loopback_platform_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakrylle_chat/core/services/auth/sakrylle_oauth_service.dart';

void main() {
  group('shouldUseLoopback', () {
    test('windows/linux use loopback', () {
      expect(shouldUseLoopback(TargetPlatform.windows), isTrue);
      expect(shouldUseLoopback(TargetPlatform.linux), isTrue);
    });
    test('mobile/macos use custom scheme', () {
      expect(shouldUseLoopback(TargetPlatform.android), isFalse);
      expect(shouldUseLoopback(TargetPlatform.iOS), isFalse);
      expect(shouldUseLoopback(TargetPlatform.macOS), isFalse);
    });
    test('web never uses loopback', () {
      expect(shouldUseLoopback(TargetPlatform.windows, isWeb: true), isFalse);
    });
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/services/auth/loopback_platform_test.dart`
Expected: FAIL（`shouldUseLoopback` 未定义）。

- [ ] **Step 3: 新增顶层函数**

在 `sakrylle_oauth_service.dart` 顶层（class 外、import 之后）新增：
```dart
/// Whether OAuth should use a loopback HTTP redirect (desktop) instead of a
/// custom URL scheme. Web never uses loopback; mobile and macOS keep the
/// existing `sakrylle-chat://` custom scheme.
bool shouldUseLoopback(TargetPlatform platform, {bool isWeb = false}) {
  if (isWeb) return false;
  return platform == TargetPlatform.windows || platform == TargetPlatform.linux;
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/core/services/auth/loopback_platform_test.dart`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/auth/sakrylle_oauth_service.dart test/core/services/auth/loopback_platform_test.dart
git commit -m "feat(oauth): add shouldUseLoopback platform helper"
```

## Task 13: loopback 回调服务（条件导入，保 web 构建）+ 测试

**Files:**
- Create: `lib/core/services/auth/loopback_redirect_server.dart`（dart:io 实现）
- Create: `lib/core/services/auth/loopback_redirect_server_stub.dart`（web stub）
- Create: `test/core/services/auth/loopback_redirect_server_test.dart`

说明：`sakrylle_oauth_service.dart` 不能直接 `import 'dart:io'`（破坏 web 构建），故 HttpServer 逻辑放独立文件，由条件导入选择实现。

- [ ] **Step 1: 写失败测试（io 实现，flutter test 跑在 VM 上有 dart:io）**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sakrylle_chat/core/services/auth/loopback_redirect_server.dart';

void main() {
  test('loopback server resolves with the full callback uri', () async {
    final cb = await startLoopbackServer();
    expect(cb.redirectUri, startsWith('http://127.0.0.1:'));
    expect(cb.redirectUri, endsWith('/callback'));

    // Simulate the browser redirect hitting the loopback callback.
    final res = await http.get(Uri.parse('${cb.redirectUri}?code=abc&state=xyz'));
    expect(res.statusCode, 200);

    final uri = await cb.future;
    expect(uri.queryParameters['code'], 'abc');
    expect(uri.queryParameters['state'], 'xyz');
    await cb.close();
  });

  test('loopback server times out and closes', () async {
    final cb = await startLoopbackServer(timeout: const Duration(milliseconds: 200));
    expect(() => cb.future, throwsA(isA<Exception>()));
    await cb.close();
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/services/auth/loopback_redirect_server_test.dart`
Expected: FAIL（库未定义）。

- [ ] **Step 3: io 实现**

`lib/core/services/auth/loopback_redirect_server.dart`：
```dart
import 'dart:async';
import 'dart:io';

/// Handle to a one-shot loopback OAuth redirect server.
class LoopbackCallback {
  LoopbackCallback({
    required this.redirectUri,
    required this.future,
    required this.close,
  });

  /// The redirect_uri the authorization request must use (with bound port).
  final String redirectUri;

  /// Resolves with the full callback [Uri] (query contains code/state/error),
  /// or throws on timeout.
  final Future<Uri> future;

  /// Shut down the underlying server.
  final Future<void> Function() close;
}

/// Bind an ephemeral loopback server and wait for a single `/callback` request.
Future<LoopbackCallback> startLoopbackServer({
  Duration timeout = const Duration(minutes: 5),
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final completer = Completer<Uri>();

  server.listen((HttpRequest request) async {
    if (request.uri.path != '/callback') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(
        '<!doctype html><html><head><meta charset="utf-8"></head>'
        '<body style="font-family:sans-serif;text-align:center;padding-top:3rem">'
        '<h2>登录成功，可关闭此窗口</h2><p>You may close this window.</p>'
        '</body></html>',
      );
    await request.response.close();
    if (!completer.isCompleted) completer.complete(request.uri);
  });

  return LoopbackCallback(
    redirectUri: 'http://127.0.0.1:${server.port}/callback',
    future: completer.future.timeout(timeout),
    close: () async {
      await server.close(force: true);
    },
  );
}
```

- [ ] **Step 4: web stub**

`lib/core/services/auth/loopback_redirect_server_stub.dart`：
```dart
import 'dart:async';

/// Web stub: loopback OAuth is never used on web ([shouldUseLoopback] is false).
class LoopbackCallback {
  LoopbackCallback({
    required this.redirectUri,
    required this.future,
    required this.close,
  });

  final String redirectUri;
  final Future<Uri> future;
  final Future<void> Function() close;
}

Future<LoopbackCallback> startLoopbackServer({
  Duration timeout = const Duration(minutes: 5),
}) {
  throw UnsupportedError('Loopback OAuth is not supported on this platform.');
}
```

- [ ] **Step 5: 运行确认通过**

Run: `flutter test test/core/services/auth/loopback_redirect_server_test.dart`
Expected: PASS（2 个用例）。

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/auth/loopback_redirect_server.dart lib/core/services/auth/loopback_redirect_server_stub.dart test/core/services/auth/loopback_redirect_server_test.dart
git commit -m "feat(oauth): add loopback redirect server (io impl + web stub)"
```

## Task 14: authorize() 双路径 + redirect_uri 串联改造

**Files:**
- Modify: `lib/core/services/auth/sakrylle_oauth_service.dart`

- [ ] **Step 1: 加条件导入与依赖**

在 import 区加入（`http` 之后）：
```dart
import 'package:url_launcher/url_launcher.dart';

import 'loopback_redirect_server_stub.dart'
    if (dart.library.io) 'loopback_redirect_server.dart';
```

- [ ] **Step 2: 把 `_redirectUri` 改为自定义 scheme 常量**

把 `static String get _redirectUri { ... }`（行 28-32）替换为：
```dart
  static const String _customSchemeRedirectUri =
      'sakrylle-chat://oauth/callback';
```

- [ ] **Step 3: 改写 authorize() 为双路径**

把现有 `authorize()`（行 82-126）替换为：
```dart
  /// Start the OAuth authorization flow.
  Future<OAuthTokens> authorize() async {
    final pkce = _generatePkce();
    final state = _generateState();
    final nonce = _generateState();
    final config = await _idTokenValidator.configuration;

    if (shouldUseLoopback(defaultTargetPlatform, isWeb: kIsWeb)) {
      return _authorizeLoopback(config, pkce, state, nonce);
    }
    return _authorizeCustomScheme(config, pkce, state, nonce);
  }

  Future<OAuthTokens> _authorizeCustomScheme(
    OidcConfiguration config,
    ({String verifier, String challenge}) pkce,
    String state,
    String nonce,
  ) async {
    final authUrl = _buildAuthUrl(
      authorizationEndpoint: config.authorizationEndpoint,
      redirectUri: _customSchemeRedirectUri,
      codeChallenge: pkce.challenge,
      state: state,
      nonce: nonce,
    );
    debugPrint('[OAuth] Starting Sakrylle authorize flow (custom scheme)');
    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: 'sakrylle-chat',
    );
    return _completeAuthorization(
      Uri.parse(result),
      state: state,
      verifier: pkce.verifier,
      nonce: nonce,
      redirectUri: _customSchemeRedirectUri,
    );
  }

  Future<OAuthTokens> _authorizeLoopback(
    OidcConfiguration config,
    ({String verifier, String challenge}) pkce,
    String state,
    String nonce,
  ) async {
    final cb = await startLoopbackServer();
    try {
      final authUrl = _buildAuthUrl(
        authorizationEndpoint: config.authorizationEndpoint,
        redirectUri: cb.redirectUri,
        codeChallenge: pkce.challenge,
        state: state,
        nonce: nonce,
      );
      debugPrint('[OAuth] Starting Sakrylle authorize flow (loopback)');
      final launched = await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('Failed to open system browser for OAuth');
      }
      final callbackUri = await cb.future;
      return _completeAuthorization(
        callbackUri,
        state: state,
        verifier: pkce.verifier,
        nonce: nonce,
        redirectUri: cb.redirectUri,
      );
    } finally {
      await cb.close();
    }
  }

  Future<OAuthTokens> _completeAuthorization(
    Uri uri, {
    required String state,
    required String verifier,
    required String nonce,
    required String redirectUri,
  }) async {
    if (uri.queryParameters['state'] != state) {
      throw Exception('OAuth state mismatch: possible CSRF attack');
    }
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      final error = uri.queryParameters['error'] ?? 'unknown';
      throw Exception('OAuth authorization failed: $error');
    }
    final tokens = await exchangeCode(
      code,
      verifier,
      redirectUri: redirectUri,
      expectedNonce: nonce,
    );
    await _storeTokens(tokens);
    debugPrint('[OAuth] Sakrylle authorize flow completed');
    return tokens;
  }
```

- [ ] **Step 4: `exchangeCode` 增加 redirectUri 参数**

把 `exchangeCode` 签名（行 129-133）改为：
```dart
  Future<OAuthTokens> exchangeCode(
    String code,
    String verifier, {
    required String redirectUri,
    String? expectedNonce,
  }) async {
```
并把其 body 中 `'redirect_uri': _redirectUri,` 改为 `'redirect_uri': redirectUri,`。

- [ ] **Step 5: `_buildAuthUrl` 增加 redirectUri 参数**

把 `_buildAuthUrl` 签名（行 255-260）加入 `required String redirectUri`，并把 body 内 `'redirect_uri': _redirectUri,` 改为 `'redirect_uri': redirectUri,`。

- [ ] **Step 6: 分析**

Run: `flutter analyze lib/core/services/auth/sakrylle_oauth_service.dart`
Expected: No issues（确认无残留 `_redirectUri` 引用）。

- [ ] **Step 7: 全量 auth 测试 + web 构建守卫**

Run: `flutter test test/core/services/auth/`
Expected: All pass。
Run: `flutter build web --no-pub` （确认条件导入未破坏 web 构建）
Expected: 构建成功（web 走 stub）。

- [ ] **Step 8: Commit**

```bash
git add lib/core/services/auth/sakrylle_oauth_service.dart
git commit -m "feat(oauth): branch authorize() into loopback (desktop) and custom-scheme paths"
```

## Task 15: scope 审计 + 中心文档同步 + 注册请求清单 + 本地 oidc-docs 更新

**Files:**
- Modify: `lib/core/services/auth/sakrylle_oauth_service.dart:25-26`（仅当审计结论需调整）
- Modify: `/Users/cervine/Documents/Sakrylle/Sakrylle API/sakrylle-docs/10-platform-identity/rp-integration-guide.md`
- Modify: `oidc-docs/local-integration.md`、`oidc-docs/implementation-status.md`、`oidc-docs/troubleshooting.md`
- Create: `oidc-docs/sakrylle-chat-client-registration-request.md`

- [ ] **Step 1: 审计 Chat 实际调用的 /v1 端点**

Run: `rg -n "/v1/|chat/completions|/models|/user/balance" lib/core/services/api lib/core/providers/settings_provider.dart`
据结果列出 Chat 调用的端点集合，推导所需 scope。确认 `_scopes`（`openid profile email models:read chat.completions:create offline_access`）是否覆盖且每个 scope 在中心矩阵存在。若需调整，改 `sakrylle_oauth_service.dart:25-26` 并在注册请求中以此为准。

- [ ] **Step 2: 更新中心 rp-integration-guide.md 的 sakrylle-chat 目标配置**

在 `sakrylle-chat` client 配置处，`redirect_uris` 增列 `http://127.0.0.1`（loopback，端口无关），并写明最终 scope。新增一行显式说明：**redirect 匹配须对 `127.0.0.1` 按 RFC 8252 做端口无关匹配**。

- [ ] **Step 3: 创建注册请求清单**

`oidc-docs/sakrylle-chat-client-registration-request.md`，内容包含：
```markdown
# sakrylle-chat OIDC Client 注册请求

- client_id: sakrylle-chat
- client_type: public（无 client_secret）
- grant_types: [authorization_code, refresh_token]
- redirect_uris:
  - sakrylle-chat://oauth/callback   （Android / iOS / macOS 自定义 scheme）
  - http://127.0.0.1                 （Windows / Linux loopback，端口无关）
- scope: <Step 1 审计后的最终集合>
- logout_redirect_uris: <如启用 RP-Initiated Logout 跳转则填>

## 需中心平台确认
1. redirect 匹配是否对 http://127.0.0.1 做 RFC 8252 端口无关匹配？
   若否，需约定固定端口并在此注册。
2. allowed_scopes 是否覆盖上述 scope（scope enforcement 已开启）？
```

- [ ] **Step 4: 同步本地 oidc-docs 状态**

`oidc-docs/implementation-status.md`、`local-integration.md`、`troubleshooting.md`：把 Windows/Linux OAuth callback 由「未验证」更新为「已实现 loopback，待中心注册后门禁验收」；记录 loopback redirect、端口无关匹配待确认项。

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/auth/sakrylle_oauth_service.dart oidc-docs/
git commit -m "docs(oidc): align scope, document loopback redirect, add client registration request"
```
中心文档单独提交（不同仓库）：
```bash
git -C "/Users/cervine/Documents/Sakrylle/Sakrylle API" add sakrylle-docs/10-platform-identity/rp-integration-guide.md
git -C "/Users/cervine/Documents/Sakrylle/Sakrylle API" commit -m "docs(rp): sakrylle-chat add loopback redirect and finalize scope"
```

## Phase 3 收尾验证

- [ ] Run: `flutter analyze` → Expected: No issues.
- [ ] Run: `flutter test` → Expected: All pass.
- [ ] Run: `flutter build macos --debug` → Expected: 成功。
- [ ] 平台边界声明：Windows/Linux loopback 真实浏览器往返**未在本机验证**，记入交付说明。

## 门禁验收 checklist（待中心注册 `sakrylle-chat` 后执行，不阻塞代码合入）

- [ ] Android / iOS / macOS / Windows / Linux 各跑真实登录：login → refresh → revoke/logout → profile 映射。
- [ ] 验证日志不打印 auth code / token / callback URL / authorization URL / token 响应。
- [ ] 确认 token 仅存平台安全存储（无 SharedPreferences 回落）。
- [ ] Windows/Linux 确认中心对 `127.0.0.1` 端口无关匹配生效。

---

## 自检与交付说明要点

- ARB 未触及（品牌名硬编码于 `main.dart`，loopback HTML 非 AppLocalizations），无需 `flutter gen-l10n`。
- 桌面边界：本机仅能验证 macOS；Windows/Linux loopback 真实往返与构建未覆盖，须显式声明。
- 兼容性：备份 `cfg.path` 按用户持久化、双前缀解析 + manifest 回落保旧备份可读；通知渠道删旧建新（用户旧渠道个性化丢失，可接受）；macOS autosave 一次性无损迁移；字体别名运行时重注册无需迁移。
- 保留项：`kelivo_fetch`、`KelivoIN`、`brand_assets` 映射、`sandbox_path_resolver` 旧路径、备份读旧前缀——均为兼容性必需。
