import 'rollout.dart';
import 'version.dart';

class UpdateQuery {
  final String channel, platform, arch, installId;
  final String? currentVersion;
  const UpdateQuery({required this.channel, required this.currentVersion, required this.platform, required this.arch, required this.installId});
}

class Decision {
  final String status; // up-to-date | available | required | incompatible
  final Map<String, dynamic>? release, artifact;
  const Decision(this.status, [this.release, this.artifact]);
}

Map<String, dynamic>? _match(Map<String, dynamic> r, UpdateQuery q) {
  for (final a in (r['artifacts'] as List).cast<Map<String, dynamic>>()) {
    if (a['platform'] == q.platform && (a['arch'] == q.arch || a['arch'] == 'universal')) return a;
  }
  return null;
}

/// Line-by-line port of packages/core/src/decide.ts.
Decision decideUpdate(Map<String, dynamic> p, UpdateQuery q) {
  final ch = (p['channels'] as Map)[q.channel] as Map;
  final releases = (ch['releases'] as List).cast<Map<String, dynamic>>();
  if (releases.isEmpty) return const Decision('up-to-date');
  final newest = releases.first, cur = q.currentVersion, minV = ch['minVersion'] as String;
  final below = cur != null && compareVersions(cur, minV) < 0;
  Map<String, dynamic>? rel, art;
  for (var i = 0; i < releases.length; i++) {
    final r = releases[i];
    if (below && compareVersions(r['version'] as String, minV) < 0) break;
    if (!below && i == 0 && !inRollout(q.installId, p['app'] as String, r['version'] as String, ch['rollout'] as int)) continue;
    final a = _match(r, q);
    if (a != null) {
      rel = r;
      art = a;
      break;
    }
  }
  if (rel == null) {
    return !below && releases.any((r) => _match(r, q) != null) ? const Decision('up-to-date') : Decision('incompatible', newest);
  }
  if (below) return Decision('required', rel, art);
  if (cur == null || compareVersions(rel['version'] as String, cur) > 0) return Decision('available', rel, art);
  return const Decision('up-to-date');
}
