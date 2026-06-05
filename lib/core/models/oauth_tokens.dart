import 'dart:convert';

/// OAuth token response from Sakrylle API.
class OAuthTokens {
  final String accessToken;
  final String? refreshToken;
  final int expiresIn;
  final int? refreshTokenExpiresIn;
  final String? scope;
  final String? idToken;
  final String? tokenType;

  const OAuthTokens({
    required this.accessToken,
    this.refreshToken,
    required this.expiresIn,
    this.refreshTokenExpiresIn,
    this.scope,
    this.idToken,
    this.tokenType = 'Bearer',
  });

  /// When the access token expires (Unix timestamp in seconds).
  int get accessTokenExpiresAt =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + expiresIn;

  /// When the refresh token expires (Unix timestamp in seconds), or null.
  int? get refreshTokenExpiresAt => refreshTokenExpiresIn != null
      ? DateTime.now().millisecondsSinceEpoch ~/ 1000 + refreshTokenExpiresIn!
      : null;

  factory OAuthTokens.fromJson(Map<String, dynamic> json) {
    return OAuthTokens(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String?,
      expiresIn: json['expires_in'] as int? ?? 86400,
      refreshTokenExpiresIn: json['refresh_token_expires_in'] as int?,
      scope: json['scope'] as String?,
      idToken: json['id_token'] as String?,
      tokenType: json['token_type'] as String? ?? 'Bearer',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_in': expiresIn,
      'refresh_token_expires_in': refreshTokenExpiresIn,
      'scope': scope,
      'id_token': idToken,
      'token_type': tokenType,
    };
  }

  /// Decode the id_token payload (without signature verification).
  /// Returns null if id_token is absent or malformed.
  Map<String, dynamic>? get idTokenPayload {
    if (idToken == null || idToken!.isEmpty) return null;
    try {
      final parts = idToken!.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final padded = payload + '=' * (4 - payload.length % 4);
      final bytes = base64Url.decode(padded);
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
