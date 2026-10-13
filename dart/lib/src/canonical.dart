// RFC 8785 (JCS) for the value space MyStore manifests use: ints, strings, bools, null, lists, maps.
// Output is byte-identical to JavaScript's canonicalize (checked by the shared vectors).
String canonicalJson(Object? v) {
  final b = StringBuffer();
  void write(Object? x) {
    if (x == null) {
      b.write('null');
    } else if (x is bool) {
      b.write(x ? 'true' : 'false');
    } else if (x is int) {
      b.write(x.toString());
    } else if (x is double) {
      if (x != x.truncateToDouble() || x.isInfinite) throw ArgumentError('non-integer numbers are not used in manifests');
      b.write(x.toInt().toString());
    } else if (x is String) {
      _string(b, x);
    } else if (x is List) {
      b.write('[');
      for (var i = 0; i < x.length; i++) {
        if (i > 0) b.write(',');
        write(x[i]);
      }
      b.write(']');
    } else if (x is Map) {
      final keys = x.keys.cast<String>().toList()..sort(); // String.compareTo = UTF-16 code unit order, as JCS requires
      b.write('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) b.write(',');
        _string(b, keys[i]);
        b.write(':');
        write(x[keys[i]]);
      }
      b.write('}');
    } else {
      throw ArgumentError('unsupported JSON value ${x.runtimeType}');
    }
  }

  write(v);
  return b.toString();
}

void _string(StringBuffer b, String s) {
  b.write('"');
  for (final c in s.codeUnits) {
    switch (c) {
      case 0x22: b.write(r'\"');
      case 0x5c: b.write(r'\\');
      case 0x08: b.write(r'\b');
      case 0x0c: b.write(r'\f');
      case 0x0a: b.write(r'\n');
      case 0x0d: b.write(r'\r');
      case 0x09: b.write(r'\t');
      default:
        if (c < 0x20) {
          b.write('\\u${c.toRadixString(16).padLeft(4, '0')}');
        } else {
          b.writeCharCode(c);
        }
    }
  }
  b.write('"');
}
