import 'dart:convert';

const int _fnv1a32OffsetBasis = 0x811C9DC5;
const int _fnv1a32Prime = 0x01000193;
const int _android31BitMask = 0x7FFFFFFF;

/// Computes a stable, non-zero positive 31-bit Android notification ID using
/// FNV-1a 32-bit hashing over [reminderId], [fireAt], and [slotOffset].
///
/// Folding the resolved [fireAt] epoch ensures that editing a reminder's
/// scheduled time yields a new ID, so reconciliation cancels the stale OS
/// alarm and schedules the updated time cleanly.
int deterministicNotificationId(
  String reminderId,
  DateTime fireAt, {
  int slotOffset = 0,
}) {
  final bytes = utf8.encode(
    '$reminderId|${fireAt.millisecondsSinceEpoch}|$slotOffset',
  );
  var hash = _fnv1a32OffsetBasis;
  for (final byte in bytes) {
    hash ^= byte;
    hash = _mul32(hash, _fnv1a32Prime);
  }
  final masked = hash & _android31BitMask;
  return masked == 0 ? 1 : masked;
}

/// Performs exact unsigned 32-bit multiplication without exceeding 53-bit
/// floating-point precision on any Dart target.
int _mul32(int a, int b) {
  final aLo = a & 0xFFFF;
  final aHi = (a >> 16) & 0xFFFF;
  final lo = aLo * b;
  final hi = ((aHi * b) & 0xFFFF) << 16;
  return (lo + hi) & 0xFFFFFFFF;
}
