import 'package:cloud_firestore/cloud_firestore.dart';

enum TokenStatus {
  active,
  pendingReview,
  revoked,
}

class AccessToken {
  final String token;
  final String holderName;
  final bool isAdmin;
  final TokenStatus status;
  final int maxDevices;
  final String? registeredDeviceId;
  final String? deviceModel;
  final List<String> registeredDeviceIds;
  final List<String> deviceModels;
  final String? attemptedDeviceId;
  final String? attemptedDeviceModel;
  final List<String> grantedRecipeIds;
  final DateTime? firstAccessedAt;
  final DateTime? lastAccessedAt;

  const AccessToken({
    required this.token,
    required this.holderName,
    this.isAdmin = false,
    required this.status,
    this.maxDevices = 3,
    this.registeredDeviceId,
    this.deviceModel,
    this.registeredDeviceIds = const [],
    this.deviceModels = const [],
    this.attemptedDeviceId,
    this.attemptedDeviceModel,
    this.grantedRecipeIds = const [],
    this.firstAccessedAt,
    this.lastAccessedAt,
  });

  // Helper getters to check device authorization and quota
  bool isDeviceRegistered(String deviceId) =>
      registeredDeviceIds.contains(deviceId) || registeredDeviceId == deviceId;

  bool get hasAvailableSlot => registeredDeviceIds.length < maxDevices;

  factory AccessToken.fromFirestore(DocumentSnapshot<dynamic> doc) {
    final rawData = doc.data();
    final Map<String, dynamic> data =
    rawData is Map<String, dynamic> ? rawData : {};

    TokenStatus parseStatus(dynamic rawStatus) {
      final str = rawStatus?.toString();
      if (str == 'pending_review') {
        return TokenStatus.pendingReview;
      }
      if (str == 'revoked') {
        return TokenStatus.revoked;
      }
      return TokenStatus.active;
    }

    bool parseBool(dynamic val) {
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      return false;
    }

    int parseInt(dynamic val, int fallback) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? fallback;
      return fallback;
    }

    List<String> parseStringList(dynamic rawList, [String? legacySingleValue]) {
      final List<String> result = [];
      if (rawList is Iterable) {
        result.addAll(
          rawList
              .where((item) => item != null && item.toString().isNotEmpty)
              .map((item) => item.toString()),
        );
      }
      // Backward compatibility: migrate legacy single field into the list if not present
      if (legacySingleValue != null &&
          legacySingleValue.isNotEmpty &&
          !result.contains(legacySingleValue)) {
        result.insert(0, legacySingleValue);
      }
      return List.unmodifiable(result);
    }

    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    final String? legacyDeviceId = data['registeredDeviceId']?.toString();
    final String? legacyDeviceModel = data['deviceModel']?.toString();

    final List<String> deviceIds =
    parseStringList(data['registeredDeviceIds'], legacyDeviceId);
    final List<String> models =
    parseStringList(data['deviceModels'], legacyDeviceModel);

    return AccessToken(
      token: doc.id,
      holderName: data['holderName']?.toString() ?? 'Sem nome',
      isAdmin: parseBool(data['isAdmin']),
      status: parseStatus(data['status']),
      maxDevices: parseInt(data['maxDevices'], 3),
      registeredDeviceId:
      legacyDeviceId ?? (deviceIds.isNotEmpty ? deviceIds.first : null),
      deviceModel:
      legacyDeviceModel ?? (models.isNotEmpty ? models.first : null),
      registeredDeviceIds: deviceIds,
      deviceModels: models,
      attemptedDeviceId: data['attemptedDeviceId']?.toString(),
      attemptedDeviceModel: data['attemptedDeviceModel']?.toString(),
      grantedRecipeIds: parseStringList(data['grantedRecipeIds']),
      firstAccessedAt: parseDate(data['firstAccessedAt']),
      lastAccessedAt: parseDate(data['lastAccessedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    String serializeStatus(TokenStatus s) {
      switch (s) {
        case TokenStatus.pendingReview:
          return 'pending_review';
        case TokenStatus.revoked:
          return 'revoked';
        case TokenStatus.active:
          return 'active';
      }
    }

    return {
      'holderName': holderName,
      'isAdmin': isAdmin,
      'status': serializeStatus(status),
      'maxDevices': maxDevices,
      'registeredDeviceId': registeredDeviceId ??
          (registeredDeviceIds.isNotEmpty ? registeredDeviceIds.first : null),
      'deviceModel':
      deviceModel ?? (deviceModels.isNotEmpty ? deviceModels.first : null),
      'registeredDeviceIds': registeredDeviceIds,
      'deviceModels': deviceModels,
      'attemptedDeviceId': attemptedDeviceId,
      'attemptedDeviceModel': attemptedDeviceModel,
      'grantedRecipeIds': grantedRecipeIds,
      if (firstAccessedAt != null)
        'firstAccessedAt': Timestamp.fromDate(firstAccessedAt!),
      if (lastAccessedAt != null)
        'lastAccessedAt': Timestamp.fromDate(lastAccessedAt!),
    };
  }
}