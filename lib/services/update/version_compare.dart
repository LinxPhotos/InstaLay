/// Comparable dotted version strings (e.g. `0.8.0`, `1.0.0-beta.1` pre-release ignored for now).
///
/// Comparison is numeric per dot-separated segment of the release core (before
/// `+` build or `-` pre-release). Missing segments are treated as `0`.
int compareVersionStrings(String a, String b) {
  final aCore = _releaseCore(a);
  final bCore = _releaseCore(b);
  final aParts = _numericParts(aCore);
  final bParts = _numericParts(bCore);
  final len = aParts.length > bParts.length ? aParts.length : bParts.length;
  for (var i = 0; i < len; i++) {
    final av = i < aParts.length ? aParts[i] : 0;
    final bv = i < bParts.length ? bParts[i] : 0;
    if (av != bv) return av.compareTo(bv);
  }
  return 0;
}

bool isVersionNewer(String candidate, String current) =>
    compareVersionStrings(candidate, current) > 0;

String _releaseCore(String raw) {
  var s = raw.trim();
  if (s.startsWith('v') || s.startsWith('V')) {
    s = s.substring(1);
  }
  final plus = s.indexOf('+');
  if (plus >= 0) s = s.substring(0, plus);
  final dash = s.indexOf('-');
  if (dash >= 0) s = s.substring(0, dash);
  return s;
}

List<int> _numericParts(String core) {
  if (core.isEmpty) return const [0];
  return core.split('.').map((part) {
    final match = RegExp(r'^\d+').firstMatch(part);
    if (match == null) return 0;
    return int.tryParse(match.group(0)!) ?? 0;
  }).toList();
}
