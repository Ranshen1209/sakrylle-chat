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

> **范围修正说明（2026-06-10 取证后）**：原 §4 基于早期审计，低估了 `kelivo` 在生产代码中的使用。取证发现两类事实：(1) `assets/app_icon.png`、`assets/icons/kelivo.png` 是**仍在用的应用内品牌图标**（About/侧栏/托盘/Linux 窗口），且显示旧 Kelivo 图，非过期文件，不可删；(2) 大量 `kelivo` 是**持久化常量**（备份、通知渠道、字体别名、旧路径迁移）。经与用户逐项确认，修正后的范围如下。

### 4.1 用户可见静态文本（高）

- `README.md`：品牌名 Kelivo → Sakrylle Chat。`<h1>`（行 3）、致谢段（行 79「Kelivo's interface」）、`<img alt>`（行 2）。**移除 App Store 徽章/链接**（行 27，暂无新上架）。**GitHub 链接（含字面量 `kelivo` 的仓库 URL，行 29/62/93）保持不变**。
- `README_ZH_CN.md`：同上（行 2/3/26/79）。移除 App Store 徽章（行 26）；GitHub 链接（行 29/62/93）保持。
- `web/manifest.json`：`name` 与 `short_name` `kelivo` → `Sakrylle Chat`。

### 4.2 应用内品牌图标（高，原以为是「删旧资源」，实为替换在用图标）

`sakrylle_icon.png` 仅接到了 flutter_launcher_icons（系统启动图标）；应用内显示仍走旧 `app_icon.png` / `icons/kelivo.png`。处理方式（实现取最小风险者，计划阶段定）：
- **重指向**：把以下引用改指 `assets/sakrylle_icon.png`（保留原文件不删，避免连带 .ico/打包资源处理）：
  - `lib/features/settings/pages/about_page.dart:331`、`lib/desktop/setting/about_pane.dart:276`（About 页图标）
  - `lib/desktop/desktop_home_page.dart:312`（桌面侧栏）
  - `lib/desktop/desktop_tray_controller.dart:96`（托盘 png）
  - `linux/runner/my_application.cc:33`（Linux 窗口图标）
- 托盘/Windows 用的 `app_icon.ico`（`desktop_tray_controller.dart:92`、`windows/runner/Runner.rc:55`、`pubspec.yaml:161`）：需由 `sakrylle_icon.png` 生成 `.ico` 后替换，或保留（计划阶段按是否能生成 .ico 决定；不可直接删）。
- 确认/执行 `flutter_launcher_icons`（已指向 `assets/sakrylle_icon.png`）生成各平台启动图标。

### 4.3 平台命名 / 类名（中）

- `linux/runner/my_application.cc`：窗口标题（行 83/87）`kelivo` → `Sakrylle Chat`；icon_name（行 51）`kelivo` → `com.sakrylle.chat`（对齐 `CMakeLists.txt` 的 `APPLICATION_ID`；GTK 找不到主题图标时回落默认，与现状同，无破坏）。
- iOS LiveActivity 重命名 `KelivoGenerationActivityAttributes` → `SakrylleGenerationActivityAttributes`，同步：源文件改名 + `GenerationActivityExtension.swift`（5 处）+ `AppDelegate.swift`（type 引用 6 处）+ `project.pbxproj`（path/buildfile 引用）。同时 `AppDelegate.swift:222` 后台任务标签 `KelivoBackgroundGeneration` → `SakrylleBackgroundGeneration`（调试标签，不持久化）。LiveActivity 为临时态，重命名安全。

### 4.4 持久化常量：改名 + 安全迁移（用户已选）

- **macOS autosave key**（`macos/Runner/MainFlutterWindow.swift`）：`KelivoMainWindowFrame` → `SakrylleMainWindowFrame`。迁移：`awakeFromNib` 中 `setFrameAutosaveName` 前，若 `NSUserDefaults` 新 key（`NSWindow Frame SakrylleMainWindowFrame`）无值且旧 key（`NSWindow Frame KelivoMainWindowFrame`）有值，拷贝旧值到新 key，避免重置用户窗口布局。
- **通知渠道**（`lib/core/services/notification_service.dart:9`）：`kelivo_bg_chat_v2` → `sakrylle_bg_chat`。迁移：`ensureInitialized` 创建新渠道前，`deleteNotificationChannel('kelivo_bg_chat_v2')` 删除旧孤儿渠道。
- **字体本地别名**（`settings_provider.dart:1383/1404/1465/1476`）：`kelivo_local_app/code` → `sakrylle_local_app/code`。**无需迁移**：alias 仅是运行时注册字体的内部 family 名，每次启动从持久化的字体路径重新注册，从不在 UI 显示；持久化的 `_displayAppFontLocalAliasKey` 等存的是派生 family，旧值在新版仍能用同路径重注册。
- **备份存储键：双读迁移**（`backup.dart`、`s3_client.dart`、`data_sync.dart`、各 backup UI 默认值/占位符）：
  - 新默认/新写入：`sakrylle_backups`、`sakrylle_backup_<ts>.zip`、`.sakrylle_backups_manifest.json`。
  - **双读兼容**：列举/恢复时同时识别 `kelivo_backup_*` 与 `sakrylle_backup_*`；`data_sync.dart:423` 解析正则同时匹配两前缀；manifest 读取时新名缺失则回落旧 `.kelivo_backups_manifest.json`。
  - 默认路径回落：`fromJson` 当 path/prefix 为空时仍能读到旧 `kelivo_backups` 下的数据（列举两套前缀），保证老用户备份不失联。
  - UI 占位符/默认显示更新为 `sakrylle_backups`。

### 4.5 用户可见字样（用户已选一并改）

- `lib/core/providers/mcp_provider.dart:771`：内置 MCP 服务显示名 `'Kelivo MCP'` → `'Sakrylle Fetch'`（仅显示名；工具 id `kelivo_fetch`、引擎类 `KelivoFetchMcpServerEngine` 不动）。
- 导出文件名前缀 `kelivo-<ts>` / `kelivo_<ts>`：`image_preview_sheet.dart`、`image_viewer_page.dart`、`markdown_with_highlight.dart`、`mermaid_bridge_stub.dart`、`tts_provider.dart`、`providers_pane.dart`（qr）等处 → `sakrylle-`。纯导出文件名前缀，无持久化契约。

### 4.6 明确保留（改动会破坏已存用户数据/配置兼容性，或本就是迁移代码）

- `kelivo_fetch`（MCP 工具 id，被保存的工具配置引用）；引擎类 `KelivoFetchMcpServerEngine`、目录 `lib/core/services/mcp/kelivo_fetch/`。
- `KelivoIN`（内置 LLM 供应商 id，被保存的供应商配置引用）；及 `provider_detail_page.dart` 中 `kelivoin` 判定、`settings_provider.dart` 中 `kelivoin` endpoint 路由。
- `lib/utils/brand_assets.dart:65` `kelivo→kelivo.png`（KelivoIN provider 图标映射，随 KelivoIN 保留）。
- `lib/utils/sandbox_path_resolver.dart:69` 的 `AppData/Local/Kelivo/`（**本身就是读旧安装路径做迁移的代码**，改字面量反而破坏迁移）。
- 测试中镜像上述保留常量的数据（如 KelivoIN 相关、kelivo_fetch、sandbox 旧路径）。
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

### 5.2 品牌化测试

- **备份双读迁移单测**（重点，数据兼容）：
  1. 列举时旧 `kelivo_backup_*` 对象被识别。
  2. 列举时新 `sakrylle_backup_*` 对象被识别。
  3. 新旧混合时都返回、按时间排序正确。
  4. `data_sync.dart` 文件名时间解析正则对两前缀均能提取时间戳。
  5. manifest 读取：新名缺失时回落旧 `.kelivo_backups_manifest.json`。
- **回归守卫（正向断言，避免误伤含 `kelivo` 的 GitHub URL）**：断言 `web/manifest.json` 的 `name`/`short_name` == `Sakrylle Chat`；断言 `mcp_provider.dart` 内置服务显示名 == `Sakrylle Fetch`；断言 iOS LiveActivity 类型名为 `SakrylleGenerationActivityAttributes`。不使用「全局无 Kelivo」式负向 grep。
- macOS autosave 迁移、通知渠道迁移为原生/插件逻辑，标注目标平台手动验证（本机 macOS 可验证 autosave）。

### 5.3 验证命令与平台边界

- `flutter analyze` + `flutter test`。
- 预期**不触及 ARB**（品牌名硬编码在 `main.dart`，非 ARB；loopback HTML 非 AppLocalizations），无需 `flutter gen-l10n`。
- 桌面边界（`CLAUDE.md §4.4`）：本机 macOS 可 `flutter build macos` 验证；**Windows/Linux loopback 无法在本机实跑**，交付说明显式标注未覆盖边界，留作门禁验收。

---

## 6. 风险与兼容性

1. **🔴 loopback 端口匹配（关键涉外风险）**：中心 redirect 为「精确白名单、不做前缀/正则」。loopback 临时端口要求中心按 RFC 8252 对 `127.0.0.1` 做端口无关匹配。若中心不支持，须改用固定端口（需中心注册该端口）或推动中心调整匹配逻辑。已列入注册请求显式询问项。
2. **macOS 窗口布局**：autosave key 改名带迁移（拷贝旧 NSUserDefaults 值），避免重置用户已保存布局。
3. **iOS LiveActivity 改名**：临时态、不持久化，安全。
4. **🔴 备份存储键双读迁移（数据兼容关键）**：直接改备份默认存储键会让依赖默认的老用户备份失联。采用双读：新写 `sakrylle_*`，列举/恢复/解析/manifest 同时读旧 `kelivo_*`，默认路径回落旧前缀。最大风险点，单测重点覆盖。
5. **通知渠道改名**：删旧渠道 + 建新渠道；用户对旧渠道的个性化设置不带过来（可接受，原 `_v2` 后缀即表明接受渠道重建）。
6. **应用内图标**：重指向 `sakrylle_icon.png`，原 `app_icon.png`/`icons/kelivo.png` 保留不删（仍被 .ico/打包资源等间接依赖，删除有连带风险）。
7. **保留常量**：`kelivo_fetch`/`KelivoIN`/`brand_assets` 映射/`sandbox_path_resolver` 旧路径——无需迁移，保兼容。
8. **scope enforcement**：注册 `allowed_scopes` 必须覆盖 Chat 全部所调 `/v1`，否则登录后调用被拒。
9. **外部依赖**：真实联调全程依赖中心注册 `sakrylle-chat` client；代码可先交付，联调与门禁验收待注册完成。

---

## 7. 实现顺序建议

1. **Track B 静态/低风险**：4.1 静态文本、4.2 应用内图标重指向、4.3 平台命名/iOS 类名、4.5 用户可见字样 → `flutter analyze` + `flutter test`。
2. **Track B 持久化迁移**：4.4 macOS autosave、通知渠道、字体别名、**备份双读迁移（含单测）** → `flutter analyze` + `flutter test`。
3. **Track A 代码**：`sakrylle_oauth_service.dart` loopback 改造 + redirect_uri 串联 + 单元测试。
4. scope 审计与定稿。
5. 中心文档同步 + 注册请求清单 + 本地 `oidc-docs/` 更新。
6. macOS 构建验证；门禁验收 checklist（待中心注册后执行）。
