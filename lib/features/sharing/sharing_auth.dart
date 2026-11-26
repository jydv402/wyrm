import 'dart:math';

/// Password and session-token authenticator for LAN file sharing endpoints.
///
/// Always requires a non-empty password: either an unambiguous 6-character code
/// generated on startup or a custom password configured in Settings. Changing
/// or regenerating the password immediately revokes all active session tokens.
class SharingAuthService {
  static const String _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _generatedCodeLength = 6;

  final Random _random;
  String _generatedPassword;
  String? _customPassword;
  final Set<String> _activeTokens = <String>{};

  /// Creates a [SharingAuthService] with an initial random 6-char password.
  SharingAuthService({String? initialCustomPassword, Random? random})
    : _random = random ?? Random.secure(),
      _generatedPassword = '' {
    _generatedPassword = _generateCode();
    setCustomPassword(initialCustomPassword);
  }

  /// The currently active password required to unlock Sharing on the Web Remote.
  String get activePassword => _customPassword ?? _generatedPassword;

  /// Whether the active password is user-defined rather than auto-generated.
  bool get isCustomPassword => _customPassword != null;

  /// Number of currently active Web Remote / QR download tokens.
  int get activeTokenCount => _activeTokens.length;

  /// Applies or clears a custom password, revoking existing tokens when changed.
  void setCustomPassword(String? password) {
    final trimmed = password?.trim();
    final normalized = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    if (normalized == _customPassword) return;
    _customPassword = normalized;
    revokeAllTokens();
  }

  /// Generates a fresh 6-character code, clears any custom password, and revokes
  /// all previously issued tokens.
  String regeneratePassword() {
    _customPassword = null;
    _generatedPassword = _generateCode();
    revokeAllTokens();
    return _generatedPassword;
  }

  /// Verifies [candidatePassword] and issues a new bearer session token on match.
  ///
  /// Returns `null` when [candidatePassword] does not match [activePassword].
  String? authenticate(String candidatePassword) {
    if (!_constantTimeEquals(candidatePassword, activePassword)) {
      return null;
    }
    final token = _generateToken();
    _activeTokens.add(token);
    return token;
  }

  /// Validates an incoming `X-Sharing-Token` header or `?token=` query value.
  bool isValidToken(String? token) {
    if (token == null || token.isEmpty) return false;
    var matched = false;
    for (final active in _activeTokens) {
      if (_constantTimeEquals(token, active)) {
        matched = true;
      }
    }
    return matched;
  }

  /// Invalidates every active session and QR download token.
  void revokeAllTokens() {
    _activeTokens.clear();
  }

  String _generateCode() {
    final buffer = StringBuffer();
    for (var i = 0; i < _generatedCodeLength; i++) {
      buffer.write(_codeAlphabet[_random.nextInt(_codeAlphabet.length)]);
    }
    return buffer.toString();
  }

  String _generateToken() {
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buffer.write(_random.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
