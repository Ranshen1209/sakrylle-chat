import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import '../../models/oauth_tokens.dart';
import 'secure_storage_service.dart';

/// OAuth 2.0 Authorization Code + PKCE service for Sakrylle API.
///
/// Implements the full OIDC login flow for Sakrylle Chat:
/// - Authorization endpoint: https://sub.sakrylle.com/oauth/authorize
/// - Token endpoint: https://sub.sakrylle.com/oauth/token
/// - Client type: public (no client_secret)
/// - PKCE: S256 mandatory
class SakrylleOAuthService {
  SakrylleOAuthService._();
  static final SakrylleOAuthService instance = SakrylleOAuthService._();

  static const String _issuer = 'https://sub.sakrylle.com';
  static const String _clientId = 'sakrylle-chat';
  static const String _scopes =
      'openid profile email models:read chat.completions:create offline_access';

  /// The redirect URI for the current platform.
  static String get _redirectUri {
    // All platforms use custom URL scheme
    return 'sakrylle-chat://oauth/callback';
  }

  final SecureStorageService _secure = SecureStorageService.instance;

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

  /// Get user info from the id_token payload (name, email, etc.).
  Future<Map<String, dynamic>?> get userInfo async {
    final token = await idToken;
    if (token == null) return null;
    final tokens = OAuthTokens(accessToken: '', expiresIn: 0, idToken: token);
    return tokens.idTokenPayload;
  }

  /// Start the OAuth authorization flow.
  /// Returns the OAuthTokens on success, or throws on failure.
  Future<OAuthTokens> authorize() async {
    // Generate PKCE
    final pkce = _generatePkce();
    final state = _generateState();
    final nonce = _generateState(); // reuse for nonce

    // Build authorize URL
    final authUrl = _buildAuthUrl(
      codeChallenge: pkce.challenge,
      state: state,
      nonce: nonce,
    );

    print('[OAuth] Starting authorize flow');
    print('[OAuth] Auth URL: $authUrl');
    print('[OAuth] Redirect URI: $_redirectUri');
    print('[OAuth] State: $state');

    // Launch browser and wait for callback
    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: 'sakrylle-chat',
    );

    print('[OAuth] Callback received: $result');

    // Parse callback
    final uri = Uri.parse(result);
    final returnedState = uri.queryParameters['state'];
    print('[OAuth] Returned state: $returnedState');
    if (returnedState != state) {
      throw Exception('OAuth state mismatch: possible CSRF attack');
    }

    final code = uri.queryParameters['code'];
    print('[OAuth] Authorization code: ${code?.substring(0, 10)}...');
    if (code == null || code.isEmpty) {
      final error = uri.queryParameters['error'] ?? 'unknown';
      final desc = uri.queryParameters['error_description'] ?? '';
      throw Exception('OAuth authorization failed: $error - $desc');
    }

    // Exchange code for tokens
    print('[OAuth] Exchanging code for tokens...');
    final tokens = await exchangeCode(code, pkce.verifier);
    print('[OAuth] Token exchange successful. Access token: ${tokens.accessToken.substring(0, 10)}...');

    // Store tokens
    await _storeTokens(tokens);

    return tokens;
  }

  /// Exchange an authorization code for tokens.
  Future<OAuthTokens> exchangeCode(String code, String verifier) async {
    print('[OAuth] Token endpoint: $_issuer/oauth/token');
    print('[OAuth] Client ID: $_clientId');
    print('[OAuth] Redirect URI: $_redirectUri');

    final response = await http.post(
      Uri.parse('$_issuer/oauth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _redirectUri,
        'client_id': _clientId,
        'code_verifier': verifier,
      },
    );

    print('[OAuth] Token response status: ${response.statusCode}');
    print('[OAuth] Token response body: ${response.body}');

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(
        'Token exchange failed: ${body['error']} - ${body['error_description']}',
      );
    }

    return OAuthTokens.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Refresh the access token using the stored refresh token.
  /// Returns new tokens, or throws if refresh fails.
  Future<OAuthTokens> refreshTokens() async {
    final refreshToken = await _secure.getOAuthToken(_refreshTokenKey);
    if (refreshToken.isEmpty) {
      throw Exception('No refresh token available');
    }

    final response = await http.post(
      Uri.parse('$_issuer/oauth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': _clientId,
      },
    );

    if (response.statusCode != 200) {
      // Refresh failed — clear all tokens
      await logout();
      throw Exception('Token refresh failed: ${response.statusCode}');
    }

    final tokens = OAuthTokens.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );

    // Store new tokens (refresh_token rotation)
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

    // If token expires in less than 5 minutes, refresh
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
    // Try to revoke the refresh token (best-effort)
    if (refreshToken.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$_issuer/oauth/revoke'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'token': refreshToken, 'client_id': _clientId},
        );
      } catch (_) {
        // Ignore revocation errors
      }
    }
    // Clear local storage
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
    required String codeChallenge,
    required String state,
    String? nonce,
  }) {
    return Uri.parse('$_issuer/oauth/authorize').replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'scope': _scopes,
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        if (nonce != null) 'nonce': nonce,
      },
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
}
