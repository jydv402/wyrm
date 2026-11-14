import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Utilities for resolving the device's local network IPv4 address.
class NetworkInfo {
  /// Queries active network interfaces and returns the best candidate local IPv4 address.
  static Future<String> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      // Prioritize Wi-Fi and ethernet interfaces over virtual tunnels.
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        final isPreferred =
            name.contains('wlan') ||
            name.contains('wi-fi') ||
            name.contains('wifi') ||
            name.contains('eth') ||
            name.contains('en');

        if (isPreferred) {
          for (final address in interface.addresses) {
            if (!address.isLoopback &&
                address.type == InternetAddressType.IPv4) {
              return address.address;
            }
          }
        }
      }

      // Fallback: search across any non-loopback interface.
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback && address.type == InternetAddressType.IPv4) {
            return address.address;
          }
        }
      }
    } catch (_) {
      // Gracefully fall back if network interface inspection is restricted.
    }

    return '127.0.0.1';
  }
}

/// Provides the active local IPv4 address of the device.
final localIpProvider = FutureProvider<String>((ref) async {
  return NetworkInfo.getLocalIpAddress();
});
