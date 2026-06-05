import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Singleton service for storing sensitive data (API keys, OAuth tokens)
/// using platform-native secure storage (Keychain on iOS/macOS, Keystore on Android).
class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Key prefixes
  static const String _apiKeyPrefix = 'sakrylle_chat.apikey.';
  static const String _oauthPrefix = 'sakrylle_chat.oauth.';

  // --- API Key storage ---

  /// Store a single API key for a provider.
  Future<void> setApiKey(String providerId, String apiKey) async {
    final key = '$_apiKeyPrefix$providerId';
    if (apiKey.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: apiKey);
    }
  }

  /// Read a single API key for a provider.
  Future<String> getApiKey(String providerId) async {
    return await _storage.read(key: '$_apiKeyPrefix$providerId') ?? '';
  }

  /// Store multiple API keys for a provider (multi-key rotation).
  Future<void> setApiKeys(String providerId, List<String> apiKeys) async {
    // Clear existing keys first
    await clearApiKeys(providerId);
    for (int i = 0; i < apiKeys.length; i++) {
      if (apiKeys[i].isNotEmpty) {
        await _storage.write(
          key: '$_apiKeyPrefix$providerId.$i',
          value: apiKeys[i],
        );
      }
    }
  }

  /// Read multiple API keys for a provider.
  Future<List<String>> getApiKeys(String providerId, {int count = 0}) async {
    final keys = <String>[];
    for (int i = 0; i < count; i++) {
      final value = await _storage.read(key: '$_apiKeyPrefix$providerId.$i');
      if (value != null && value.isNotEmpty) {
        keys.add(value);
      }
    }
    return keys;
  }

  /// Clear all API keys for a provider.
  Future<void> clearApiKeys(String providerId) async {
    final all = await _storage.readAll();
    final prefix = '$_apiKeyPrefix$providerId';
    for (final key in all.keys) {
      if (key.startsWith(prefix)) {
        await _storage.delete(key: key);
      }
    }
  }

  // --- OAuth token storage ---

  /// Store an OAuth token.
  Future<void> setOAuthToken(String name, String value) async {
    if (value.isEmpty) {
      await _storage.delete(key: '$_oauthPrefix$name');
    } else {
      await _storage.write(key: '$_oauthPrefix$name', value: value);
    }
  }

  /// Read an OAuth token.
  Future<String> getOAuthToken(String name) async {
    return await _storage.read(key: '$_oauthPrefix$name') ?? '';
  }

  /// Clear all OAuth tokens.
  Future<void> clearOAuthTokens() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(_oauthPrefix)) {
        await _storage.delete(key: key);
      }
    }
  }

  // --- Migration helpers ---

  /// Check if a provider's API key has been migrated to secure storage.
  Future<bool> isApiKeyMigrated(String providerId) async {
    final all = await _storage.readAll();
    return all.containsKey('$_apiKeyPrefix$providerId');
  }

  /// Migrate a single API key from SharedPreferences value to secure storage.
  /// Returns true if migration was performed.
  Future<bool> migrateApiKey(String providerId, String plainApiKey) async {
    if (plainApiKey.isEmpty) return false;
    if (await isApiKeyMigrated(providerId)) return false;
    await setApiKey(providerId, plainApiKey);
    return true;
  }
}
