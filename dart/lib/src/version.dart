// Same rule as packages/core/src/version.ts: X.Y.Z or X.Y.Z-(alpha|beta|rc).N.
final _shape = RegExp(r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-(alpha|beta|rc)\.(0|[1-9]\d*))?$');
const _pre = {'alpha': 0, 'beta': 1, 'rc': 2};

bool isVersion(String v) => _shape.hasMatch(v);

int compareVersions(String a, String b) {
  final x = _shape.firstMatch(a), y = _shape.firstMatch(b);
  if (x == null || y == null) throw ArgumentError('invalid version: $a / $b');
  List<int> key(RegExpMatch m) => [
        int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!),
        m[4] == null ? 1 : 0, m[4] == null ? 0 : _pre[m[4]]!, m[5] == null ? 0 : int.parse(m[5]!),
      ];
  final ka = key(x), kb = key(y);
  for (var i = 0; i < ka.length; i++) {
    if (ka[i] != kb[i]) return ka[i] < kb[i] ? -1 : 1;
  }
  return 0;
}
