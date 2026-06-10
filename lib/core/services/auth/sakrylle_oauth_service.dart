import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../models/oauth_tokens.dart';
import 'loopback_redirect_server_stub.dart'
    if (dart.library.io) 'loopback_redirect_server.dart';
import 'oidc_id_token_validator.dart';
import 'secure_storage_service.dart';

/// Whether OAuth should use a loopback HTTP redirect (desktop) instead of a
/// custom URL scheme. Web never uses loopback; mobile and macOS keep the
/// existing `sakrylle-chat://` custom scheme.
bool shouldUseLoopback(TargetPlatform platform, {bool isWeb = false}) {
  if (isWeb) return false;
  return platform == TargetPlatform.windows || platform == TargetPlatform.linux;
}

/// OAuth 2.0 Authorization Code + PKCE service for Sakrylle API.
///
/// Implements the full OIDC login flow for Sakrylle Chat:
/// - Issuer: https://sub.sakrylle.com
/// - Client type: public (no client_secret)
/// - PKCE: S256 mandatory
class SakrylleOAuthService {
  SakrylleOAuthService._();
  static final SakrylleOAuthService instance = SakrylleOAuthService._();

  static const String _issuer = 'https://sub.sakrylle.com';
  static const String _clientId = 'sakrylle-chat';
  static const String _scopes =
      'openid profile email models:read chat.completions:create offline_access';

  static const String _customSchemeRedirectUri =
      'sakrylle-chat://oauth/callback';

  final SecureStorageService _secure = SecureStorageService.instance;
  final OidcIdTokenValidator _idTokenValidator = OidcIdTokenValidator(
    issuer: _issuer,
    clientId: _clientId,
  );

  // Storage keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _expiresAtKey = 'expires_at';
  static const String _refreshExpiresAtKey = 'refresh_expires_at';
  static const String _idTokenKey = 'id_token';

  // --- Public API ---

  /// Whether the user is currently logged in (has a valid access token).
  Future<bool> get isLoggedIn async {
    final token = await _secure.getOAuthToken(_accessTokenKey);
    if (token.isEmpty) return false;
    final expiresAt = await _getExpiresAt();
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 < expiresAt;
  }

  /// Get the current access token, or empty string if not logged in.
  Future<String> get accessToken async {
    return await _secure.getOAuthToken(_accessTokenKey);
  }

  /// Get the current id_token, or null if not available.
  Future<String?> get idToken async {
    final token = await _secure.getOAuthToken(_idTokenKey);
    return token.isEmpty ? null : token;
  }

  /// Get user info from a verified id_token payload (name, email, etc.).
  Future<Map<String, dynamic>?> get userInfo async {
    final token = await idToken;
    if (token == null) return null;
    try {
      return await _idTokenValidator.verifyIdToken(idToken: token);
    } on OidcValidationException {
      await _secure.clearOAuthTokens();
      return null;
    }
  }

  /// Start the OAuth authorization flow.
  /// Returns the [OAuthTokens] on success, or throws on failure.
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

  /// Completes the flow from the callback [uri] (used ONLY to read the
  /// `code`/`state`/`error` query params). [redirectUri] is the value that was
  /// registered with the authorization server and MUST be the one sent to the
  /// token endpoint — do not derive it from [uri].
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

  /// Exchange an authorization code for tokens.
  Future<OAuthTokens> exchangeCode(
    String code,
    String verifier, {
    required String redirectUri,
    String? expectedNonce,
  }) async {
    final config = await _idTokenValidator.configuration;
    final response = await http.post(
      config.tokenEndpoint,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'client_id': _clientId,
        'code_verifier': verifier,
      },
    );

    final body = _decodeResponseObject(response.body);
    if (response.statusCode != 200) {
      throw Exception(
        _oauthErrorMessage('Token exchange failed', response, body),
      );
    }

    final tokens = OAuthTokens.fromJson(body);
    await _verifyTokenResponse(tokens, expectedNonce: expectedNonce);
    return tokens;
  }

  /// Refresh the access token using the stored refresh token.
  /// Returns new tokens, or throws if refresh fails.
  Future<OAuthTokens> refreshTokens() async {
    final refreshToken = await _secure.getOAuthToken(_refreshTokenKey);
    if (refreshToken.isEmpty) {
      throw Exception('No refresh token available');
    }

    final refreshExpiresAt = await _getRefreshExpiresAt();
    if (refreshExpiresAt != null &&
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= refreshExpiresAt) {
      await _secure.clearOAuthTokens();
      throw Exception('Refresh token expired');
    }

    final config = await _idTokenValidator.configuration;
    final response = await http.post(
      config.tokenEndpoint,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': _clientId,
      },
    );

    final body = _decodeResponseObject(response.body);
    if (response.statusCode != 200) {
      if (_isInvalidRefreshToken(body)) {
        await _secure.clearOAuthTokens();
      }
      throw Exception(
        _oauthErrorMessage('Token refresh failed', response, body),
      );
    }

    final tokens = OAuthTokens.fromJson(body);
    await _verifyTokenResponse(tokens, requireIdToken: false);
    await _storeTokens(tokens);

    return tokens;
  }

  /// Get a valid access token, refreshing if necessary.
  /// Returns the access token, or empty string if not logged in.
  Future<String> getValidAccessToken() async {
    final token = await _secure.getOAuthToken(_accessTokenKey);
    if (token.isEmpty) return '';

    final expiresAt = await _getExpiresAt();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // If token expires in less than 5 minutes, refresh.
    if (now > expiresAt - 300) {
      try {
        final newTokens = await refreshTokens();
        return newTokens.accessToken;
      } catch (_) {
        return '';
      }
    }

    return token;
  }

  /// Logout: revoke tokens and clear local storage.
  Future<void> logout() async {
    final refreshToken = await _secure.getOAuthToken(_refreshTokenKey);
    final accessToken = await _secure.getOAuthToken(_accessTokenKey);
    final config = await _idTokenValidator.configuration;

    await _revokeToken(config, refreshToken);
    await _revokeToken(config, accessToken);
    await _secure.clearOAuthTokens();
  }

  // --- Internal helpers ---

  /// Generate PKCE code_verifier and code_challenge (S256).
  ({String verifier, String challenge}) _generatePkce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final verifier = base64Url.encode(bytes).replaceAll('=', '');
    final digest = sha256.convert(utf8.encode(verifier));
    final challenge = base64Url.encode(digest.bytes).replaceAll('=', '');
    return (verifier: verifier, challenge: challenge);
  }

  /// Generate a random state string for CSRF protection.
  String _generateState() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Build the authorization URL.
  Uri _buildAuthUrl({
    required Uri authorizationEndpoint,
    required String redirectUri,
    required String codeChallenge,
    required String state,
    required String nonce,
  }) {
    return authorizationEndpoint.replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': _clientId,
        'redirect_uri': redirectUri,
        'scope': _scopes,
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'nonce': nonce,
      },
    );
  }

  Future<void> _verifyTokenResponse(
    OAuthTokens tokens, {
    String? expectedNonce,
    bool requireIdToken = true,
  }) async {
    if (tokens.accessToken.isEmpty) {
      throw Exception('Token response missing access_token');
    }
    final idToken = tokens.idToken;
    if (idToken == null || idToken.isEmpty) {
      if (requireIdToken) {
        throw Exception('Token response missing id_token');
      }
      return;
    }
    await _idTokenValidator.verifyIdToken(
      idToken: idToken,
      expectedNonce: expectedNonce,
    );
  }

  /// Store tokens in secure storage.
  Future<void> _storeTokens(OAuthTokens tokens) async {
    await _secure.setOAuthToken(_accessTokenKey, tokens.accessToken);
    if (tokens.refreshToken != null) {
      await _secure.setOAuthToken(_refreshTokenKey, tokens.refreshToken!);
    }
    await _secure.setOAuthToken(
      _expiresAtKey,
      tokens.accessTokenExpiresAt.toString(),
    );
    if (tokens.refreshTokenExpiresAt != null) {
      await _secure.setOAuthToken(
        _refreshExpiresAtKey,
        tokens.refreshTokenExpiresAt.toString(),
      );
    }
    if (tokens.idToken != null) {
      await _secure.setOAuthToken(_idTokenKey, tokens.idToken!);
    }
  }

  /// Get the access token expiration time.
  Future<int> _getExpiresAt() async {
    final value = await _secure.getOAuthToken(_expiresAtKey);
    return int.tryParse(value) ?? 0;
  }

  Future<int?> _getRefreshExpiresAt() async {
    final value = await _secure.getOAuthToken(_refreshExpiresAtKey);
    return int.tryParse(value);
  }

  Future<void> _revokeToken(OidcConfiguration config, String token) async {
    if (token.isEmpty) return;
    final endpoint = config.revocationEndpoint;
    if (endpoint == null) return;

    final response = await http.post(
      endpoint,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'token': token, 'client_id': _clientId},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('[OAuth] Token revocation failed: ${response.statusCode}');
    }
  }

  Map<String, dynamic> _decodeResponseObject(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) return json;
    } catch (_) {}
    return const <String, dynamic>{};
  }

  String _oauthErrorMessage(
    String prefix,
    http.Response response,
    Map<String, dynamic> body,
  ) {
    final error = body['error']?.toString();
    final description = body['error_description']?.toString();
    if (error == null || error.isEmpty) {
      return '$prefix: ${response.statusCode}';
    }
    if (description == null || description.isEmpty) {
      return '$prefix: $error';
    }
    return '$prefix: $error - $description';
  }

  bool _isInvalidRefreshToken(Map<String, dynamic> body) {
    final error = body['error']?.toString();
    return error == 'invalid_grant' || error == 'invalid_token';
  }
}
