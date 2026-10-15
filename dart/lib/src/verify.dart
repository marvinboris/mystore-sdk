import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'canonical.dart';
import 'version.dart';

const platforms = ['android', 'windows', 'macos', 'linux', 'web'];
const arches = ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x64', 'arm64', 'universal'];
const _kinds = ['apk', 'exe', 'msi', 'dmg', 'zip', 'appimage', 'deb', 'pwa'];

class VerifyResult {
  final bool ok;
  final String? reason;
  final Map<String, dynamic>? payload;
  const VerifyResult.ok(this.payload) : ok = true, reason = null;
  const VerifyResult.fail(this.reason) : ok = false, payload = null;
}

bool _str(Object? v, [int max = 10000]) => v is String && v.length <= max;
bool _int(Object? v) => v is int;
bool _strs(Object? v) => v is List && v.every((x) => _str(x));
bool _hex(Object? v, int n) => v is String && RegExp('^[0-9a-f]{$n}\$').hasMatch(v);
bool _ver(Object? v) => v is String && isVersion(v);

bool _artifact(Object? a) =>
    a is Map && platforms.contains(a['platform']) && arches.contains(a['arch']) && _kinds.contains(a['kind']) &&
    a['url'] is String && RegExp(r'''^https://[^\s"'<>\\]+$''').hasMatch(a['url'] as String) &&
    _int(a['size']) && (a['size'] as int) > 0 && _hex(a['sha256'], 64) &&
    (a['sha512'] == null || _hex(a['sha512'], 128)) && (a['minOs'] == null || _str(a['minOs'], 20)) &&
    (a['tauriSig'] == null || _str(a['tauriSig'], 2000));
bool _release(Object? r) =>
    r is Map && _ver(r['version']) && (r['versionCode'] == null || _int(r['versionCode'])) && _str(r['date']) &&
    r['notes'] is Map && _strs(r['notes']['fr']) && _strs(r['notes']['en']) && r['artifacts'] is List && (r['artifacts'] as List).every(_artifact);
bool _channel(Object? c) =>
    c is Map && _int(c['rollout']) && (c['rollout'] as int) >= 0 && (c['rollout'] as int) <= 100 && _ver(c['minVersion']) &&
    c['releases'] is List && (c['releases'] as List).every(_release) &&
    c['yanked'] is List && (c['yanked'] as List).every((y) => y is Map && _str(y['version']) && y['reason'] is Map && _str(y['reason']['fr']) && _str(y['reason']['en']));
bool isManifest(Object? m) {
  if (m is! Map || !_str(m['keyid']) || !_str(m['sig']) || m['signed'] is! Map) return false;
  final s = m['signed'] as Map;
  return s['schema'] == 1 && _str(s['app']) && _int(s['serial']) && _str(s['expires']) && s['channels'] is Map &&
      _channel(s['channels']['stable']) && _channel(s['channels']['beta']) &&
      (s['android'] == null || (s['android'] is Map && _str(s['android']['package'], 200) &&
          s['android']['signerSha256'] is String && RegExp(r'^[0-9A-F]{64}$').hasMatch(s['android']['signerSha256'] as String)));
}

/// Same checks, same order as packages/core/src/verify.ts.
Future<VerifyResult> verifyManifest(Object? m, Map<String, String> pinned,
    {required DateTime now, int? lastSerial, Duration skew = const Duration(hours: 24), required String expectApp}) async {
  if (!isManifest(m)) return const VerifyResult.fail('malformed');
  final man = m as Map;
  final signed = (man['signed'] as Map).cast<String, dynamic>();
  final pub = pinned[man['keyid']];
  if (pub == null) return const VerifyResult.fail('unknown-key');
  var good = false;
  try {
    good = await Ed25519().verify(utf8.encode(canonicalJson(signed)),
        signature: Signature(base64.decode(man['sig'] as String), publicKey: SimplePublicKey(_hexBytes(pub), type: KeyPairType.ed25519)));
  } catch (_) {
    good = false;
  }
  if (!good) return const VerifyResult.fail('bad-signature');
  if (signed['app'] != expectApp) return const VerifyResult.fail('wrong-app');
  final exp = DateTime.tryParse(signed['expires'] as String);
  if (exp == null || exp.add(skew).isBefore(now)) return const VerifyResult.fail('expired');
  if (lastSerial != null && (signed['serial'] as int) < lastSerial) return const VerifyResult.fail('rollback');
  return VerifyResult.ok(signed);
}

List<int> _hexBytes(String h) => [for (var i = 0; i < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)];
