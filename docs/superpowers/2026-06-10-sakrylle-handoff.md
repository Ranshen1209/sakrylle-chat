# Sakrylle Chat — 会话交付与续作 Handoff（2026-06-10）

> 本文件记录本次会话完成的工作、验证结果、当前状态与剩余（多为门禁/外部）事项，并在末尾附**可直接交付给新 Claude Code 对话的 Prompt**。

## 1. 分支与基线

- 分支：`feat/sakrylle-migration-completion`（基于 `master`，merge-base `87ee6531`）
- HEAD：`bb440fc3`
- 工作区：clean，**尚未合并 / 未开 PR**（按 handoff 保留）

## 2. 本会话完成的两大工作流

### 2.1 迁移收尾（OIDC 接入 + 品牌化清残留）
- Spec：`docs/superpowers/specs/2026-06-10-sakrylle-migration-completion-design.md`
- Plan：`docs/superpowers/plans/2026-06-10-sakrylle-migration-completion.md`
- 交付内容：
  - **OIDC**：Windows/Linux loopback 回调（`lib/core/services/auth/loopback_redirect_server.dart` + `_stub.dart`，条件导入保 web 构建）；`authorize()` 拆为 loopback / 自定义 scheme 双路径并把 `redirect_uri` 串联到 token 交换（`sakrylle_oauth_service.dart`）；`shouldUseLoopback` 平台判定 + 单测；scope 审计；中心 `rp-integration-guide.md` 增列 `http://127.0.0.1` redirect；本地 `oidc-docs/` 状态更新；`oidc-docs/sakrylle-chat-client-registration-request.md` 注册请求清单。
  - **品牌化**：README/README_ZH_CN、`web/manifest.json`、`web/index.html`、Windows 窗口标题、Linux 标题/图标名、iOS LiveActivity 类型重命名、应用内图标重指向 `sakrylle_icon.png`、MCP 显示名、导出文件名前缀。
  - **安全迁移**：macOS autosave key（无损迁移）、Android 通知渠道（删旧建新）、字体别名（运行时、无迁移）、**备份双读迁移**（新写 `sakrylle_*`，列举/恢复/解析/S3 manifest 同时读旧 `kelivo_*`，默认值 forward-only）。
  - **有意保留**（兼容性）：`kelivo_fetch` 工具 id、`KelivoIN` provider、`brand_assets` 映射、`sandbox_path_resolver` 旧路径、`KelivoMutex`/`SendAppLinkToInstance` 单实例 IPC、备份读旧前缀。
- 提交范围：`b465f0f7` … `34a39fc0`（含 spec/plan 文档提交 `2e41f8df`/`d1376c35`/`de00a9f2`）。

### 2.2 发布就绪 + 品牌 token 重构
- Spec：`docs/superpowers/specs/2026-06-10-sakrylle-release-readiness-design.md`
- Plan：`docs/superpowers/plans/2026-06-10-sakrylle-release-readiness.md`
- 交付内容（三 track）：
  - **Track W（修 web 构建）**：`avatar_cache.dart` int64 FNV-1a 改 `BigInt`（web 可编译）；`mermaid_bridge_web.dart` `platformViewRegistry` 改 `dart:ui_web`。`flutter build web` 现成功。
  - **Track R（发布就绪）**：`tool/generate_ico.dart` 用 `image` 包从 `sakrylle_icon.png` 生成多尺寸 `assets/app_icon.ico`（6 尺寸，已替换旧 Kelivo 美术）；清理全部 27 条 `deprecated_member_use`（`onReorder→onReorderItem` 去 `-1` 调整、provider 分组工具在调用侧用 `legacyNewIndex` 还原旧语义；`axisAlignment→alignment` 2 处）；平台构建门禁清单。
  - **Track B（品牌 token）**：扩展 `AppRadii`/`AppSpacing` + 新增 `SakrylleColors`（`design_tokens.dart`，未引入并行类，无 dual-truth）；`_withSakrylleShapes` helper 接入 4 个主题构建器（卡片/对话框/按钮/输入框/chip 圆角）；Monet Purple 色板 `primary` 改 `primary700 #5E4F86` 达 AA（7.15:1，**用户已确认接受整体加深**）；共享 iOS 原语引用 `AppRadii`；`ios_tactile` 无障碍（reduced-motion + 自制 iOS 风格 focus 高亮，**无** Android ripple）；`formatDisplayAmount` 全角 `￥`(U+FFE5) 助手 + 单测（**仅定义，无挂载点**）；字体/字号核对通过（无 <14px 正文违规）。
- 提交范围：`0458adfd` … `bb440fc3`（含 spec/plan `8369ec8e`/`ca922184`/`473308db`）。

## 3. 验证结果（本机 macOS）

- ✅ `flutter build web` → `✓ Built build/web`（exit 0）
- ✅ `dart analyze --fatal-infos lib test` → **No issues found!**（27 条弃用清零，零新增）
- ✅ `flutter build macos --debug` → 成功
- ✅ 定向测试通过：auth、backup、provider_grouping、utils（新增 loopback/平台判定/备份双前缀/货币助手测试）
- 每个任务经两阶段评审（spec + 质量）；最高风险项（备份双读、onReorder off-by-one、4 构建器主题接入、Monet 对比度、§4.9 无障碍）均经独立验证。

### 已知/接受的取舍
- `avatar_cache` 改 BigInt 后头像缓存文件名变一次（自动重建，无数据损失）。
- 备份默认值改 `sakrylle_backups` 为 forward-only；老用户持久化的 `kelivo_backups` 不受影响，且新旧前缀双读。
- 通知渠道改名 → 用户对旧渠道的个性化设置不带过来（设计接受）。
- Monet Purple 色板主色整体加深为 `#5E4F86`（用户已确认）。

## 4. 剩余事项（门禁 / 外部，需新会话或外部协调）

### 4.1 OIDC 真实联调（外部依赖，最高优先）
1. **中心平台注册 `sakrylle-chat` client**（写生产 `oauth_clients`）。详见 `oidc-docs/sakrylle-chat-client-registration-request.md`。
2. 确认中心对 `http://127.0.0.1` 做 **RFC 8252 §7.3 端口无关匹配**（loopback 端口运行时动态分配）。
3. 确认 `allowed_scopes` 覆盖 Chat 所调 `/v1`（含 `chat.completions:create`；余额端点 `/api/v1/user/balance` 的 scope 待中心确认）。
4. 注册完成后，五平台真实浏览器往返冒烟：login → refresh → revoke/logout → profile；验证日志不打印 code/token/URL/响应；token 仅在安全存储。

### 4.2 平台构建验证（本机仅能验 macOS / web）
- `flutter build windows --release`（验 `.ico`、窗口标题、loopback、token 主题）
- `flutter build linux --release`（验窗口标题/图标、loopback、token 主题）
- `flutter build ios --release --no-codesign`（验 LiveActivity 改名、token 主题）
- 移动/Windows/Linux 的 token 主题视觉回归目测。

### 4.3 其它
- 全量 `flutter test` 有 **2 个预存在的 10 分钟挂起测试**（`test/features/home/widgets/chat_input_bar_queue_test.dart`、`test/features/provider/pages/provider_detail_page_selection_toolbar_test.dart`）——已确认 baseline 同样挂起，与本会话无关，但 CI 全绿前需有人排查。
- 分支 `feat/sakrylle-migration-completion` 待决定合并 / PR。
- 提醒手动验证的可重排页面拖拽（onReorder 迁移后）：provider 分组（最复杂）、助手/MCP/快捷短语/世界书/instruction injection/tags/regex 列表。

## 5. 交付给新对话的 Prompt

见下方代码块（复制到新的 Claude Code 对话）。
