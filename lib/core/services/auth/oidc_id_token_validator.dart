import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';

class OidcValidationException implements Exception {
  const OidcValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OidcConfiguration {
  const OidcConfiguration({
    required this.issuer,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.jwksUri,
    this.revocationEndpoint,
    this.endSessionEndpoint,
  });

  final Uri issuer;
  final Uri authorizationEndpoint;
  final Uri tokenEndpoint;
  final Uri jwksUri;
  final Uri? revocationEndpoint;
  final Uri? endSessionEndpoint;

  factory OidcConfiguration.fromJson(Map<String, dynamic> json) {
    Uri requiredUri(String key) {
      final value = json[key]?.toString() ?? '';
      if (value.isEmpty) {
        throw OidcValidationException('OIDC discovery missing $key');
      }
      return Uri.parse(value);
    }

    Uri? optionalUri(String key) {
      final value = json[key]?.toString() ?? '';
      return value.isEmpty ? null : Uri.parse(value);
    }

    return OidcConfiguration(
      issuer: requiredUri('issuer'),
      authorizationEndpoint: requiredUri('authorization_endpoint'),
      tokenEndpoint: requiredUri('token_endpoint'),
      jwksUri: requiredUri('jwks_uri'),
      revocationEndpoint: optionalUri('revocation_endpoint'),
      endSessionEndpoint: optionalUri('end_session_endpoint'),
    );
  }
}

class OidcIdTokenValidator {
  OidcIdTokenValidator({
    required String issuer,
    required String clientId,
    http.Client? httpClient,
    int clockSkewSeconds = 60,
  }) : _issuer = Uri.parse(issuer),
       _clientId = clientId,
       _httpClient = httpClient ?? http.Client(),
       _clockSkewSeconds = clockSkewSeconds;

  final Uri _issuer;
  final String _clientId;
  final http.Client _httpClient;
  final int _clockSkewSeconds;

  OidcConfiguration? _configuration;
  JsonWebKeyStore? _keyStore;

  Future<OidcConfiguration> get configuration async {
    final cached = _configuration;
    if (cached != null) return cached;

    final response = await _httpClient.get(
      _issuer.replace(path: '/.well-known/openid-configuration'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OidcValidationException(
        'OIDC discovery failed: ${response.statusCode}',
      );
    }

    final json = _decodeObject(response.body, 'OIDC discovery');
    final config = OidcConfiguration.fromJson(json);
    if (config.issuer.toString() != _issuer.toString()) {
      throw OidcValidationException('OIDC discovery issuer mismatch');
    }
    _configuration = config;
    return config;
  }

  Future<Map<String, dynamic>> verifyIdToken({
    required String idToken,
    String? expectedNonce,
  }) async {
    if (idToken.isEmpty) {
      throw const OidcValidationException('Missing id_token');
    }

    final keyStore = await _getKeyStore();
    final jwt = await JsonWebToken.decodeAndVerify(idToken, keyStore);
    final claims = jwt.claims.toJson();

    _validateIssuer(claims['iss']);
    _validateAudience(claims['aud']);
    _validateTimeClaims(claims);
    if (expectedNonce != null) {
      _validateNonce(claims['nonce'], expectedNonce);
    }

    return claims;
  }

  Future<JsonWebKeyStore> _getKeyStore() async {
    final cached = _keyStore;
    if (cached != null) return cached;

    final config = await configuration;
    final response = await _httpClient.get(config.jwksUri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OidcValidationException('OIDC JWKS failed: ${response.statusCode}');
    }

    final jwks = _decodeObject(response.body, 'OIDC JWKS');
    final rawKeys = jwks['keys'];
    if (rawKeys is! List || rawKeys.isEmpty) {
      throw const OidcValidationException('OIDC JWKS contains no keys');
    }

    final store = JsonWebKeyStore();
    for (final rawKey in rawKeys) {
      if (rawKey is! Map<String, dynamic>) {
        throw const OidcValidationException('OIDC JWKS contains invalid key');
      }
      store.addKey(JsonWebKey.fromJson(rawKey));
    }
    _keyStore = store;
    return store;
  }

  void _validateIssuer(Object? value) {
    if (value?.toString() != _issuer.toString()) {
      throw const OidcValidationException('Invalid id_token issuer');
    }
  }

  void _validateAudience(Object? value) {
    final audiences = switch (value) {
      final List<Object?> values => values.map((item) => item.toString()),
      final String audience => <String>[audience],
      _ => const <String>[],
    };
    if (!audiences.contains(_clientId)) {
      throw const OidcValidationException('Invalid id_token audience');
    }
  }

  void _validateTimeClaims(Map<String, dynamic> claims) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final exp = _intClaim(claims['exp']);
    if (exp == null || exp <= now - _clockSkewSeconds) {
      throw const OidcValidationException('id_token expired');
    }

    final nbf = _intClaim(claims['nbf']);
    if (nbf != null && nbf > now + _clockSkewSeconds) {
      throw const OidcValidationException('id_token not yet valid');
    }

    final iat = _intClaim(claims['iat']);
    if (iat != null && iat > now + _clockSkewSeconds) {
      throw const OidcValidationException('id_token issued in the future');
    }
  }

  void _validateNonce(Object? value, String expectedNonce) {
    if (value?.toString() != expectedNonce) {
      throw const OidcValidationException('Invalid id_token nonce');
    }
  }

  int? _intClaim(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static Map<String, dynamic> _decodeObject(String body, String label) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) return json;
    } catch (_) {}
    throw OidcValidationException('$label response is not a JSON object');
  }
}
