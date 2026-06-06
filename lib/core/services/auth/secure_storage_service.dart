import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageUnavailableException implements Exception {
  const SecureStorageUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Singleton service for storing sensitive data (API keys, OAuth tokens)
/// using platform-native secure storage (Keychain on iOS/macOS, Keystore on Android).
class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  FlutterSecureStorage? _storage;
  bool _initialized = false;
  bool _keychainAvailable = false;
  SharedPreferences? _prefs;

  @visibleForTesting
  void debugResetForTest() {
    _storage = null;
    _initialized = false;
    _keychainAvailable = false;
    _prefs = null;
  }

  // Key prefixes
  static const String _apiKeyPrefix = 'sakrylle_chat.apikey.';
  static const String _oauthPrefix = 'sakrylle_chat.oauth.';
  static const String _fallbackPrefix = 'secure_fallback.';

  /// Initialize the storage. Call this once at app startup.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        mOptions: MacOsOptions(useDataProtectionKeyChain: false),
      );
      // Test that secure storage can both read and write. Some macOS
      // Keychain configurations allow missing-key reads but reject writes.
      const probeKey = '__secure_storage_probe__';
      await _storage!.write(key: probeKey, value: 'ok');
      await _storage!.read(key: probeKey);
      await _storage!.delete(key: probeKey);
      _keychainAvailable = true;
      debugPrint('[SecureStorage] Secure storage available');
    } catch (e) {
      debugPrint('[SecureStorage] Secure storage unavailable: $e');
      _keychainAvailable = false;
      _storage = null;
      _prefs = await SharedPreferences.getInstance();
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  FlutterSecureStorage _requireStorage() {
    final storage = _storage;
    if (!_keychainAvailable || storage == null) {
      throw const SecureStorageUnavailableException(
        'Secure storage is unavailable; refusing to use insecure fallback',
      );
    }
    return storage;
  }

  Future<String> _readSecureWithLegacyMigration(String key) async {
    final storage = _requireStorage();
    final value = await storage.read(key: key) ?? '';
    if (value.isNotEmpty) return value;

    final prefs = await _getPrefs();
    final legacyKey = '$_fallbackPrefix$key';
    final legacyValue = prefs.getString(legacyKey) ?? '';
    if (legacyValue.isEmpty) return '';

    await storage.write(key: key, value: legacyValue);
    await prefs.remove(legacyKey);
    return legacyValue;
  }

  // --- API Key storage ---

  /// Store a single API key for a provider.
  Future<void> setApiKey(String providerId, String apiKey) async {
    await _ensureInitialized();
    final storage = _requireStorage();
    final key = '$_apiKeyPrefix$providerId';
    if (apiKey.isEmpty) {
      await storage.delete(key: key);
      await (await _getPrefs()).remove('$_fallbackPrefix$key');
    } else {
      await storage.write(key: key, value: apiKey);
    }
  }

  /// Read a single API key for a provider.
  Future<String> getApiKey(String providerId) async {
    await _ensureInitialized();
    return _readSecureWithLegacyMigration('$_apiKeyPrefix$providerId');
  }

  /// Store multiple API keys for a provider (multi-key rotation).
  Future<void> setApiKeys(String providerId, List<String> apiKeys) async {
    await _ensureInitialized();
    final storage = _requireStorage();
    await clearApiKeys(providerId);
    for (int i = 0; i < apiKeys.length; i++) {
      if (apiKeys[i].isNotEmpty) {
        await storage.write(
          key: '$_apiKeyPrefix$providerId.$i',
          value: apiKeys[i],
        );
      }
    }
  }

  /// Read multiple API keys for a provider.
  Future<List<String>> getApiKeys(String providerId, {int count = 0}) async {
    await _ensureInitialized();
    final keys = <String>[];
    for (int i = 0; i < count; i++) {
      final value = await _readSecureWithLegacyMigration(
        '$_apiKeyPrefix$providerId.$i',
      );
      if (value.isNotEmpty) keys.add(value);
    }
    return keys;
  }

  /// Clear all API keys for a provider.
  Future<void> clearApiKeys(String providerId) async {
    await _ensureInitialized();
    final prefs = await _getPrefs();
    final fallbackPrefix = '$_fallbackPrefix$_apiKeyPrefix$providerId';
    final fallbackKeys = prefs
        .getKeys()
        .where((key) => key.startsWith(fallbackPrefix))
        .toList();
    for (final key in fallbackKeys) {
      await prefs.remove(key);
    }

    final storage = _requireStorage();
    final all = await storage.readAll();
    final prefix = '$_apiKeyPrefix$providerId';
    for (final key in all.keys) {
      if (key.startsWith(prefix)) {
        await storage.delete(key: key);
      }
    }
  }

  // --- OAuth token storage ---

  /// Store an OAuth token.
  Future<void> setOAuthToken(String name, String value) async {
    await _ensureInitialized();
    final storage = _requireStorage();
    final key = '$_oauthPrefix$name';
    if (value.isEmpty) {
      await storage.delete(key: key);
      await (await _getPrefs()).remove('$_fallbackPrefix$key');
    } else {
      await storage.write(key: key, value: value);
    }
  }

  /// Read an OAuth token.
  Future<String> getOAuthToken(String name) async {
    await _ensureInitialized();
    return _readSecureWithLegacyMigration('$_oauthPrefix$name');
  }

  /// Clear all OAuth tokens.
  Future<void> clearOAuthTokens() async {
    await _ensureInitialized();
    final prefs = await _getPrefs();
    final fallbackKeys = prefs
        .getKeys()
        .where((key) => key.startsWith('$_fallbackPrefix$_oauthPrefix'))
        .toList();
    for (final key in fallbackKeys) {
      await prefs.remove(key);
    }

    final storage = _requireStorage();
    final all = await storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(_oauthPrefix)) {
        await storage.delete(key: key);
      }
    }
  }

  // --- Migration helpers ---

  /// Check if a provider's API key has been migrated to secure storage.
  Future<bool> isApiKeyMigrated(String providerId) async {
    await _ensureInitialized();
    final key = '$_apiKeyPrefix$providerId';
    final storage = _requireStorage();
    if ((await storage.read(key: key) ?? '').isNotEmpty) return true;
    final prefs = await _getPrefs();
    return prefs.containsKey('$_fallbackPrefix$key');
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
