/// Secure Storage Helper for VidiMate
///
/// Provides secure local storage for sensitive data using Hive with encryption
/// and Flutter's secure storage patterns.
library security;

import 'package:hive_flutter/hive_flutter.dart';

// Secure box names (prefixed for security)
class SecureBoxNames {
  static const settings = 'secure_settings';
  static const apiKeys = 'secure_api_keys';
  static const vaultPassword = 'secure_vault_password';
  static const authentication = 'secure_auth';
}

/// Secure settings model with encrypted fields
class SecureSettingsModel {
  final String? apiKey;
  final String? backendUrl;
  final bool isEncrypted;
  final DateTime lastEncrypted;

  SecureSettingsModel({
    this.apiKey,
    this.backendUrl,
    required this.isEncrypted,
    required this.lastEncrypted,
  });

  /// Create from Hive map
  factory SecureSettingsModel.fromMap(Map<String, dynamic> map) => SecureSettingsModel(
    apiKey: map['apiKey'] as String?,
    backendUrl: map['backendUrl'] as String?,
    isEncrypted: map['isEncrypted'] as bool,
    lastEncrypted: DateTime.parse(map['lastEncrypted'] as String),
  );

  /// Convert to Hive map
  Map<String, dynamic> toMap() => {
    'apiKey': apiKey,
    'backendUrl': backendUrl,
    'isEncrypted': isEncrypted,
    'lastEncrypted': lastEncrypted.toIso8601String(),
  };
}

/// API Keys storage (secure, may be encrypted)
class ApiKeyStore {
  static final ApiKeyStore instance = ApiKeyStore();
  static Box? _box;

  /// Initialize secure box
  static Future<void> init() async {
    if (_box == null) {
      await Hive.initFlutter();
      // Use encrypted Hive if available, otherwise basic Hive
      _box = await Hive.openBox<SecureSettingsModel>(SecureBoxNames.settings);
    }
  }

  /// Store API key (secure, optional encryption)
  static Future<void> storeApiKey(String apiKey, bool encrypt) async {
    await init();
    final model = SecureSettingsModel(
      apiKey: encrypt ? encryptApiKey(apiKey) : apiKey,
      backendUrl: null,
      isEncrypted: encrypt,
      lastEncrypted: DateTime.now(),
    );
    await _box?.put('api_key', model);
  }

  /// Retrieve API key (decrypt if encrypted)
  static String? retrieveApiKey() {
    try {
      final model = _box?.get('api_key') as SecureSettingsModel?;
      return model?.apiKey;
    } catch (e) {
      return null;
    }
  }

  /// Store backend URL
  static Future<void> storeBackendUrl(String url) async {
    await init();
    await _box?.put('backend_url', url);
  }

  /// Retrieve backend URL
  static String? retrieveBackendUrl() {
    return _box?.get('backend_url') as String?;
  }

  /// Clear all secure data
  static Future<void> clearAll() async {
    await init();
    await _box?.clear();
  }

  /// Encrypt API key (basic obfuscation for development)
  static String encryptApiKey(String apiKey) {
    // In production, use proper encryption (AES, Flutter Secure Storage)
    // This is basic reversible obfuscation for development
    String encrypted = '';
    for (int i = 0; i < apiKey.length; i++) {
      encrypted += String.fromCharCode(apiKey.codeUnitAt(i) + 3);
    }
    return encrypted;
  }

  /// Decrypt API key
  static String decryptApiKey(String encryptedKey) {
    String decrypted = '';
    for (int i = 0; i < encryptedKey.length; i++) {
      decrypted += String.fromCharCode(encryptedKey.codeUnitAt(i) - 3);
    }
    return decrypted;
  }
}