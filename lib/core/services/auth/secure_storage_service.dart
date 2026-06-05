import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service for storing sensitive data (API keys, OAuth tokens)
/// using platform-native secure storage (Keychain on iOS/macOS, Keystore on Android).
/// Falls back to SharedPreferences when Keychain is not available.
class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  FlutterSecureStorage? _storage;
  bool _initialized = false;
  bool _keychainAvailable = false;
  SharedPreferences? _prefs;

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
      );
      // Test if Keychain is available by doing a read
      await _storage!.read(key: '__test_keychain__');
      _keychainAvailable = true;
      debugPrint('[SecureStorage] Keychain available');
    } catch (e) {
      debugPrint('[SecureStorage] Keychain not available, using fallback: $e');
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

  // --- API Key storage ---

  /// Store a single API key for a provider.
  Future<void> setApiKey(String providerId, String apiKey) async {
    await _ensureInitialized();
    final key = '$_apiKeyPrefix$providerId';
    if (!_keychainAvailable) {
      final prefs = await _getPrefs();
      if (apiKey.isEmpty) {
        await prefs.remove('$_fallbackPrefix$key');
      } else {
        await prefs.setString('$_fallbackPrefix$key', apiKey);
      }
      return;
    }
    try {
      if (apiKey.isEmpty) {
        await _storage!.delete(key: key);
      } else {
        await _storage!.write(key: key, value: apiKey);
      }
    } catch (e) {
      debugPrint('[SecureStorage] setApiKey error: $e');
      // Fallback to SharedPreferences
      final prefs = await _getPrefs();
      if (apiKey.isEmpty) {
        await prefs.remove('$_fallbackPrefix$key');
      } else {
        await prefs.setString('$_fallbackPrefix$key', apiKey);
      }
    }
  }

  /// Read a single API key for a provider.
  Future<String> getApiKey(String providerId) async {
    await _ensureInitialized();
    final key = '$_apiKeyPrefix$providerId';
    if (!_keychainAvailable) {
      final prefs = await _getPrefs();
      return prefs.getString('$_fallbackPrefix$key') ?? '';
    }
    try {
      return await _storage!.read(key: key) ?? '';
    } catch (e) {
      debugPrint('[SecureStorage] getApiKey error: $e');
      final prefs = await _getPrefs();
      return prefs.getString('$_fallbackPrefix$key') ?? '';
    }
  }

  /// Store multiple API keys for a provider (multi-key rotation).
  Future<void> setApiKeys(String providerId, List<String> apiKeys) async {
    await _ensureInitialized();
    // Clear existing keys first
    await clearApiKeys(providerId);
    for (int i = 0; i < apiKeys.length; i++) {
      if (apiKeys[i].isNotEmpty) {
        final key = '$_apiKeyPrefix$providerId.$i';
        if (!_keychainAvailable) {
          final prefs = await _getPrefs();
          await prefs.setString('$_fallbackPrefix$key', apiKeys[i]);
        } else {
          try {
            await _storage!.write(key: key, value: apiKeys[i]);
          } catch (e) {
            debugPrint('[SecureStorage] setApiKeys error: $e');
            final prefs = await _getPrefs();
            await prefs.setString('$_fallbackPrefix$key', apiKeys[i]);
          }
        }
      }
    }
  }

  /// Read multiple API keys for a provider.
  Future<List<String>> getApiKeys(String providerId, {int count = 0}) async {
    await _ensureInitialized();
    final keys = <String>[];
    for (int i = 0; i < count; i++) {
      final key = '$_apiKeyPrefix$providerId.$i';
      String? value;
      if (!_keychainAvailable) {
        final prefs = await _getPrefs();
        value = prefs.getString('$_fallbackPrefix$key');
      } else {
        try {
          value = await _storage!.read(key: key);
        } catch (e) {
          debugPrint('[SecureStorage] getApiKeys error: $e');
          final prefs = await _getPrefs();
          value = prefs.getString('$_fallbackPrefix$key');
        }
      }
      if (value != null && value.isNotEmpty) {
        keys.add(value);
      }
    }
    return keys;
  }

  /// Clear all API keys for a provider.
  Future<void> clearApiKeys(String providerId) async {
    await _ensureInitialized();
    if (!_keychainAvailable) {
      final prefs = await _getPrefs();
      final prefix = '$_fallbackPrefix$_apiKeyPrefix$providerId';
      final keysToRemove = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      return;
    }
    try {
      final all = await _storage!.readAll();
      final prefix = '$_apiKeyPrefix$providerId';
      for (final key in all.keys) {
        if (key.startsWith(prefix)) {
          await _storage!.delete(key: key);
        }
      }
    } catch (e) {
      debugPrint('[SecureStorage] clearApiKeys error: $e');
      final prefs = await _getPrefs();
      final prefix = '$_fallbackPrefix$_apiKeyPrefix$providerId';
      final keysToRemove = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
    }
  }

  // --- OAuth token storage ---

  /// Store an OAuth token.
  Future<void> setOAuthToken(String name, String value) async {
    await _ensureInitialized();
    final key = '$_oauthPrefix$name';
    if (!_keychainAvailable) {
      final prefs = await _getPrefs();
      if (value.isEmpty) {
        await prefs.remove('$_fallbackPrefix$key');
      } else {
        await prefs.setString('$_fallbackPrefix$key', value);
      }
      return;
    }
    try {
      if (value.isEmpty) {
        await _storage!.delete(key: key);
      } else {
        await _storage!.write(key: key, value: value);
      }
    } catch (e) {
      debugPrint('[SecureStorage] setOAuthToken error: $e');
      final prefs = await _getPrefs();
      if (value.isEmpty) {
        await prefs.remove('$_fallbackPrefix$key');
      } else {
        await prefs.setString('$_fallbackPrefix$key', value);
      }
    }
  }

  /// Read an OAuth token.
  Future<String> getOAuthToken(String name) async {
    await _ensureInitialized();
    final key = '$_oauthPrefix$name';
    if (!_keychainAvailable) {
      final prefs = await _getPrefs();
      return prefs.getString('$_fallbackPrefix$key') ?? '';
    }
    try {
      return await _storage!.read(key: key) ?? '';
    } catch (e) {
      debugPrint('[SecureStorage] getOAuthToken error: $e');
      final prefs = await _getPrefs();
      return prefs.getString('$_fallbackPrefix$key') ?? '';
    }
  }

  /// Clear all OAuth tokens.
  Future<void> clearOAuthTokens() async {
    await _ensureInitialized();
    if (!_keychainAvailable) {
      final prefs = await _getPrefs();
      final keysToRemove = prefs.getKeys().where((k) => k.startsWith('$_fallbackPrefix$_oauthPrefix')).toList();
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      return;
    }
    try {
      final all = await _storage!.readAll();
      for (final key in all.keys) {
        if (key.startsWith(_oauthPrefix)) {
          await _storage!.delete(key: key);
        }
      }
    } catch (e) {
      debugPrint('[SecureStorage] clearOAuthTokens error: $e');
      final prefs = await _getPrefs();
      final keysToRemove = prefs.getKeys().where((k) => k.startsWith('$_fallbackPrefix$_oauthPrefix')).toList();
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
    }
  }

  // --- Migration helpers ---

  /// Check if a provider's API key has been migrated to secure storage.
  Future<bool> isApiKeyMigrated(String providerId) async {
    await _ensureInitialized();
    if (!_keychainAvailable) {
      final prefs = await _getPrefs();
      return prefs.containsKey('$_fallbackPrefix$_apiKeyPrefix$providerId');
    }
    try {
      final all = await _storage!.readAll();
      return all.containsKey('$_apiKeyPrefix$providerId');
    } catch (e) {
      debugPrint('[SecureStorage] isApiKeyMigrated error: $e');
      final prefs = await _getPrefs();
      return prefs.containsKey('$_fallbackPrefix$_apiKeyPrefix$providerId');
    }
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
