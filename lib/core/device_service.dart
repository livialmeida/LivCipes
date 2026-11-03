import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static const String _storageKey = 'livcipes_client_instance_id';
  final Uuid _uuid = const Uuid();

  // Retrieve or generate a persistent unique client identifier
  Future<String> getUniqueDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_storageKey);

    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _uuid.v4();
      await prefs.setString(_storageKey, deviceId);
    }

    return deviceId;
  }

  // Retrieve basic platform/browser environment description
  Future<String> getDeviceDescription() async {
    if (kIsWeb) {
      return 'Web / PWA Client';
    }
    return defaultTargetPlatform.name;
  }
}