import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'access_token_model.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _localDeviceIdKey = 'livcipes_device_uuid';
  static const String _savedTokenKey = 'livcipes_saved_token';

  CollectionReference get _tokensCollection =>
      _firestore.collection('access_tokens');

  Future<String> getDeviceIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    String? localId = prefs.getString(_localDeviceIdKey);

    if (localId == null || localId.trim().isEmpty) {
      localId = const Uuid().v4();
      await prefs.setString(_localDeviceIdKey, localId);
    }

    return localId;
  }

  Future<AccessToken?> checkCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_savedTokenKey);

    if (savedToken == null || savedToken.trim().isEmpty) {
      return null;
    }

    try {
      final docSnap = await _tokensCollection.doc(savedToken).get();
      if (!docSnap.exists) {
        await prefs.remove(_savedTokenKey);
        return null;
      }

      final token = AccessToken.fromFirestore(docSnap);
      final currentDeviceId = await getDeviceIdentifier();
      
      if (token.status != TokenStatus.active ||
          (!token.isAdmin && !token.isDeviceRegistered(currentDeviceId))) {
        await prefs.remove(_savedTokenKey);
        return null;
      }

      return token;
    } catch (_) {
      await prefs.remove(_savedTokenKey);
      return null;
    }
  }

  Future<AccessToken?> validateToken(String rawKey) async {
    final cleanKey = rawKey.trim().toUpperCase();
    if (cleanKey.isEmpty) return null;

    final currentDeviceId = await getDeviceIdentifier();
    final docRef = _tokensCollection.doc(cleanKey);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      return null;
    }

    final token = AccessToken.fromFirestore(docSnap);

    if (token.status == TokenStatus.revoked) {
      throw 'Acesso revogado pela administração.';
    }

    // Admins bypass single-device locking to prevent locking out of developer console
    if (token.isAdmin) {
      await docRef.update({
        'status': 'active',
        'registeredDeviceId': currentDeviceId,
        'lastAccessedAt': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedTokenKey, cleanKey);
      return token;
    }

    // Standard user existing binding verification
    if (token.isDeviceRegistered(currentDeviceId)) {
      if (token.status == TokenStatus.pendingReview) {
        throw 'Dispositivo em análise por segurança.';
      }

      await docRef.update({
        'registeredDeviceIds': FieldValue.arrayUnion([currentDeviceId]),
        'lastAccessedAt': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedTokenKey, cleanKey);
      return token;
    }

    // Standard user initial or additional binding (up to maxDevices)
    if (token.hasAvailableSlot) {
      if (token.status == TokenStatus.pendingReview) {
        throw 'Dispositivo em análise por segurança.';
      }

      final String currentModel = kIsWeb ? 'Web Browser' : 'Mobile Device';
      final bool isFirstDevice = token.registeredDeviceIds.isEmpty;

      await docRef.update({
        if (isFirstDevice) 'registeredDeviceId': currentDeviceId,
        if (isFirstDevice) 'deviceModel': currentModel,
        if (isFirstDevice) 'firstAccessedAt': FieldValue.serverTimestamp(),
        'registeredDeviceIds': FieldValue.arrayUnion([currentDeviceId]),
        'deviceModels': [...token.deviceModels, currentModel],
        'maxDevices': token.maxDevices,
        'status': 'active',
        'lastAccessedAt': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedTokenKey, cleanKey);

      final updatedSnap = await docRef.get();
      return AccessToken.fromFirestore(updatedSnap);
    }

    // Standard user hardware mismatch (quota exceeded)
    await docRef.update({
      'status': 'pending_review',
      'attemptedDeviceId': currentDeviceId,
      'attemptedDeviceModel': kIsWeb ? 'Web Browser' : 'Mobile Device',
      'lastAccessedAt': FieldValue.serverTimestamp(),
    });

    throw 'Dispositivo não reconhecido. O acesso foi bloqueado para análise por segurança.';
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedTokenKey);
  }
}