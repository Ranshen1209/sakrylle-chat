# Sakrylle 发布就绪 + 品牌 token 重构 设计

- 日期：2026-06-10
- 仓库：Sakrylle Chat（`sakrylle_chat`，Flutter 跨端 LLM 客户端）
- 分支：`feat/sakrylle-migration-completion`（接续迁移收尾工作）
- 中心品牌规范：`/Users/cervine/Documents/Sakrylle/Sakrylle API/sakrylle-docs/40-brand-system/design.md`
- 关联前序：`docs/superpowers/specs/2026-06-10-sakrylle-migration-completion-design.md`

## 1. 目标与背景

迁移收尾（OIDC loopback + 品牌化清残留）已完成。本 spec 处理三类剩余工作，组织为三条独立、可分别交付的 track：

- **Track W**：修复预存在的 `flutter build web` 失败（阻塞 web 发布）。
- **Track R**：发布就绪收尾（托盘/Windows `.ico`、CI `--fatal-infos` 弃用清理、平台构建验证）。
- **Track B**：按中心 `design.md` 做品牌 token 全量重构（主题层集中接入）。

三者互不依赖。排序：W（解阻塞）→ R（机械收尾转绿）→ B（最大改面、最后做）。

## 2. 总体结构与交付边界

- 一份 spec，三条 track，分别可提交、可验证。
- 交付边界：本仓库代码与资源。`.ico` 生成、Windows/Linux/iOS 真机构建验证若受本机工具/平台限制，标注门禁与替代方案，不阻塞代码交付。
- 本机为 macOS，仅能验证 macOS 构建与 `flutter test`/`flutter analyze`；其余平台为门禁项。

---

## 3. Track W — 修复 web 构建

`flutter build web` 当前失败，已定位首批两个确定性错误。

### W1. `lib/utils/avatar_cache.dart` int64 字面量
- 现状：`avatar_cache.dart:20` `0xcbf29ce484222325`、`:24` `0xFFFFFFFFFFFFFFFF`（64 位 FNV-1a），JS 不可精确表示。该文件基于 `dart:io`（原生专用），但被打进 web 编译。
- 修法：把哈希算术改为 `BigInt`。
  - `BigInt h = BigInt.parse('cbf29ce484222325', radix: 16);`
  - `final BigInt prime = BigInt.parse('100000001b3', radix: 16);`
  - `final BigInt mask = BigInt.parse('FFFFFFFFFFFFFFFF', radix: 16);`
  - 循环：`h = (h ^ BigInt.from(c));` `h = (h * prime) & mask;`
  - `final hex = h.toRadixString(16).padLeft(16, '0');`
- 兼容性：BigInt 无符号语义与原生 signed-int64 略异，**已缓存头像文件名可能变一次**，缓存自动重建，无数据损失。spec 与代码注释注明。

### W2. `lib/shared/widgets/mermaid_bridge_web.dart:58` `platformViewRegistry`
- 现状：用 `ui.platformViewRegistry`（`dart:ui`），新版 Flutter 已移至 `dart:ui_web`。
- 修法：`import 'dart:ui_web' as ui_web;`，改用 `ui_web.platformViewRegistry.registerViewFactory(viewType, (int id) => container);`，移除该处对 `dart:ui` 成员的引用及 `// ignore: undefined_prefixed_name`。保留文件其余 `dart:html`/`dart:js_util` 逻辑不变。

### W3. 迭代到真正绿（验收标准）
- 上述为编译器首批报错；修掉后可能暴露级联问题，最典型是 `avatar_cache.dart` 的 `dart:io` 导入本身在 web 不可用（编译器此前停在字面量未走到）。
- Track W 定义为调试任务：修已知错 → `flutter build web` → 若现新错继续修，直到构建成功。
  - `dart:io`-on-web 类问题的解法：用条件导入 + web stub 隔离原生专用代码，或确保该文件不进 web 入口图（择风险最小者，实现时定）。
- **验收**：`flutter build web` 退出码 0、产物生成；`flutter analyze` 无新问题；不回归原生平台行为。

---

## 4. Track R — 发布就绪收尾

### R1. 托盘/Windows `.ico` 重新生成
- 现状：`assets/app_icon.ico` 仍是旧 Kelivo 美术（本机无 ImageMagick）。
- 首选方案：用 Dart `image` 包（已是直接依赖 `image: ^4.8.0`）写一次性脚本，从 `assets/sakrylle_icon.png` 生成 `.ico`，覆盖 `assets/app_icon.ico`。仅替换文件内容，`pubspec.yaml`/`windows/runner/Runner.rc`/托盘引用路径不变。
  - 多尺寸 ICO 的具体 API（单尺寸 `encodeIco` vs 多尺寸 `encodeIcoImages` 等）以安装版本为准，实现时确认；若该版本仅支持单尺寸，则生成 256×256 单尺寸 ICO（Windows 会自动缩放）。
- 回退：`image` 包 ICO 编码不可用时，标注用 ImageMagick / 在线工具生成，作为门禁交人工。spec 注明实际采用的路径。
- 校验：`assets/app_icon.ico` 为有效多尺寸 ICO；桌面托盘与 Windows exe 图标显示新美术（Windows 显示为门禁验证）。

### R2. 清理 27 条 `deprecated_member_use`
- 构成：约 23 条 `onReorder`（多处可重排列表）+ 4 条 `axisAlignment`（`SizeTransition` 等）。
- **前置护栏（必做）**：这些弃用提示源自本机 Flutter 版本（"after v3.41.0"）。先确认替代 API（`onReorderItem` / `alignment`）在**本仓库锁定的 Flutter/SDK 版本与 CI 所用版本**上存在。
  - 若替代 API 在目标版本不存在 → 盲改会把 CI 改红；该项降级为「记录待 Flutter 升级后处理」，**不强改**。
  - 若存在 → 逐处替换。`onReorder→onReorderItem` 需处理 `newIndex` 语义调整（移除项后的索引修正），对每个可重排列表核对/测试重排行为。
- 校验：`dart analyze --fatal-infos lib test` 通过（或：剩余项均为已记录的 CI 版本不匹配项，列明）。受影响的可重排页面跑相关 widget 测试。

### R3. 平台构建验证补齐
- 本机仅验 macOS。Windows / Linux / iOS 构建（覆盖 OIDC loopback、`.ico`、LiveActivity 改名、Track B 的 token 主题）无法本机执行。
- 措施：spec 列出对应验证命令（`flutter build windows/linux/ios --release`），声明为门禁/CI 项与未覆盖边界。

---

## 5. Track B — 品牌 token 全量重构（主题层集中接入）

落地方式：在 `design_tokens.dart` 集中定义 token，接入 `theme_factory.dart` 的 ThemeData 组件主题（多数 Material 组件自动继承），共享 iOS 原语改引 token。取值来自 `design.md`。

### B1. token 定义（`lib/theme/design_tokens.dart`）

> **架构修正（取证后）**：`design_tokens.dart` 已存在 `AppRadii`（`capsule=28`）与 `AppSpacing`（`xxs=4 xs=8 sm=12 md=16 lg=20`），被 4 个文件引用。为避免 dual-truth，**扩展现有类**而非新增并行 `Sakrylle*` 类；保留现值避免布局回归。颜色另立 `SakrylleColors`（现有 `AppColors` 仅 `textMuted`）。

- 扩展 `AppRadii`（新增 design.md 圆角档；`sm=12`/`md=16` 与 design.md 一致）：
```dart
class AppRadii {
  static const double capsule = 28;   // 既有，保留
  static const double sm = 12;        // 按钮/输入框
  static const double md = 16;        // 卡片/模态
  static const double full = 999;     // 徽章/开关/头像
}
```
- 扩展 `AppSpacing`（`xs=8 sm=12 md=16` 已与 design.md 一致；新增 `xl=32`；`lg` 保留既有 20 避免回归，design.md 的 24 如需另加 `lgPlus`/按需，本轮不改既有 lg）：
```dart
class AppSpacing {
  static const double xxs = 4;  // 既有
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;  // 既有，保留（不改为 24，避免现有布局回归）
  static const double xl = 32;  // 新增
}
```
- 新增 `SakrylleColors`：
```dart
class SakrylleColors {
  static const Color monetPurple = Color(0xFF9181BD);     // primary-500
  static const Color monetPurpleDark = Color(0xFF7B6AAB); // primary-600
  static const Color primary700 = Color(0xFF5E4F86);      // 起始值，需对比度校验 ≥ AA 4.5:1 后定稿
  static const Color sakura = Color(0xFFEC6A9C);          // accent
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF9181BD);
}
```
- `primary700` 的最终值：实现时用对比度计算确认「白字 on primary700 ≥ 4.5:1」，不满足则调暗。机制优先（按对比度阈值定）。

### B2. ThemeData 组件主题接入（`lib/theme/theme_factory.dart`）

> **架构修正**：有 4 个主题构建器（`buildLightTheme`、`buildLightThemeForScheme`、`buildDarkTheme`、`buildDarkThemeForScheme`），且当前**无** card/button/input/chip 圆角主题（仅 `dialogTheme` 设了 backgroundColor）。

- 新增一个共享 helper（如 `ThemeData _applySakrylleComponentThemes(ThemeData base, ColorScheme scheme)` 或一组可复用的 `*ThemeData` 常量），在**全部 4 个构建器**的 `ThemeData(...)`/`.copyWith(...)` 中接入，避免 4 处重复：
  - `cardTheme` / `dialogTheme` → `RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md))`
  - `elevatedButtonTheme` / `filledButtonTheme` / `outlinedButtonTheme` / `textButtonTheme` → shape 圆角 `AppRadii.sm`
  - `inputDecorationTheme` → 圆角 `AppRadii.sm`
  - `chipTheme` → `StadiumBorder`（full）
- **primary-700 对比度（多色板架构下的正确落点）**：对比度问题仅出现在 **Monet Purple 品牌色板**（白字 on `#9181bd` ≈ 3.8:1）；其余色板各有可访问 primary，动态取色由 M3 处理。因此**仅调整 `palettes.dart` 中 Monet Purple 那一个色板的 `ColorScheme`**（把其 `primary` 或填充按钮用色对齐 `SakrylleColors.primary700`，保持 `onPrimary` 白色达 AA），**不**做全局按钮背景覆盖（否则会污染其它色板与动态取色）。
- 这些改动对继承主题的页面自动生效。

### B3. 共享 iOS 原语引用 token
把以下组件中硬编码的圆角/内距改引 `AppRadii`/`AppSpacing`（改这些即全局传播）：
- `lib/shared/widgets/ios_tactile.dart`、`ios_tile_button.dart`、`ios_form_text_field.dart`、`ios_switch.dart`、`ios_checkbox.dart`
- `lib/desktop/widgets/*`（如 `desktop_select_dropdown.dart` 等）
- 仅替换尺寸常量，不改交互逻辑；保持自制 iOS 观感。

### B4. 字体 / 字号
- 字体 fallback 已是平台系统字体栈（`theme_factory.dart` 的 `kDefaultFontFamilyFallback`/`kWindowsFontFamilyFallback`），符合 design.md「system-ui、不引 Google Fonts」意图——核对即可，不引入 Google Fonts。
- 核对共享组件移动端正文 ≥ 14px（Material 默认 bodyMedium 14sp），仅修正个别 < 14 的共享文本样式。

### B5. 无障碍
- focus：为共享 iOS tactile 组件补焦点高亮（桌面 Tab/方向键可见 focus，不抑制 focus）。
- reduced-motion：在 iOS tactile 的缩放/透明度动画处尊重 `MediaQuery.of(context).disableAnimations`，开启时跳过缩放动画。

### B6. 货币 ￥（判定项）
- 现状：`lib/` 无任何 `¥`/`￥`，无货币符号显示。
- 方案：新增 `formatDisplayAmount`（display-only 金额前缀全角 `￥` U+FFE5）共享助手；**仅**挂载于 Sakrylle 平台余额展示处。第三方 provider 余额币种未知，保持原样不加符号。
- 可调整项：若评审认为连 Sakrylle 余额也不应加符号，则改为「仅定义助手、暂不挂载」。

### B7. 风险与验证
- theme-level 改动影响全 app 视觉。回归手段：`flutter analyze` + `flutter test` + **macOS 实跑目测**（按钮圆角、卡片、输入框、对话框、共享 iOS 组件、focus、reduced-motion）。
- primary-700 与 token 圆角可能与既有自制 iOS 观感有差异，macOS 目测确认统一性不被破坏；移动/Windows/Linux 视觉回归列为门禁。
- 不破坏既有 Android 动态取色路径（B2 已隔离）。

---

## 6. 测试与验证（汇总）

- **Track W**：`flutter build web` 成功为硬验收；`flutter analyze` 无新问题。
- **Track R**：`.ico` 为有效多尺寸 ICO；`dart analyze --fatal-infos lib test` 通过（或剩余项为已记录的版本不匹配项）；可重排页面相关 widget 测试通过。
- **Track B**：`flutter analyze` + `flutter test` 通过；macOS 实跑目测无视觉回归；若新增 `formatDisplayAmount` 等纯函数，补单测（happy/边界）。
- 全局：本机仅覆盖 macOS；Windows/Linux/iOS/web-运行时 视觉与功能为门禁，spec 显式声明未覆盖边界。
- 不触及 ARB（无新增用户可见本地化文本）；如 B6 货币助手涉及用户可见格式，确认是否需本地化（货币符号本身非可翻译文本，数字格式无 l10n key）。

## 7. 实现顺序建议

1. **Track W**：W1 BigInt → W2 ui_web → W3 迭代到 `flutter build web` 绿。
2. **Track R**：R1 `.ico` 生成 → R2 弃用清理（先验证 API 版本）→ R3 门禁验证清单。
3. **Track B**：B1 token → B2 主题接入 → B3 共享原语 → B4 字体/字号核对 → B5 无障碍 → B6 货币助手 → B7 macOS 目测。

## 8. 兼容性与边界小结

- 头像缓存文件名因 BigInt 改动可能变一次（自动重建，无数据损失）。
- R2 弃用清理以「替代 API 在目标 Flutter 版本存在」为前置门槛，否则不强改。
- Track B 仅改静态品牌色板的按钮对比度，Android 动态取色不动。
- 全平台真机/web 运行时验证为门禁，本机只覆盖 macOS。
