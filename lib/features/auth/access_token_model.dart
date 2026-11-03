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
  final String? registeredDeviceId;
  final String? deviceModel;
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
    this.registeredDeviceId,
    this.deviceModel,
    this.attemptedDeviceId,
    this.attemptedDeviceModel,
    this.grantedRecipeIds = const [],
    this.firstAccessedAt,
    this.lastAccessedAt,
  });

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

    List<String> parseGrantedIds(dynamic rawList) {
      if (rawList is Iterable) {
        return rawList
            .where((item) => item != null)
            .map((item) => item.toString())
            .toList();
      }
      return const [];
    }

    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      return null;
    }

    return AccessToken(
      token: doc.id,
      holderName: data['holderName']?.toString() ?? 'Sem nome',
      isAdmin: parseBool(data['isAdmin']),
      status: parseStatus(data['status']),
      registeredDeviceId: data['registeredDeviceId']?.toString(),
      deviceModel: data['deviceModel']?.toString(),
      attemptedDeviceId: data['attemptedDeviceId']?.toString(),
      attemptedDeviceModel: data['attemptedDeviceModel']?.toString(),
      grantedRecipeIds: parseGrantedIds(data['grantedRecipeIds']),
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
      'registeredDeviceId': registeredDeviceId,
      'deviceModel': deviceModel,
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