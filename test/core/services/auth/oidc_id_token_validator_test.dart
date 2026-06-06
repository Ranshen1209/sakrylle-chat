import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose/jose.dart';

import 'package:sakrylle_chat/core/services/auth/oidc_id_token_validator.dart';

void main() {
  const issuer = 'https://sub.sakrylle.com';
  const clientId = 'sakrylle-chat';

  late JsonWebKey key;

  setUp(() {
    key = JsonWebKey.symmetric(
      key: BigInt.parse('1234567890123456789012345678901234567890'),
      keyId: 'test-key',
    );
  });

  OidcIdTokenValidator validatorFor(JsonWebKey jwk) {
    return OidcIdTokenValidator(
      issuer: issuer,
      clientId: clientId,
      httpClient: MockClient((request) async {
        if (request.url.path == '/.well-known/openid-configuration') {
          return http.Response(
            jsonEncode({
              'issuer': issuer,
              'authorization_endpoint': '$issuer/oauth/authorize',
              'token_endpoint': '$issuer/oauth/token',
              'jwks_uri': '$issuer/oauth/jwks',
              'revocation_endpoint': '$issuer/oauth/revoke',
            }),
            200,
          );
        }
        if (request.url.path == '/oauth/jwks') {
          return http.Response(
            jsonEncode({
              'keys': [jwk.toJson()],
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );
  }

  String signClaims(Map<String, Object?> claims, JsonWebKey jwk) {
    final builder = JsonWebSignatureBuilder()
      ..jsonContent = claims
      ..addRecipient(jwk, algorithm: 'HS256')
      ..setProtectedHeader('typ', 'JWT');
    return builder.build().toCompactSerialization();
  }

  Map<String, Object?> validClaims({String nonce = 'nonce-1'}) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return {
      'iss': issuer,
      'sub': 'user-1',
      'aud': clientId,
      'exp': now + 3600,
      'iat': now,
      'nonce': nonce,
    };
  }

  test(
    'accepts a signed id_token with matching issuer audience and nonce',
    () async {
      final token = signClaims(validClaims(), key);

      final claims = await validatorFor(
        key,
      ).verifyIdToken(idToken: token, expectedNonce: 'nonce-1');

      expect(claims['sub'], 'user-1');
    },
  );

  test('rejects a token with the wrong nonce', () async {
    final token = signClaims(validClaims(nonce: 'nonce-1'), key);

    expect(
      () => validatorFor(
        key,
      ).verifyIdToken(idToken: token, expectedNonce: 'nonce-2'),
      throwsA(isA<OidcValidationException>()),
    );
  });

  test('rejects a token signed by an unknown key', () async {
    final otherKey = JsonWebKey.symmetric(
      key: BigInt.parse('9988776655443322110099887766554433221100'),
      keyId: 'other-key',
    );
    final token = signClaims(validClaims(), otherKey);

    expect(
      () => validatorFor(
        key,
      ).verifyIdToken(idToken: token, expectedNonce: 'nonce-1'),
      throwsA(anything),
    );
  });

  test('rejects expired id_tokens', () async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final token = signClaims({...validClaims(), 'exp': now - 120}, key);

    expect(
      () => validatorFor(
        key,
      ).verifyIdToken(idToken: token, expectedNonce: 'nonce-1'),
      throwsA(isA<OidcValidationException>()),
    );
  });
}
