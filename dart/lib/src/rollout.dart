import 'dart:convert';
import 'package:crypto/crypto.dart';

/// uint32 big-endian of sha256("installId:app:version")[0..4] % 100, as in packages/core/src/rollout.ts.
int rolloutBucket(String installId, String app, String version) {
  final h = sha256.convert(utf8.encode('$installId:$app:$version')).bytes;
  return ((h[0] << 24) | (h[1] << 16) | (h[2] << 8) | h[3]) % 100;
}

bool inRollout(String installId, String app, String version, int percent) => rolloutBucket(installId, app, version) < percent;
