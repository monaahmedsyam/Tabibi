import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseService api = FirebaseService();

  User? user;
  AppUser? profile;
  bool loading = true;

  StreamSubscription<User?>? _userSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  void init() {
    _userSub = api.auth.authStateChanges().listen((firebaseUser) {
      user = firebaseUser;
      _profileSub?.cancel();

      if (firebaseUser == null) {
        profile = null;
        loading = false;
        notifyListeners();
        return;
      }

      loading = true;
      notifyListeners();
      _profileSub = api.userDoc(firebaseUser.uid).listen((doc) {
        profile = doc.exists ? AppUser.fromDoc(doc) : null;
        loading = false;
        notifyListeners();
        _syncMessaging(firebaseUser.uid);
      });
    });
  }

  Future<void> _syncMessaging(String uid) async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await api.db.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
    } catch (_) {
      // Notifications are optional and must not block authentication.
    }
  }

  Future<void> logout() => api.logout();

  @override
  void dispose() {
    _userSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
