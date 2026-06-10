---
title: sakrylle-chat OIDC Client 注册请求
status: local
scope: product-local
last_verified: 2026-06-10
---

# sakrylle-chat OIDC Client 注册请求

> 面向中心平台（Sakrylle API / sub.sakrylle.com）的 RP 注册请求。Chat 端代码已就绪，待中心写入生产 `oauth_clients` 后方可真实联调。

## 申请参数

- **client_id**: `sakrylle-chat`
- **client_type**: public（无 client_secret）
- **grant_types**: `authorization_code`, `refresh_token`
- **redirect_uris**:
  - `sakrylle-chat://oauth/callback` — Android / iOS / macOS 自定义 scheme
  - `http://127.0.0.1` — Windows / Linux loopback（端口运行时动态分配，须按 RFC 8252 §7.3 做端口无关匹配）
- **scope**: `openid profile email models:read chat.completions:create offline_access`
- **logout_redirect_uris**: 暂不需要（Chat 端 logout 仅调用 `/oauth/revoke` + 清本地存储，不使用 RP-Initiated Logout 跳转）

## Scope 审计依据

Chat 使用 OAuth `access_token` 调用的 `/v1` 端点：

| 端点 | 用途 | 对应 scope |
|---|---|---|
| `POST /v1/chat/completions` | 聊天补全（所有 AI 对话） | `chat.completions:create` |
| `GET /v1/models` | 模型列表（UI 选择模型） | `models:read` |
| `GET /api/v1/user/balance` | 余额显示（provider 设置页） | 见"待中心确认"第 3 条 |

标准 OIDC scope：`openid`（触发 id_token）、`profile`（id_token 中 name/preferred_username）、`email`（id_token 中 email/email_verified）、`offline_access`（签发 refresh_token）均按标准使用，无需额外确认。

## 需中心平台确认

1. **redirect 端口无关匹配**：redirect 匹配是否对 `http://127.0.0.1` 按 RFC 8252 §7.3 做端口无关匹配？
   若否，需约定固定端口并在此登记（Chat Windows/Linux loopback 服务改为绑定该端口）。

2. **allowed_scopes 覆盖**：`allowed_scopes` 是否覆盖上述 scope（`openid profile email models:read chat.completions:create offline_access`）？
   中心 scope enforcement 开启后缺失会导致登录后调用被拒（`invalid_scope`）。

3. **余额端点 scope**：Chat 使用路径 `/api/v1/user/balance`（非 `/v1/me`）查询余额。该路径在 scope 矩阵中对应哪个 scope（`account:balance:read`？）？若需要，应将 `account:balance:read` 加入 `allowed_scopes` 并同步更新 Chat 端 `_scopes` 常量。

## 代码位置

- Scope 常量：`lib/core/services/auth/sakrylle_oauth_service.dart` 第 36–37 行 `_scopes`
- loopback 实现：`lib/core/services/auth/loopback_redirect_server.dart`
- 平台分支：`lib/core/services/auth/sakrylle_oauth_service.dart` `shouldUseLoopback()`

## 变更历史

| 日期 | 变更 |
|---|---|
| 2026-06-10 | 初始注册请求，新增 Windows/Linux loopback redirect；定稿 scope |
