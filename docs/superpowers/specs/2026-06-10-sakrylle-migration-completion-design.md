# Sakrylle 迁移收尾设计（OIDC 接入 + 品牌化）

- 日期：2026-06-10
- 仓库：Sakrylle Chat（`sakrylle_chat`，Flutter 跨端 LLM 客户端）
- 范围：两条独立 track 合并为一份 spec —— Track A（OIDC 接入收尾）、Track B（品牌化收尾）
- 中心文档来源（实际路径）：`/Users/cervine/Documents/Sakrylle/Sakrylle API/sakrylle-docs/10-platform-identity/`、`.../40-brand-system/design.md`（CLAUDE.md 中记为 `../sub2api/sakrylle-docs/`）

## 1. 目标与背景

Sakrylle Chat 由 kelivo fork 而来。当前状态（已交叉核验代码）：

- **OIDC**：Authorization Code + PKCE(S256)、OIDC Discovery、id_token 完整校验（JWKS 验签 + iss/aud/exp/nbf/iat/nonce）、refresh/revoke/logout、fail-closed 安全存储、Android/iOS/macOS 自定义 scheme 回调、移动/桌面登录 UI —— 均已落地。缺口：Windows/Linux 无 OAuth 回调；真实浏览器往返冒烟未做；中心平台尚未注册 `sakrylle-chat` client（外部依赖）。
- **品牌化**：Bundle ID/包名（`com.sakrylle.chat`）、应用显示名、品牌主色、图标配置已完成。残留 Kelivo 字样集中在 README、`web/manifest.json`、Linux 窗口标题/图标、iOS LiveActivity 类名、macOS autosave key、测试数据、历史文档。

本设计把以上缺口收口到「可交付代码 + 文档同步 + 门禁验收」。

## 2. 总体结构与排序

一份 spec，两条 track。实现排序：**先 Track B（纯本仓库、无外部依赖、可立即闭环），后 Track A（含涉外协调）**。

交付边界：
- 本仓库代码（`lib/`、各平台目录、`README*`、`web/`）
- 本仓库 `oidc-docs/`
- 中心 `sakrylle-docs/` 的 RP 注册契约更新
- **不含**：实际写生产 `oauth_clients`（注册 client 是运维动作）—— 本 spec 仅产出注册请求清单与门禁验收项。

---

## 3. Track A：OIDC 接入收尾

### 3.1 Windows/Linux loopback 回调（方案 A）

改动集中在 `lib/core/services/auth/sakrylle_oauth_service.dart`，复用现有 PKCE/state/nonce/exchange 全部逻辑，仅替换「如何拿到回调 code」的方式。无需新增依赖（`url_launcher: ^6.3.2` 已在 `pubspec.yaml`）。

**平台分支**
```dart
final useLoopback = !kIsWeb && (Platform.isWindows || Platform.isLinux);
```
判定逻辑抽成纯函数 `bool shouldUseLoopback(TargetPlatform platform, {bool isWeb = false})` 以便单测（不直接依赖 `dart:io Platform`）。

**桌面 loopback 路径** `_authorizeLoopback()`：
1. `final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);` 取系统分配的临时端口。
2. `redirectUri = 'http://127.0.0.1:${server.port}/callback'`。
3. 用该 `redirectUri` 构建授权 URL；`url_launcher.launchUrl(authUrl, mode: LaunchMode.externalApplication)` 打开系统浏览器。
4. `await server.first.timeout(const Duration(minutes: 5))` 捕获 `/callback?code=&state=` 请求；校验 `state`；向浏览器返回极简 HTML 提示页；`finally` 中 `await server.close(force: true)`。
5. 走现有 `exchangeCode`（传入同一 `redirectUri`）。

**移动/macOS 路径** `_authorizeCustomScheme()`：保持现有 `FlutterWebAuth2.authenticate(callbackUrlScheme: 'sakrylle-chat')` + `sakrylle-chat://oauth/callback`，不变。

**redirect_uri 串联改造（必须）**：当前 `_redirectUri` 是固定静态 getter，且在 `_buildAuthUrl` 与 `exchangeCode` 两处使用。loopback 的 redirect_uri 含动态端口，授权请求与 token 交换必须用同一值，否则 token 端点会因 `redirect_uri` 不匹配而拒绝。改造：
- `_buildAuthUrl` 增加 `required String redirectUri` 参数。
- `exchangeCode` 增加 `required String redirectUri` 参数（不再读 `_redirectUri`）。
- 实际使用的 `redirectUri` 存入 `_OAuthTransaction`，保证两处一致。
- 自定义 scheme 路径传 `sakrylle-chat://oauth/callback`；loopback 路径传 `http://127.0.0.1:<port>/callback`。
- 移除/保留 `_redirectUri` 仅作自定义 scheme 常量。

**HTML 提示页本地化例外**：该页在外部系统浏览器渲染，Service 层无 `BuildContext`/`AppLocalizations`。按 KISS 用一段中英双语静态文本（例：`登录成功，可关闭此窗口 / You may close this window`）。这是对 `CLAUDE.md §4.1`「用户可见文本必须本地化」的**有意例外**，理由：非 Flutter UI、不经 AppLocalizations、内容固定且无歧义。spec 与代码注释均记录此例外。

### 3.2 scope 对齐

1. 审计 Chat 实际调用的 `/v1/*` 端点（chat completions、models 列表、`/v1/user/balance`）。
2. 据此推导所需 scope 集合。
3. 与中心 scope 矩阵核对后定稿——当前代码 `_scopes = 'openid profile email models:read chat.completions:create offline_access'`，需确认 `chat.completions:create` 在中心矩阵中存在且会被授予。
4. 注册用 `allowed_scopes` 必须覆盖全部所调端点（中心 `oauth_scope_enforcement_enabled` 已于 2026-06-05 置 true，否则登录后调用被拒）。
5. 代码 `_scopes` 常量与最终注册 scope 保持一致。

### 3.3 中心文档同步 + 注册请求

- 更新中心 `sakrylle-docs/10-platform-identity/rp-integration-guide.md` 的 `sakrylle-chat` 目标 client 配置：redirect_uris 增列 `http://127.0.0.1`（loopback，端口无关），定稿 scope。
- 同步本仓库 `oidc-docs/local-integration.md`、`implementation-status.md`、`troubleshooting.md`：W/L loopback 由「未验证」改为「已实现，待门禁验收」。
- 产出 `sakrylle-chat` client 注册请求清单：`client_id=sakrylle-chat`、public client、`grant_types=[authorization_code, refresh_token]`、`redirect_uris=[sakrylle-chat://oauth/callback, http://127.0.0.1]`、最终 scope、`logout_redirect_uris`。
- 注册请求中**显式询问**：中心 redirect 匹配是否对 `127.0.0.1` 做 RFC 8252 端口无关匹配（见 §6 风险 1）。

### 3.4 验证门禁化

真实浏览器往返冒烟写成「中心注册 `sakrylle-chat` 完成后」的验收 checklist，不阻塞代码合入：
- 在 Android / iOS / macOS / Windows / Linux，用非生产测试账号实跑：login → refresh → revoke/logout → profile 映射。
- 验证日志不打印 auth code / token / callback URL / authorization URL / token 响应。
- 确认 token 仅存平台安全存储。

---

## 4. Track B：品牌化收尾

力度：用户可见 + 中优 + 低优全清。保留兼容性敏感的内部标识。

### 4.1 用户可见（高）

- `README.md`：品牌名 Kelivo → Sakrylle Chat（含描述）。**移除 App Store 徽章/链接**（暂无新上架）；GitHub 链接保持现仓库地址不变。
- `README_ZH_CN.md`：同上，品牌名替换 + 移除 App Store 徽章；GitHub 链接保持现仓库地址。
- `web/manifest.json`：`name` 与 `short_name` → `Sakrylle Chat`。

### 4.2 中优

- `linux/runner/my_application.cc`：窗口标题 `kelivo` → `Sakrylle Chat`。图标名 `gtk_window_set_icon_name(window, "kelivo")`：确认打包侧是否按某主题图标名安装；若无对应安装名，则**仅改窗口标题**，图标继续由 `flutter_launcher_icons` 生成路径提供，不强行改 icon name（避免引用不存在的主题图标）。
- iOS LiveActivity 重命名 `KelivoGenerationActivityAttributes` → `SakrylleGenerationActivityAttributes`，同步 4 处：
  - `ios/Runner/KelivoGenerationActivityAttributes.swift`（源文件改名）
  - `ios/GenerationActivityExtension/GenerationActivityExtension.swift`
  - `ios/Runner/AppDelegate.swift`
  - `ios/Runner.xcodeproj/project.pbxproj`（文件引用）
  - LiveActivity 为临时态，类型名不持久化，重命名安全。
- 清理旧图标资源：确认无引用后删除 `assets/icons/kelivo.png`、过期 `assets/app_icon*.png`。
- 执行/确认 `flutter_launcher_icons`（配置已指向 `assets/sakrylle_icon.png`）已为各平台重新生成图标。

### 4.3 低优 / 兼容

- `macos/Runner/MainFlutterWindow.swift`：autosave key `KelivoMainWindowFrame` → `SakrylleMainWindowFrame`，**带迁移**：启动时若新 key 在 `NSUserDefaults` 无值且旧 key（`NSWindow Frame KelivoMainWindowFrame`）有值，则拷贝旧值到新 key，避免重置用户窗口位置/大小。
- 测试数据中的 `Kelivo` 字样（如 backup 路径 `kelivo_backups`、query 文本 `Kelivo fetch`）：更新为中性/新品牌字样，**仅当不影响兼容性断言**；若某测试断言依赖旧字符串语义则保留并注明。
- 历史文档 `oidc-docs/historical/*`、`oidc-docs/implementation-status.md` 中残留品牌字样：更新为参考意义文字。

### 4.4 明确保留（改动会破坏已存用户数据/配置兼容性）

- `kelivo_fetch`（`lib/core/services/mcp/kelivo_fetch/`，MCP 工具 id，被保存的工具配置引用）。
- `KelivoIN`（内置 LLM 供应商 id，被保存的供应商配置引用）。
- spec 与相关代码注释注明保留理由。

---

## 5. 测试与验证

测试需求驱动（`CLAUDE.md §4.10`），覆盖 happy / 边界 / 失败 / 状态分支。

### 5.1 OIDC 单元测试

- `shouldUseLoopback(platform, isWeb)`：Windows/Linux → true；macOS/Android/iOS → false；web → false。
- loopback 回调解析：起真实本地 `HttpServer`，覆盖：
  1. happy：`code + 匹配 state` → 返回 code。
  2. 边界/失败：`state` 不匹配 → 抛 CSRF 异常。
  3. 失败：`error=access_denied` 参数 → 抛错。
  4. 失败：超时未收到回调 → 抛错并关闭 server。
- `redirect_uri` 串联：断言 `_buildAuthUrl` 产出的 `redirect_uri` 与传入 `exchangeCode` 的一致（loopback 与自定义 scheme 两种）。
- 保留现有 `oidc_id_token_validator_test.dart`、`secure_storage_service_test.dart`、`provider_detail_page_oidc_smoke_test.dart`。

### 5.2 品牌化回归守卫

- 新增轻量测试：断言指定文件集（`README.md`、`README_ZH_CN.md`、`web/manifest.json`、Linux 窗口标题来源、iOS LiveActivity 类型名）中无用户可见 `Kelivo`；**白名单放行** `kelivo_fetch`、`KelivoIN`。
- macOS autosave 迁移为 Swift 逻辑，标注手动/目标平台验证（本机 macOS 可验证）。

### 5.3 验证命令与平台边界

- `flutter analyze` + `flutter test`。
- 预期**不触及 ARB**（品牌名硬编码在 `main.dart`，非 ARB；loopback HTML 非 AppLocalizations），无需 `flutter gen-l10n`。
- 桌面边界（`CLAUDE.md §4.4`）：本机 macOS 可 `flutter build macos` 验证；**Windows/Linux loopback 无法在本机实跑**，交付说明显式标注未覆盖边界，留作门禁验收。

---

## 6. 风险与兼容性

1. **🔴 loopback 端口匹配（关键涉外风险）**：中心 redirect 为「精确白名单、不做前缀/正则」。loopback 临时端口要求中心按 RFC 8252 对 `127.0.0.1` 做端口无关匹配。若中心不支持，须改用固定端口（需中心注册该端口）或推动中心调整匹配逻辑。已列入注册请求显式询问项。
2. **macOS 窗口布局**：autosave key 改名带迁移，避免重置用户已保存布局。
3. **iOS LiveActivity 改名**：临时态、不持久化，安全。
4. **保留 `kelivo_fetch`/`KelivoIN`**：无需数据迁移，保用户已存配置可用。
5. **scope enforcement**：注册 `allowed_scopes` 必须覆盖 Chat 全部所调 `/v1`，否则登录后调用被拒。
6. **外部依赖**：真实联调全程依赖中心注册 `sakrylle-chat` client；代码可先交付，联调与门禁验收待注册完成。

---

## 7. 实现顺序建议

1. Track B 全部（B1 → B2 → B3）+ 品牌化回归守卫测试 → `flutter analyze` + `flutter test` → macOS 构建验证。
2. Track A 代码：`sakrylle_oauth_service.dart` loopback 改造 + redirect_uri 串联 + 单元测试。
3. scope 审计与定稿。
4. 中心文档同步 + 注册请求清单 + 本地 `oidc-docs/` 更新。
5. 门禁验收 checklist（待中心注册后执行）。
