import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  const SupabaseConfig._();

  static const _dartDefineUrl = String.fromEnvironment(
    'SUPABASE_URL',
  );
  static const _dartDefineAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static String url = '';
  static String anonKey = '';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static Future<void> load() async {
    final env = await _loadEnv();
    url = _dartDefineUrl.isNotEmpty ? _dartDefineUrl : env['SUPABASE_URL'] ?? '';
    anonKey = _dartDefineAnonKey.isNotEmpty ? _dartDefineAnonKey : env['SUPABASE_ANON_KEY'] ?? '';
  }

  static Future<Map<String, String>> _loadEnv() async {
    try {
      final raw = await rootBundle.loadString('.env');
      return {
        for (final line in raw.split('\n'))
          if (_parseEnvLine(line) case final entry?) entry.key: entry.value,
      };
    } catch (_) {
      return const {};
    }
  }

  static MapEntry<String, String>? _parseEnvLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) return null;

    final separator = trimmed.indexOf('=');
    if (separator <= 0) return null;

    final key = trimmed.substring(0, separator).trim();
    var value = trimmed.substring(separator + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }

    return MapEntry(key, value);
  }
}

Future<void> initializeSupabase() async {
  await SupabaseConfig.load();
  if (!SupabaseConfig.isConfigured) {
    throw StateError('Missing SUPABASE_URL or SUPABASE_ANON_KEY configuration.');
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
}

SupabaseClient get supabase => Supabase.instance.client;

const pushAuthorizedRoles = ['admin', 'pastor', 'social_media', 'security'];

List<String> getUserRoles(User? user) {
  final roles = <String>{};
  final appMetadata = user?.appMetadata ?? const <String, dynamic>{};
  final userMetadata = user?.userMetadata ?? const <String, dynamic>{};
  final appRoles = appMetadata['roles'];
  final primaryRole = appMetadata['role'] ?? userMetadata['role'];

  if (primaryRole is String && primaryRole.isNotEmpty) {
    roles.add(primaryRole);
  }

  if (appRoles is List) {
    roles.addAll(appRoles.whereType<String>());
  }

  return roles.toList();
}

bool hasAnyRole(User? user, Iterable<String> roles) {
  final activeRoles = getUserRoles(user);
  return activeRoles.any(roles.contains);
}

bool canSendPush(User? user) => hasAnyRole(user, pushAuthorizedRoles);
