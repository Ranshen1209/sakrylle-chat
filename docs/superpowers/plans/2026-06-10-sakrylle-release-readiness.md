# Sakrylle 发布就绪 + 品牌 token 重构 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 web 构建、完成发布就绪收尾、按 design.md 在主题层落地品牌 token，使 Sakrylle Chat 达到可发布状态。

**Architecture:** 三条独立、可分别交付的 track。Track W 修两个确定性 web 编译错误并迭代到 `flutter build web` 绿；Track R 生成 `.ico`、清理 CI `--fatal-infos` 弃用（带 Flutter 版本护栏）、补平台构建验证门禁；Track B 扩展现有 `AppRadii`/`AppSpacing`、经共享 helper 接入 4 个主题构建器、共享 iOS 原语引用 token、Monet Purple 色板对比度、无障碍、货币助手。

**Tech Stack:** Flutter 3.44.1 / Dart、Material 3、`dynamic_color`、`image: ^4.8.0`（ICO 生成）、`dart:ui_web`、`BigInt`。

**Spec:** `docs/superpowers/specs/2026-06-10-sakrylle-release-readiness-design.md`

**约定**：命令在仓库根 `/Users/cervine/Documents/Sakrylle/Sakrylle Chat` 执行。分支 `feat/sakrylle-migration-completion`。本机仅能验证 macOS / web 构建与 `flutter test`/`analyze`；Windows/Linux/iOS 为门禁。

---

# Phase W — 修复 web 构建

## Task W1: avatar_cache int64 → BigInt

**Files:**
- Modify: `lib/utils/avatar_cache.dart:18-38`（`_safeName` 方法）

- [ ] **Step 1: 改 `_safeName` 的哈希为 BigInt**

把 `_safeName`（行 18-38）中的整型 FNV-1a 替换为 BigInt 实现（保留 ext 提取逻辑不变）：
```dart
  static String _safeName(String url) {
    // 64-bit FNV-1a using BigInt so the literals are representable on web (JS).
    BigInt h = BigInt.parse('cbf29ce484222325', radix: 16); // FNV offset basis
    final BigInt prime = BigInt.parse('100000001b3', radix: 16); // FNV prime
    final BigInt mask = BigInt.parse('FFFFFFFFFFFFFFFF', radix: 16);
    for (final c in url.codeUnits) {
      h = (h ^ BigInt.from(c));
      h = (h * prime) & mask; // keep 64-bit
    }
    final hex = h.toRadixString(16).padLeft(16, '0');
    final uri = Uri.tryParse(url);
    String ext = 'img';
    if (uri != null) {
      final seg = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last.toLowerCase()
          : '';
      final m = RegExp(r"\.(png|jpg|jpeg|webp|gif|bmp|ico)").firstMatch(seg);
      if (m != null) ext = m.group(1)!;
    }
    return 'av_$hex.$ext';
  }
```

- [ ] **Step 2: 分析该文件**

Run: `flutter analyze lib/utils/avatar_cache.dart`
Expected: No issues（行 20/24 的 int64 字面量报错消失）。

- [ ] **Step 3: Commit**

```bash
git add lib/utils/avatar_cache.dart
git commit -m "fix(web): use BigInt for avatar cache hash so literals compile on web"
```

## Task W2: mermaid platformViewRegistry → dart:ui_web

**Files:**
- Modify: `lib/shared/widgets/mermaid_bridge_web.dart:6,58`

- [ ] **Step 1: 加 dart:ui_web 导入**

在 import 区（约行 6，`import 'dart:ui' as ui;` 附近）新增：
```dart
import 'dart:ui_web' as ui_web; // ignore: uri_does_not_exist
```
保留现有 `import 'dart:ui' as ui;`（文件其它处可能仍用 `ui`，若 analyze 报 `ui` 未使用再移除）。

- [ ] **Step 2: 改用 ui_web.platformViewRegistry**

把行 57-58：
```dart
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(viewType, (int id) => container);
```
替换为：
```dart
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int id) => container);
```

- [ ] **Step 3: 分析**

Run: `flutter analyze lib/shared/widgets/mermaid_bridge_web.dart`
Expected: No new issues（`platformViewRegistry` 未定义错误消失；若 `ui` 变未使用则一并删除其 import）。

- [ ] **Step 4: Commit**

```bash
git add lib/shared/widgets/mermaid_bridge_web.dart
git commit -m "fix(web): use dart:ui_web platformViewRegistry for mermaid view factory"
```

## Task W3: 迭代到 `flutter build web` 绿

**Files:**
- 视迭代而定（可能涉及 `lib/utils/avatar_cache.dart` 的 `dart:io` 隔离）

- [ ] **Step 1: 构建 web**

Run: `flutter build web`
Expected: 可能仍失败。捕获错误：`flutter build web 2>&1 | grep -iE "error|\.dart:[0-9]"`。

- [ ] **Step 2: 逐个解决新暴露的错误（最可能：avatar_cache 的 dart:io 在 web 不可用）**

若报 `avatar_cache.dart` 的 `dart:io`（`Directory`/`File`）在 web 不可用：用条件导入隔离原生实现。做法：
- 把 `avatar_cache.dart` 拆为接口 + 条件实现：
  - `lib/utils/avatar_cache.dart`（公共 API，不直接 import dart:io；用条件导入选择实现）
  - `lib/utils/avatar_cache_io.dart`（现有 dart:io 实现）
  - `lib/utils/avatar_cache_stub.dart`（web stub：`ensureCached` 等直接返回 null / 原 url，`_safeName` 可保留纯 Dart 版）
  - 条件导入：`import 'avatar_cache_stub.dart' if (dart.library.io) 'avatar_cache_io.dart';`
- 仅当 Step 1 确实因 dart:io 失败才做此拆分；若 Step 1 已绿则跳过本步。
- 其它新错误同理：定位 → 用条件导入/web stub 隔离原生依赖，或修正 API，直至构建通过。

- [ ] **Step 3: 验证 web 构建成功**

Run: `flutter build web`
Expected: 退出码 0，输出 `✓ Built build/web`。
Run: `flutter analyze lib`
Expected: 不因本 Phase 引入新问题（既有 deprecation 由 Phase R 处理）。

- [ ] **Step 4: Commit（如 Step 2 有改动）**

```bash
git add lib/utils/
git commit -m "fix(web): isolate native-only avatar cache via conditional import for web build"
```

## Phase W 收尾验证

- [ ] Run: `flutter build web` → Expected: 成功。
- [ ] Run: `flutter test test/` 中与 avatar_cache 相关的（若有）→ Expected: pass。若拆分了 avatar_cache，手动确认原生路径行为不变。

---

# Phase R — 发布就绪收尾

## Task R1: 由 sakrylle_icon.png 生成 app_icon.ico

**Files:**
- Create: `tool/generate_ico.dart`（一次性脚本）
- Modify（生成产物）: `assets/app_icon.ico`

- [ ] **Step 1: 写生成脚本**

`tool/generate_ico.dart`：
```dart
// One-off: regenerate assets/app_icon.ico from assets/sakrylle_icon.png.
// Run: dart run tool/generate_ico.dart
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('assets/sakrylle_icon.png').readAsBytesSync());
  if (src == null) {
    stderr.writeln('Failed to decode assets/sakrylle_icon.png');
    exit(1);
  }
  // Build multi-size ICO if supported; fall back to single 256 if API differs.
  final sizes = [256, 128, 64, 48, 32, 16];
  final images = [
    for (final s in sizes)
      img.copyResize(src, width: s, height: s, interpolation: img.Interpolation.average),
  ];
  List<int> bytes;
  try {
    bytes = img.encodeIcoImages(images); // multi-size (image 4.x)
  } catch (_) {
    bytes = img.encodeIco(images.first); // single 256 fallback
  }
  File('assets/app_icon.ico').writeAsBytesSync(bytes);
  stdout.writeln('Wrote assets/app_icon.ico (${bytes.length} bytes)');
}
```

- [ ] **Step 2: 运行脚本**

Run: `dart run tool/generate_ico.dart`
Expected: 输出 `Wrote assets/app_icon.ico (<N> bytes)`。
若 `encodeIcoImages`/`encodeIco` 在安装的 `image` 版本不存在（编译报错）：改用该版本实际提供的 ICO 编码 API（`dart pub deps` / 查 `image` 包导出）；若 `image` 无 ICO 编码，删除脚本并改走回退——用 ImageMagick 或在线工具从 `assets/sakrylle_icon.png` 生成 `.ico`，作为门禁项在交付说明记录，跳到 Step 4。

- [ ] **Step 3: 校验 ICO 有效**

Run: `file assets/app_icon.ico`
Expected: 识别为 `MS Windows icon resource`，含一个或多个尺寸。

- [ ] **Step 4: Commit**

```bash
git add tool/generate_ico.dart assets/app_icon.ico
git commit -m "chore(brand): regenerate app_icon.ico from Sakrylle icon"
```
（若走了回退人工生成，仅 `git add assets/app_icon.ico` 并在 message 注明工具。）

## Task R2: 清理 `--fatal-infos` 弃用（带版本护栏）

**Files:**
- Modify: `flutter analyze` 实际标记的 deprecated 站点（见下）

> **护栏**：本机 Flutter 3.44.1 已含替代 API（`ReorderableListView.onReorderItem`、`SizeTransition.alignment`）。若仓库 CI 用更旧 Flutter 且无这些 API，本任务降级为「记录待升级」，不强改。实现前用 `flutter --version` 确认与 CI 一致或更新。

- [ ] **Step 1: 取得 analyze 实际标记的弃用站点（不要盲改所有 onReorder:）**

Run: `flutter analyze lib 2>&1 | grep deprecated_member_use`
记录每条的 `file:line` 与成员名。**只改这些被标记的站点**——仓库中有自定义 widget 也叫 `onReorder:`（非 Flutter 弃用 API），不可一并替换。

- [ ] **Step 2: 迁移每个被标记的 `onReorder` → `onReorderItem`（移除 -1 调整）**

迁移配方（`onReorderItem` 的 `newIndex` 已是调整后的值，故删除手动 `-1`）。以 `lib/features/quick_phrase/pages/quick_phrases_page.dart:156` 为例：

之前：
```dart
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                context.read<QuickPhraseProvider>().reorderPhrases(
                  oldIndex: oldIndex,
                  newIndex: newIndex,
                  assistantId: widget.assistantId,
                );
              },
```
之后：
```dart
              onReorderItem: (oldIndex, newIndex) {
                context.read<QuickPhraseProvider>().reorderPhrases(
                  oldIndex: oldIndex,
                  newIndex: newIndex,
                  assistantId: widget.assistantId,
                );
              },
```
要点：① 命名参数 `onReorder:` → `onReorderItem:`；② 删除回调体内 `if (newIndex > oldIndex) newIndex -= 1;`（若存在）；③ 若该回调没有 `-1` 调整（直接用 newIndex），则迁移后行为会 off-by-one，需核对该处原逻辑——多数 Flutter `onReorder` 用法都含 `-1`，无 `-1` 的要单独判断是否本就有 bug。
对于方法引用形式（如 `onReorder: _reorder` 见 `assistant_regex_tab.dart`）：把 `_reorder` 重命名/改造为不含 `-1` 调整的版本并改用 `onReorderItem: _reorder`；若 `_reorder` 被多处共享，新增 `_reorderItem` 不含调整版供 `onReorderItem` 用。
对于条件形式（如 `providers_page.dart:816` `onReorder: reorderEnabled ? onReorder : (_, __){}`）：改为 `onReorderItem:`，并确保所引 `onReorder` 回调已去除 `-1`。
**逐个 analyze-标记站点处理**（依 Step 1 清单），改完一个保持可编译。

- [ ] **Step 3: 迁移 `axisAlignment` → `alignment`（2 处）**

`lib/shared/widgets/markdown_with_highlight.dart:4864` 与 `lib/features/chat/widgets/chat_message_widget.dart:2446`，均为 `axisAlignment: -1`（`SizeTransition`）。
先确认各处 `SizeTransition` 的 `axis`（默认 `Axis.vertical`）。按 Flutter 官方迁移配方：
- `axis: Axis.vertical`（或默认）：`axisAlignment: -1` → `alignment: const Alignment(-1.0, -1.0)`
- `axis: Axis.horizontal`：`axisAlignment: -1` → `alignment: const Alignment(-1.0, -1.0)`（horizontal 配方 `Alignment(axisAlignment, -1.0)` = `Alignment(-1.0, -1.0)`）
两处都把 `axisAlignment: -1,` 行替换为 `alignment: const Alignment(-1.0, -1.0),`（两 axis 在 `axisAlignment:-1` 下结果相同）。

- [ ] **Step 4: 验证零弃用 + 重排行为**

Run: `dart analyze --fatal-infos lib test`
Expected: No issues（或仅剩「CI 版本不匹配、已记录」的项；若全清则更好）。
Run: `flutter test test/features/quick_phrase test/features/assistant test/features/provider test/features/world_book test/features/home 2>&1 | tail -5`（覆盖含可重排列表的页面相关测试，存在哪些跑哪些）
Expected: pass。对无自动化测试的可重排页面，在交付说明标注需手动验证重排正确（拖拽后顺序符合预期、无 off-by-one）。

- [ ] **Step 5: Commit**

```bash
git add lib/
git commit -m "fix: migrate deprecated onReorder->onReorderItem and axisAlignment->alignment"
```

## Task R3: 平台构建验证门禁清单

**Files:**
- Modify: `docs/superpowers/specs/2026-06-10-sakrylle-release-readiness-design.md`（在 §6 追加门禁结果）或交付说明

- [ ] **Step 1: 本机可做的验证**

Run: `flutter build macos --debug` → Expected: 成功。
Run: `flutter build web` → Expected: 成功（Phase W 已修）。

- [ ] **Step 2: 记录门禁项**

在交付说明列出无法本机验证的平台与命令，供 CI/他人执行：
```
- Windows: flutter build windows --release   （验证 .ico、窗口标题、loopback、token 主题）
- Linux:   flutter build linux --release      （验证窗口标题/图标、loopback、token 主题）
- iOS:     flutter build ios --release --no-codesign （验证 LiveActivity 改名、token 主题）
```
本步无代码改动，仅交付说明。无需 commit（若写入 docs 则 commit）。

## Phase R 收尾验证

- [ ] Run: `dart analyze --fatal-infos lib test` → Expected: 通过或仅剩已记录项。
- [ ] Run: `flutter build macos --debug` → Expected: 成功。

---

# Phase B — 品牌 token 主题层全量重构

## Task B1: 扩展 AppRadii / AppSpacing + 新增 SakrylleColors

**Files:**
- Modify: `lib/theme/design_tokens.dart`

- [ ] **Step 1: 扩展 token 类（保留既有值避免回归）**

在 `lib/theme/design_tokens.dart` 中：
`AppRadii` 改为：
```dart
class AppRadii {
  static const double capsule = 28; // 既有，保留
  static const double sm = 12;      // 按钮/输入框
  static const double md = 16;      // 卡片/模态
  static const double full = 999;   // 徽章/开关/头像
}
```
`AppSpacing` 新增 `xl`（其余保留）：
```dart
class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20; // 既有，保留（不改为 24，避免现有布局回归）
  static const double xl = 32;  // 新增
}
```
文件末尾新增 `SakrylleColors`（需 `import 'package:flutter/material.dart';` 已在文件顶部）：
```dart
class SakrylleColors {
  static const Color monetPurple = Color(0xFF9181BD);     // primary-500
  static const Color monetPurpleDark = Color(0xFF7B6AAB); // primary-600
  static const Color primary700 = Color(0xFF5E4F86);      // 待对比度校验
  static const Color sakura = Color(0xFFEC6A9C);          // accent
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF9181BD);
}
```

- [ ] **Step 2: 分析**

Run: `flutter analyze lib/theme/design_tokens.dart`
Expected: No issues。

- [ ] **Step 3: Commit**

```bash
git add lib/theme/design_tokens.dart
git commit -m "feat(theme): extend AppRadii/AppSpacing and add SakrylleColors tokens"
```

## Task B2: 共享组件主题 helper + 接入 4 个构建器

**Files:**
- Modify: `lib/theme/theme_factory.dart`

- [ ] **Step 1: 新增共享组件主题 helper**

在 `theme_factory.dart` 顶部（import 后、构建器前）新增（依赖 `AppRadii`，需 `import 'design_tokens.dart';`，确认已导入或添加）：
```dart
// Shared Sakrylle component shapes (radius tokens) applied across all theme builders.
ThemeData _withSakrylleShapes(ThemeData base) {
  final RoundedRectangleBorder cardShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md));
  final RoundedRectangleBorder buttonShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm));
  return base.copyWith(
    cardTheme: base.cardTheme.copyWith(shape: cardShape),
    dialogTheme: base.dialogTheme.copyWith(shape: cardShape),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: (base.elevatedButtonTheme.style ?? const ButtonStyle())
          .copyWith(shape: WidgetStatePropertyAll(buttonShape)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: (base.filledButtonTheme.style ?? const ButtonStyle())
          .copyWith(shape: WidgetStatePropertyAll(buttonShape)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: (base.outlinedButtonTheme.style ?? const ButtonStyle())
          .copyWith(shape: WidgetStatePropertyAll(buttonShape)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: (base.textButtonTheme.style ?? const ButtonStyle())
          .copyWith(shape: WidgetStatePropertyAll(buttonShape)),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(shape: const StadiumBorder()),
  );
}
```
版本注意：若该 Flutter 版本用 `MaterialStatePropertyAll`（而非 `WidgetStatePropertyAll`），改用实际可用名；`base.cardTheme`/`dialogTheme`/`chipTheme` 在 Material3 下均为非空的 `*ThemeData`，`.copyWith` 可用。

- [ ] **Step 2: 在 4 个构建器返回前套用 helper**

在 `buildLightTheme`、`buildLightThemeForScheme`、`buildDarkTheme`、`buildDarkThemeForScheme` 各自最终 `return <theme>;` / `return theme.copyWith(...)` 处，用 `_withSakrylleShapes(...)` 包裹返回值。例：`buildLightTheme` 末尾
```dart
  return _withSakrylleShapes(theme.copyWith(
    textTheme: _withFontFallback(theme.textTheme, fontFallback),
    primaryTextTheme: _withFontFallback(theme.primaryTextTheme, fontFallback),
  ));
```
其余 3 个构建器同样在其 return 表达式外层包 `_withSakrylleShapes(...)`。

- [ ] **Step 3: 分析 + macOS 目测**

Run: `flutter analyze lib/theme/theme_factory.dart`
Expected: No issues（修正任何 `cardTheme`/`dialogTheme` 可空性：Material3 中 `base.cardTheme` 非空、`dialogTheme` 为 `DialogThemeData`，用 `.copyWith`）。
Run: `flutter build macos --debug` 后运行，目测卡片/按钮/输入框/对话框圆角符合 token（12/16），无明显错位。

- [ ] **Step 4: Commit**

```bash
git add lib/theme/theme_factory.dart
git commit -m "feat(theme): apply Sakrylle radius tokens to component themes across builders"
```

## Task B3: Monet Purple 色板对比度（primary-700）

**Files:**
- Modify: `lib/theme/palettes.dart`（Monet Purple 色板的 light `ColorScheme`）

- [ ] **Step 1: 定位 Monet Purple 色板**

Run: `rg -n "9181|Monet" lib/theme/palettes.dart`
找到该色板的 `light: ColorScheme(...)` 定义（其 `primary` 为 `#9181BD` 一类）。

- [ ] **Step 2: 校验并调整对比度**

确认「白字 on 现 primary」对比度。若 `< 4.5:1`：把该色板 light scheme 的 `primary` 改为 `SakrylleColors.primary700`（保持 `onPrimary: Color(0xFFFFFFFF)`），使白字达 AA。用对比度公式核验（4.5:1）；`primary700` 起始 `#5E4F86`，不足则继续调暗并更新 `SakrylleColors.primary700`。
仅改 Monet Purple 这一个色板，不动其它色板与动态取色路径。

- [ ] **Step 3: 分析 + 目测**

Run: `flutter analyze lib/theme/palettes.dart` → Expected: No issues。
macOS 运行，切到 Monet Purple 主题，目测填充按钮白字清晰可读。

- [ ] **Step 4: Commit**

```bash
git add lib/theme/palettes.dart lib/theme/design_tokens.dart
git commit -m "feat(theme): meet AA contrast on Monet Purple palette via primary-700"
```

## Task B4: 共享 iOS 原语引用 token

**Files:**
- Modify: `lib/shared/widgets/ios_tactile.dart`、`ios_tile_button.dart`、`ios_form_text_field.dart`、`ios_switch.dart`、`ios_checkbox.dart`、`lib/desktop/widgets/*`

- [ ] **Step 1: 用 token 替换匹配的硬编码圆角**

逐文件 Read，把硬编码圆角按值映射到 token（仅替换值能对上的；off-scale 值如 `circular(8)` 保留或按视觉判断）：
- `BorderRadius.circular(12)` → `BorderRadius.circular(AppRadii.sm)`
- `BorderRadius.circular(16)` → `BorderRadius.circular(AppRadii.md)`
- 全圆/胶囊（如 `StadiumBorder`/`circular(999)`/大半径）→ 维持或用 `AppRadii.full`
例：`ios_tactile.dart:287` `BorderRadius.circular(12)` → `BorderRadius.circular(AppRadii.sm)`；`ios_tactile.dart:141` `circular(8)` 无对应 token，**保留不动**（注明）。
需 `import '../../theme/design_tokens.dart';`（按各文件相对路径）。

- [ ] **Step 2: 分析**

Run: `flutter analyze lib/shared/widgets lib/desktop/widgets`
Expected: No issues。

- [ ] **Step 3: Commit**

```bash
git add lib/shared/widgets lib/desktop/widgets
git commit -m "refactor(theme): shared iOS primitives reference AppRadii tokens"
```

## Task B5: 无障碍 — focus 高亮 + reduced-motion

**Files:**
- Modify: `lib/shared/widgets/ios_tactile.dart`

- [ ] **Step 1: reduced-motion — 缩放动画尊重 disableAnimations**

在 `ios_tactile.dart` 的按压缩放/透明动画处，读取 `MediaQuery.maybeOf(context)?.disableAnimations ?? false`，为 true 时跳过缩放（scale 固定 1.0），仅保留即时反馈。先 Read 确认动画实现位置，再注入该判断。

- [ ] **Step 2: focus — 暴露焦点高亮**

确认 `IosIconButton`/`IosCardPress` 等可交互组件在桌面有焦点指示（若用 `GestureDetector` 无焦点，包一层 `Focus`/`FocusableActionDetector` 或用 `InkWell` 的 focusColor）。补最小焦点高亮（边框/底色变化），不改既有点按行为。

- [ ] **Step 3: 分析 + 目测**

Run: `flutter analyze lib/shared/widgets/ios_tactile.dart` → Expected: No issues。
macOS 运行：Tab 键切焦点可见高亮；系统开启「减弱动态效果」时按压无缩放。

- [ ] **Step 4: Commit**

```bash
git add lib/shared/widgets/ios_tactile.dart
git commit -m "feat(a11y): honor reduced-motion and expose focus highlight in iOS tactile"
```

## Task B6: 货币显示助手（TDD；仅定义 + 按需挂载）

**Files:**
- Create: `lib/utils/display_amount.dart`
- Create: `test/utils/display_amount_test.dart`

- [ ] **Step 1: 写失败测试**

`test/utils/display_amount_test.dart`：
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sakrylle_chat/utils/display_amount.dart';

void main() {
  group('formatDisplayAmount', () {
    test('prefixes full-width yen (U+FFE5) for display-only amounts', () {
      expect(formatDisplayAmount(12.5), '￥12.50');
      expect('￥'.codeUnitAt(0), 0xFFE5); // full-width, not half-width ¥
    });
    test('respects fraction digits', () {
      expect(formatDisplayAmount(3, fractionDigits: 0), '￥3');
    });
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/utils/display_amount_test.dart`
Expected: FAIL（库未定义）。

- [ ] **Step 3: 实现助手**

`lib/utils/display_amount.dart`：
```dart
/// Format a display-only amount with the full-width yen sign (U+FFE5).
///
/// Per Sakrylle brand spec: display-only balances use full-width `￥`;
/// real CNY payment flows use half-width `¥` (U+00A5) — this helper is
/// for the display-only case.
String formatDisplayAmount(num amount, {int fractionDigits = 2}) {
  return '￥${amount.toStringAsFixed(fractionDigits)}';
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/utils/display_amount_test.dart`
Expected: PASS（2 用例）。

- [ ] **Step 5: 按需挂载（仅当存在 Sakrylle 平台余额显示）**

Run: `rg -n "balance" lib/features lib/desktop | grep -iE "Text\(|sakrylle"`
若找到展示 Sakrylle 平台余额的 `Text(...)` 显示点，用 `formatDisplayAmount(value)` 包裹其数值。若**未找到** Sakrylle 余额显示点（当前取证未发现），则**仅定义助手 + 测试**，在 commit message 与交付说明注明「暂无挂载点，助手备用」。不强行给第三方 provider 余额加符号。

- [ ] **Step 6: Commit**

```bash
git add lib/utils/display_amount.dart test/utils/display_amount_test.dart
git commit -m "feat(brand): add full-width yen display-amount helper (mount where applicable)"
```

## Task B7: 字体/字号核对

**Files:**
- Read-only 核对；如发现 <14px 共享文本样式再 Modify

- [ ] **Step 1: 核对字体栈与移动端字号**

Run: `rg -n "fontSize: (1[0-3]|[0-9])\b" lib/shared lib/features/chat/widgets | head`
确认共享组件正文无 <14 的（图标小标签除外）。字体 fallback 已是系统栈（`theme_factory.dart` 的 `kDefaultFontFamilyFallback`），符合 design.md，无需引入 Google Fonts。
若发现共享正文 <14px 且确为正文用途，提升至 ≥14；否则不动（多为 caption/标签，design.md 允许 12px caption）。

- [ ] **Step 2: Commit（仅当有修正）**

```bash
git add lib/
git commit -m "fix(theme): ensure shared body text >= 14px on mobile"
```
（无修正则跳过，交付说明记录「字体栈与字号核对通过，无需改动」。）

## Phase B 收尾验证

- [ ] Run: `flutter analyze lib` → Expected: 不引入新问题。
- [ ] Run: `flutter test` → Expected: 相关测试通过（含新增 display_amount 测试；既有 2 个预存在挂起测试不计）。
- [ ] Run: `flutter build macos --debug` 后运行，目测：按钮/卡片/输入框/对话框圆角统一、Monet Purple 按钮对比度达标、focus 高亮可见、reduced-motion 生效。
- [ ] 交付说明声明移动/Windows/Linux 视觉回归为门禁（本机仅 macOS）。

---

## 自检与交付说明要点

- **Track W**：`flutter build web` 成功为硬验收；avatar_cache 改 BigInt 后头像缓存文件名可能变一次（自动重建）；若拆分 avatar_cache，原生路径行为不变。
- **Track R**：`.ico` 用 `image` 包生成（API 不符则回退工具，记录）；弃用清理只改 analyze 标记站点、保留自定义 `onReorder` widget；`onReorder→onReorderItem` 必须去掉 `-1` 调整，重排行为需核对；CI Flutter 版本须含替代 API，否则该项记录待升级。
- **Track B**：扩展既有 `AppRadii`/`AppSpacing`（非并行类，避免 dual-truth）；4 构建器经共享 helper 接入；primary-700 仅改 Monet Purple 色板；货币助手仅定义/按需挂载。theme-level 改动的移动/Windows/Linux 视觉回归为门禁，本机仅 macOS 目测。
- ARB 不受影响（无新增用户可见本地化文本；货币符号非可翻译文本）。
