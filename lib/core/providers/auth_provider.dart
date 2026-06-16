import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../services/auth/sakrylle_oauth_service.dart';
import '../services/sakrylle/sakrylle_catalog_service.dart';
import 'settings_provider.dart';
import 'user_provider.dart';

/// Sakrylle 收敛为单实体商业客户端：未登录不允许进入应用。
enum AuthStatus { unknown, loggedOut, loggedIn }

/// Sakrylle 的 provider 配置 key（聊天发送时 Bearer 取该 provider 的 apiKey）。
const String _sakrylleProviderKey = 'Sakrylle API';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    Future<bool> Function()? isLoggedIn,
    Future<void> Function()? refreshTokens,
    Future<void> Function()? authorize,
    Future<void> Function()? logout,
    Future<String> Function()? accessToken,
    Future<Map<String, dynamic>?> Function()? userInfo,
    Future<int> Function(SettingsProvider settings, String providerKey)?
    refreshCatalog,
  }) : _isLoggedIn =
           isLoggedIn ?? (() => SakrylleOAuthService.instance.isLoggedIn),
       _refreshTokens =
           refreshTokens ??
           (() async {
             await SakrylleOAuthService.instance.refreshTokens();
           }),
       _authorize =
           authorize ??
           (() async {
             await SakrylleOAuthService.instance.authorize();
           }),
       _logout = logout ?? (() => SakrylleOAuthService.instance.logout()),
       _accessToken =
           accessToken ?? (() => SakrylleOAuthService.instance.accessToken),
       _userInfo = userInfo ?? (() => SakrylleOAuthService.instance.userInfo),
       _refreshCatalog =
           refreshCatalog ??
           ((settings, providerKey) => SakrylleCatalogService.refreshInto(
             settings,
             providerKey,
             displayName: providerKey,
           ));

  final Future<bool> Function() _isLoggedIn;
  final Future<void> Function() _refreshTokens;
  final Future<void> Function() _authorize;
  final Future<void> Function() _logout;
  final Future<String> Function() _accessToken;
  final Future<Map<String, dynamic>?> Function() _userInfo;
  final Future<int> Function(SettingsProvider settings, String providerKey)
  _refreshCatalog;

  AuthStatus _status = AuthStatus.unknown;
  AuthStatus get status => _status;

  bool _isAuthorizing = false;
  bool get isAuthorizing => _isAuthorizing;

  bool _lastLoginFailed = false;
  bool get lastLoginFailed => _lastLoginFailed;

  bool _bootstrapped = false;

  /// 启动门控：确认登录态。已登录或可续期则进入应用，否则强制登录。
  Future<void> bootstrap(BuildContext context) async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    bool loggedIn = false;
    try {
      loggedIn = await _isLoggedIn();
      if (!loggedIn) {
        // 访问令牌过期但仍可能有可用的刷新令牌。
        await _refreshTokens();
        loggedIn = true;
      }
    } catch (_) {
      loggedIn = false;
    }

    if (loggedIn) {
      if (context.mounted) {
        final settings = context.read<SettingsProvider>();
        final user = context.read<UserProvider>();
        await _syncTokenIntoProvider(settings);
        _startBackgroundSync(settings, user);
      }
      _status = AuthStatus.loggedIn;
    } else {
      _status = AuthStatus.loggedOut;
    }
    notifyListeners();
  }

  /// 发起 OIDC 登录。成功返回 true 并进入应用，失败返回 false 并保持登出。
  Future<bool> login(BuildContext context) async {
    if (_isAuthorizing) return false;
    _isAuthorizing = true;
    _lastLoginFailed = false;
    notifyListeners();

    try {
      await _authorize();
      if (context.mounted) {
        final settings = context.read<SettingsProvider>();
        final user = context.read<UserProvider>();
        await _syncTokenIntoProvider(settings);
        _startBackgroundSync(settings, user);
      }
      _status = AuthStatus.loggedIn;
      _isAuthorizing = false;
      notifyListeners();
      return true;
    } catch (_) {
      // 含用户取消/网络异常：保持登出，暴露失败标志。
      _lastLoginFailed = true;
      _isAuthorizing = false;
      _status = AuthStatus.loggedOut;
      notifyListeners();
      return false;
    }
  }

  /// 登出：撤销并清除本地令牌，回到登录门控。
  Future<void> logout(BuildContext context) async {
    try {
      await _logout();
    } catch (_) {}
    _status = AuthStatus.loggedOut;
    notifyListeners();
  }

  /// 登录后必要同步：写入 token 到 Sakrylle provider，保证进入应用后即可发起请求。
  ///
  Future<void> _syncTokenIntoProvider(SettingsProvider settings) async {
    try {
      final token = await _accessToken();
      if (token.isNotEmpty) {
        final cfg = settings.getProviderConfig(
          _sakrylleProviderKey,
          defaultName: _sakrylleProviderKey,
        );
        await settings.setProviderConfig(
          _sakrylleProviderKey,
          cfg.copyWith(apiKey: token),
        );
      }
    } catch (_) {}
  }

  /// 非关键同步：用户名和模型目录不阻塞登录门控。
  ///
  void _startBackgroundSync(SettingsProvider settings, UserProvider user) {
    unawaited(_syncProfileAndCatalog(settings, user));
  }

  Future<void> _syncProfileAndCatalog(
    SettingsProvider settings,
    UserProvider user,
  ) async {
    try {
      final info = await _userInfo();
      if (info != null) {
        final name =
            (info['name'] ?? info['preferred_username'] ?? info['email'])
                ?.toString()
                .trim();
        if (name != null && name.isNotEmpty) {
          await user.setName(name);
        }
      }
    } catch (_) {}

    try {
      await _refreshCatalog(settings, _sakrylleProviderKey);
      await settings.ensureSakrylleDefaultChatModel(
        providerKey: _sakrylleProviderKey,
      );
    } catch (_) {}
  }
}
