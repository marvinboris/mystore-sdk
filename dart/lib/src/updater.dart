import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'decide.dart';
import 'keys.dart' as k;
import 'verify.dart';
import 'version.dart';

abstract class UpdaterStorage {
  Future<String?> get(String key);
  Future<void> set(String key, String value);
}

class MemoryStorage implements UpdaterStorage {
  final _m = <String, String>{};
  @override
  Future<String?> get(String key) async => _m[key];
  @override
  Future<void> set(String key, String value) async => _m[key] = value;
}

/// Never lets a storage failure break an update check (memory keeps values for this session).
class _SafeStorage implements UpdaterStorage {
  final UpdaterStorage inner;
  final _mem = MemoryStorage();
  _SafeStorage(this.inner);
  @override
  Future<String?> get(String key) async {
    try {
      return await inner.get(key) ?? await _mem.get(key);
    } catch (_) {
      return _mem.get(key);
    }
  }

  @override
  Future<void> set(String key, String value) async {
    await _mem.set(key, value);
    try {
      await inner.set(key, value);
    } catch (_) {}
  }
}

sealed class UpdateResult {
  const UpdateResult();
}

class UpToDate extends UpdateResult {
  const UpToDate();
}

/// Fields shared by [Available] and [Required]. They are siblings on purpose: `is Available` must never match a required update.
mixin UpdateInfo {
  String get version;
  List<String> get notes;
  int get size;
  String get url;
  String get sha256;
}

class Available extends UpdateResult with UpdateInfo {
  @override
  final String version, url, sha256;
  @override
  final List<String> notes;
  @override
  final int size;
  const Available(this.version, this.notes, this.size, this.url, this.sha256);
}

class Required extends UpdateResult with UpdateInfo {
  @override
  final String version, url, sha256;
  @override
  final List<String> notes;
  @override
  final int size;
  const Required(this.version, this.notes, this.size, this.url, this.sha256);
}

class Incompatible extends UpdateResult {
  final String version;
  const Incompatible(this.version);
}

class Unknown extends UpdateResult {
  /// network | http | malformed | unknown-key | bad-signature | expired | rollback | wrong-app
  final String reason;
  const Unknown(this.reason);
}

const defaultBaseUrl = 'https://mystore-pied-sigma.vercel.app';
String storeUrl(String app, {String baseUrl = defaultBaseUrl}) => '$baseUrl/apps/$app/';
String deepLink(String app) => 'mystore://app/$app';

class MyStoreUpdater {
  final String app, platform, arch, channel, baseUrl;
  final Map<String, String> keys;
  final UpdaterStorage _store;
  final http.Client _client;
  final Duration timeout;
  final DateTime Function() _now;
  /// Anonymous daily ping (app, version, platform, channel, per-app hashed device id). Set false to opt out.
  final bool stats;

  MyStoreUpdater({required this.app, required this.platform, required this.arch, this.channel = 'stable', this.baseUrl = defaultBaseUrl,
      Map<String, String>? pinnedKeys, required UpdaterStorage storage, http.Client? client, this.timeout = const Duration(seconds: 10), DateTime Function()? now, this.stats = true})
      : keys = pinnedKeys ?? k.pinnedKeys,
        // Storage is required: an in-memory default would re-roll staged rollouts and forget the anti-replay serial on every launch.
        _store = _SafeStorage(storage),
        _client = client ?? http.Client(),
        _now = now ?? DateTime.now {
    if (!RegExp(r'^[a-z0-9][a-z0-9-]{1,40}$').hasMatch(app)) throw ArgumentError('invalid app id "$app"');
    if (!platforms.contains(platform)) throw ArgumentError('invalid platform "$platform"');
    if (!arches.contains(arch)) throw ArgumentError('invalid arch "$arch"');
    if (channel != 'stable' && channel != 'beta') throw ArgumentError('channel must be stable or beta');
    if (keys.isEmpty) throw ArgumentError('at least one pinned key is required');
  }

  Future<String> installId() async {
    final existing = await _store.get('mystore:installId');
    if (existing != null) return existing;
    final r = Random.secure();
    final id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await _store.set('mystore:installId', id);
    return id;
  }

  /// At most once per app per UTC day; fire-and-forget, never throws.
  Future<void> _ping(String version) async {
    if (!stats) return;
    try {
      final day = _now().toUtc().toIso8601String().substring(0, 10), key = 'mystore:$app:lastPing';
      if (await _store.get(key) == day) return;
      final device = crypto.sha256.convert(utf8.encode('${await installId()}:$app')).toString();
      final res = await _client.post(Uri.parse('$baseUrl/api/ping/'), headers: {'content-type': 'application/json'},
          body: jsonEncode({'app': app, 'version': version, 'platform': platform, 'channel': channel, 'device': device})).timeout(timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) await _store.set(key, day);
    } catch (_) {}
  }

  /// Never throws for network or verification problems: returns [Unknown]. Throws [ArgumentError] for a non-semver [currentVersion].
  Future<UpdateResult> check(String currentVersion, {String locale = 'fr'}) async {
    if (!isVersion(currentVersion)) throw ArgumentError('invalid current version "$currentVersion" (expected X.Y.Z or X.Y.Z-beta.N)');
    final http.Response res;
    try {
      res = await _client.get(Uri.parse('$baseUrl/v1/$app/manifest.json')).timeout(timeout);
    } catch (_) {
      return const Unknown('network');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) return const Unknown('http');
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return const Unknown('malformed');
    }
    final serialKey = 'mystore:$app:lastSerial';
    final last = int.tryParse(await _store.get(serialKey) ?? '');
    final v = await verifyManifest(json, keys, now: _now(), lastSerial: last, expectApp: app);
    if (!v.ok) return Unknown(v.reason!);
    await _store.set(serialKey, '${v.payload!['serial']}');
    unawaited(_ping(currentVersion));
    final d = decideUpdate(v.payload!, UpdateQuery(channel: channel, currentVersion: currentVersion, platform: platform, arch: arch, installId: await installId()));
    switch (d.status) {
      case 'up-to-date':
        return const UpToDate();
      case 'incompatible':
        return Incompatible(d.release!['version'] as String);
    }
    final notesMap = d.release!['notes'] as Map;
    final local = (notesMap[locale] as List?)?.cast<String>() ?? const <String>[];
    final notes = local.isNotEmpty ? local : (notesMap['fr'] as List).cast<String>();
    final a = d.artifact!;
    return d.status == 'required'
        ? Required(d.release!['version'] as String, notes, a['size'] as int, a['url'] as String, a['sha256'] as String)
        : Available(d.release!['version'] as String, notes, a['size'] as int, a['url'] as String, a['sha256'] as String);
  }
}
