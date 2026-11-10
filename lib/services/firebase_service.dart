import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  // ============================================================
  // USER
  // ============================================================

  Stream<DocumentSnapshot<Map<String, dynamic>>> userDoc(String uid) {
    return db.collection('users').doc(uid).snapshots();
  }

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = auth.currentUser;

    if (user == null) {
      return null;
    }

    final doc = await db.collection('users').doc(user.uid).get();

    return doc.data();
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String name,
    required String role,
    required String phone,
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;

    final status =
    ['clinic', 'pharmacy'].contains(role) ? 'pending' : 'active';

    await db.collection('users').doc(uid).set({
      'uid': uid,
      'name': name.trim(),
      'email': email.trim(),
      'role': role,
      'phone': phone.trim(),
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (status == 'pending') {
      await db.collection('join_requests').doc(uid).set({
        'uid': uid,
        'name': name.trim(),
        'email': email.trim(),
        'role': role,
        'phone': phone.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return credential;
  }

  Future<void> login(String email, String password) {
    return auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> logout() {
    return auth.signOut();
  }

  Future<void> reset(String email) {
    return auth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  // ============================================================
  // PROFILE UPDATE
  // ============================================================

  Future<void> updateProfile(
      String uid,
      Map<String, dynamic> values,
      ) async {
    await db.collection('users').doc(uid).update({
      ...values,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCurrentUserProfile(
      Map<String, dynamic> values,
      ) async {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception('المستخدم غير مسجل الدخول');
    }

    // منع تعديل الحقول الحساسة من شاشة الملف الشخصي
    final safeValues = Map<String, dynamic>.from(values);

    safeValues.remove('role');
    safeValues.remove('status');
    safeValues.remove('uid');
    safeValues.remove('clinicId');
    safeValues.remove('createdAt');
    safeValues.remove('email');

    safeValues['updatedAt'] = FieldValue.serverTimestamp();

    await db.collection('users').doc(user.uid).update(
      safeValues,
    );
  }

  // ============================================================
  // CHANGE EMAIL
  // ============================================================

  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final user = auth.currentUser;

    if (user == null || user.email == null) {
      throw Exception('المستخدم غير مسجل الدخول');
    }

    final cleanEmail = newEmail.trim();

    if (!_isValidEmail(cleanEmail)) {
      throw Exception('البريد الإلكتروني الجديد غير صحيح');
    }

    if (cleanEmail.toLowerCase() ==
        user.email!.trim().toLowerCase()) {
      throw Exception('البريد الإلكتروني الجديد هو نفس البريد الحالي');
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );

    try {
      // التحقق من كلمة المرور الحالية أولًا
      await user.reauthenticateWithCredential(
        credential,
      );

      // Firebase يرسل رابط تحقق للبريد الجديد
      await user.verifyBeforeUpdateEmail(
        cleanEmail,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e));
    }
  }

  /// بعد أن يضغط المستخدم على رابط تأكيد البريد الجديد،
  /// نستدعي هذه الدالة لمزامنة البريد الجديد مع Firestore.
  Future<bool> syncCurrentEmail() async {
    final user = auth.currentUser;

    if (user == null) {
      return false;
    }

    try {
      await user.reload();

      final refreshedUser = auth.currentUser;

      if (refreshedUser == null ||
          refreshedUser.email == null) {
        return false;
      }

      final doc =
      await db.collection('users').doc(refreshedUser.uid).get();

      if (!doc.exists) {
        return false;
      }

      final firestoreEmail =
          doc.data()?['email']?.toString().trim() ?? '';

      final authEmail =
      refreshedUser.email!.trim();

      if (firestoreEmail != authEmail) {
        await db.collection('users').doc(refreshedUser.uid).update({
          'email': authEmail,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = auth.currentUser;

    if (user == null || user.email == null) {
      throw Exception('المستخدم غير مسجل الدخول');
    }

    if (currentPassword.isEmpty) {
      throw Exception('يرجى إدخال كلمة المرور الحالية');
    }

    if (newPassword.length < 6) {
      throw Exception(
        'كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل',
      );
    }

    if (currentPassword == newPassword) {
      throw Exception(
        'كلمة المرور الجديدة يجب أن تختلف عن الحالية',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );

    try {
      await user.reauthenticateWithCredential(
        credential,
      );

      await user.updatePassword(
        newPassword,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e));
    }
  }

  // ============================================================
  // FIREBASE STORAGE
  // ============================================================

  Future<String> upload(String uid, File file) async {
    final ref = storage.ref(
      'profiles/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    await ref.putFile(file);

    return ref.getDownloadURL();
  }

  // ============================================================
  // DOCTOR
  // ============================================================

  Future<void> addDoctor(Map<String, dynamic> values) async {
    FirebaseApp? secondaryApp;

    try {
      final clinicId = auth.currentUser?.uid;

      if (clinicId == null) {
        throw Exception('يجب تسجيل الدخول بحساب العيادة');
      }

      final clinicDoc =
      await db.collection('users').doc(clinicId).get();

      if (!clinicDoc.exists) {
        throw Exception('بيانات العيادة غير موجودة');
      }

      final clinicData = clinicDoc.data();

      if (clinicData?['role'] != 'clinic') {
        throw Exception(
          'غير مصرح لهذا الحساب بإضافة طبيب',
        );
      }

      if (clinicData?['status'] != 'active') {
        throw Exception(
          'يجب تفعيل حساب العيادة أولًا',
        );
      }

      final email =
          values['email']?.toString().trim() ?? '';

      final password =
          values['password']?.toString().trim() ?? '';

      final name =
          values['name']?.toString().trim() ?? '';

      final specialty =
          values['specialty']?.toString().trim() ?? '';

      final phone =
          values['phone']?.toString().trim() ?? '';

      if (name.isEmpty) {
        throw Exception('يرجى إدخال اسم الطبيب');
      }

      if (email.isEmpty) {
        throw Exception(
          'يرجى إدخال البريد الإلكتروني للطبيب',
        );
      }

      if (!_isValidEmail(email)) {
        throw Exception(
          'البريد الإلكتروني غير صحيح',
        );
      }

      if (password.length < 6) {
        throw Exception(
          'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
        );
      }

      if (specialty.isEmpty) {
        throw Exception(
          'يرجى إدخال تخصص الطبيب',
        );
      }

      secondaryApp = await Firebase.initializeApp(
        name:
        'doctorCreation_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      final secondaryAuth =
      FirebaseAuth.instanceFor(
        app: secondaryApp,
      );

      final credential =
      await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final doctor = credential.user;

      if (doctor == null) {
        throw Exception(
          'تعذر إنشاء حساب الطبيب',
        );
      }

      final doctorUid = doctor.uid;

      await db.collection('users').doc(doctorUid).set({
        'uid': doctorUid,
        'name': name,
        'email': email,
        'phone': phone,
        'specialty': specialty,
        'role': 'doctor',
        'status': 'active',
        'clinicId': clinicId,
        'licenseNumber': '',
        'experienceYears': 0,
        'bio': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await secondaryAuth.signOut();
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e));
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'حدث خطأ أثناء إنشاء الطبيب',
      );
    } finally {
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (_) {}
      }
    }
  }

  // ============================================================
  // APPOINTMENT SLOTS
  // ============================================================

  Future<void> saveSlot(
      Map<String, dynamic> values,
      ) {
    return db.collection('slots').add({
      ...values,
      'booked': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // BOOK APPOINTMENT
  // ============================================================

  Future<void> book(
      String slotId,
      String patientId,
      ) async {
    final slotRef =
    db.collection('slots').doc(slotId);

    final appointmentRef =
    db.collection('appointments').doc(
      '${slotId}_$patientId',
    );

    await db.runTransaction(
          (transaction) async {
        final slotSnapshot =
        await transaction.get(slotRef);

        if (!slotSnapshot.exists) {
          throw Exception(
            'الموعد غير موجود',
          );
        }

        final slot =
        slotSnapshot.data()!;

        final capacity =
            (slot['capacity'] as num?)?.toInt() ??
                0;

        final booked =
            (slot['booked'] as num?)?.toInt() ??
                0;

        if (booked >= capacity) {
          throw Exception(
            'الموعد ممتلئ',
          );
        }

        final existingAppointment =
        await transaction.get(
          appointmentRef,
        );

        if (existingAppointment.exists) {
          final existingData =
          existingAppointment.data();

          if (existingData?['status'] ==
              'booked') {
            throw Exception(
              'تم حجز هذا الموعد مسبقًا',
            );
          }
        }

        transaction.update(
          slotRef,
          {
            'booked': booked + 1,
          },
        );

        if (existingAppointment.exists) {
          transaction.update(
            appointmentRef,
            {
              'status': 'booked',
              'createdAt':
              FieldValue.serverTimestamp(),
            },
          );
        } else {
          transaction.set(
            appointmentRef,
            {
              'slotId': slotId,
              'patientId': patientId,
              'doctorId': slot['doctorId'],
              'clinicId': slot['clinicId'],
              'date': slot['date'],
              'status': 'booked',
              'createdAt':
              FieldValue.serverTimestamp(),
            },
          );
        }
      },
    );
  }

  // ============================================================
  // CANCEL APPOINTMENT
  // ============================================================

  Future<void> cancel(
      String appointmentId,
      String slotId,
      ) async {
    if (slotId.isEmpty) {
      throw Exception(
        'بيانات الموعد غير مكتملة',
      );
    }

    final appointmentRef =
    db.collection('appointments').doc(
      appointmentId,
    );

    final slotRef =
    db.collection('slots').doc(
      slotId,
    );

    await db.runTransaction(
          (transaction) async {
        final appointmentSnapshot =
        await transaction.get(
          appointmentRef,
        );

        final slotSnapshot =
        await transaction.get(
          slotRef,
        );

        if (!appointmentSnapshot.exists ||
            !slotSnapshot.exists) {
          throw Exception(
            'الموعد غير موجود',
          );
        }

        if (appointmentSnapshot
            .data()?['status'] ==
            'cancelled') {
          return;
        }

        final booked =
            (slotSnapshot.data()?['booked']
            as num?)
                ?.toInt() ??
                0;

        transaction.update(
          appointmentRef,
          {
            'status': 'cancelled',
          },
        );

        transaction.update(
          slotRef,
          {
            'booked':
            booked > 0 ? booked - 1 : 0,
          },
        );
      },
    );
  }

  // ============================================================
  // PRESCRIPTION
  // ============================================================

  Future<void> prescription(
      Map<String, dynamic> values,
      ) {
    return db.collection('prescriptions').add({
      ...values,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // INVENTORY
  // ============================================================

  Future<void> inventory(
      Map<String, dynamic> values,
      ) {
    return db.collection('inventory').add({
      ...values,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // ADMIN REVIEW
  // ============================================================

  Future<void> review(
      String uid,
      bool approve,
      ) async {
    final status =
    approve ? 'active' : 'rejected';

    final batch = db.batch();

    batch.update(
      db.collection('join_requests').doc(uid),
      {
        'status': status,
        'reviewedAt':
        FieldValue.serverTimestamp(),
      },
    );

    batch.update(
      db.collection('users').doc(uid),
      {
        'status': status,
        'updatedAt':
        FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  String _authErrorMessage(
      FirebaseAuthException e,
      ) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'كلمة المرور الحالية غير صحيحة';

      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم مسبقًا';

      case 'invalid-email':
        return 'البريد الإلكتروني غير صحيح';

      case 'weak-password':
        return 'كلمة المرور الجديدة ضعيفة';

      case 'requires-recent-login':
        return 'يرجى تسجيل الدخول مرة أخرى ثم المحاولة';

      case 'too-many-requests':
        return 'تم إجراء محاولات كثيرة، يرجى المحاولة لاحقًا';

      case 'network-request-failed':
        return 'تحقق من اتصال الإنترنت';

      case 'user-disabled':
        return 'تم تعطيل هذا الحساب';

      case 'user-not-found':
        return 'الحساب غير موجود';

      case 'operation-not-allowed':
        return 'هذه العملية غير مفعلة في Firebase';

      default:
        return e.message ??
            'حدث خطأ في المصادقة';
    }
  }
}