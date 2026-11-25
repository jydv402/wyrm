import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod provider exposing the injectable wall-clock [Clock].
///
/// Production code uses `const Clock()`, while tests can override this provider
/// with `Clock.fixed(...)` for deterministic scheduling and UI checks.
final clockProvider = Provider<Clock>((ref) => const Clock());
