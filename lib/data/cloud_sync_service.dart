import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/models.dart';
import '../core/split_bill.dart';

class CloudSyncService {
  CloudSyncService._();
  static final instance = CloudSyncService._();
  final _auth = FirebaseAuth.instance;
  final _store = FirebaseFirestore.instance;
  Future<void> signInWithGoogle() async {
    UserCredential credential;
    if (kIsWeb) {
      credential = await _auth.signInWithPopup(GoogleAuthProvider());
    } else {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize();
      final account = await signIn.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw FirebaseAuthException(code: 'missing-id-token');
      credential = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: token),
      );
    }
    await ensureProfile(credential.user!);
  }

  Future<void> ensureProfile(User user) async {
    final profile = _store.collection('users').doc(user.uid);
    if (!(await profile.get()).exists) {
      await profile.set({
        'displayName': user.displayName ?? '',
        'email': user.email,
        'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    await profile.set({
      'email': user.email,
      'photoUrl': user.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updatePersonalProfile({
    required String displayName,
    String? phone,
    String? note,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _store.collection('users').doc(user.uid).set({
      'displayName': displayName.trim(),
      'phone': phone?.trim().isEmpty ?? true ? null : phone!.trim(),
      'note': note?.trim().isEmpty ?? true ? null : note!.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await user.updateDisplayName(displayName.trim());
  }

  Future<void> deleteTransaction(String id) =>
      _deleteDocument(collection: 'transactions', id: id);

  Future<void> deleteBill(String id) =>
      _deleteDocument(collection: 'bills', id: id);

  Future<void> _deleteDocument({
    required String collection,
    required String id,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _store
        .collection('users')
        .doc(user.uid)
        .collection(collection)
        .doc(id)
        .delete();
  }

  Future<void> upload(LedgerSnapshot snapshot) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await ensureProfile(user);
    final batch = _store.batch();
    final base = _store.collection('users').doc(user.uid);
    for (final person in snapshot.people) {
      batch.set(base.collection('people').doc(person.id), {
        ...person.toJson(),
        'ownerId': user.uid,
      }, SetOptions(merge: true));
    }
    for (final transaction in snapshot.transactions) {
      batch.set(
        base.collection('transactions').doc(transaction.id),
        {...transaction.toJson(includeLocalPhoto: false), 'ownerId': user.uid},
        SetOptions(merge: true),
      );
    }
    for (final bill in snapshot.bills) {
      batch.set(base.collection('bills').doc(bill.id), {
        ...bill.toJson(includeLocalPhoto: false),
        'ownerId': user.uid,
      }, SetOptions(merge: true));
    }
    batch.set(
      base.collection('settings').doc('profile'),
      snapshot.settings.toJson(),
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Replaces ledger records without deleting the user's account profile.
  Future<void> replaceLedger(LedgerSnapshot snapshot) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final base = _store.collection('users').doc(user.uid);
    final snapshots = await Future.wait([
      base.collection('people').get(),
      base.collection('transactions').get(),
      base.collection('bills').get(),
      base.collection('settings').doc('profile').get(),
    ]);
    final references = <DocumentReference>[
      for (final snapshot in snapshots.take(3))
        ...(snapshot as QuerySnapshot).docs.map(
          (document) => document.reference,
        ),
      if ((snapshots[3] as DocumentSnapshot).exists)
        (snapshots[3] as DocumentSnapshot).reference,
    ];
    for (var start = 0; start < references.length; start += 450) {
      final batch = _store.batch();
      for (final reference in references.skip(start).take(450)) {
        batch.delete(reference);
      }
      await batch.commit();
    }
    await upload(snapshot);
  }

  Future<LedgerSnapshot?> download() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final base = _store.collection('users').doc(user.uid);
    final results = await Future.wait([
      base.collection('people').get(),
      base.collection('transactions').get(),
      base.collection('bills').get(),
      base.collection('settings').doc('profile').get(),
    ]);
    final people = (results[0] as QuerySnapshot).docs
        .map((doc) => Person.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
    final transactions = (results[1] as QuerySnapshot).docs
        .map(
          (doc) =>
              LedgerTransaction.fromJson(doc.data() as Map<String, dynamic>),
        )
        .toList();
    final bills = (results[2] as QuerySnapshot).docs
        .map((doc) => SplitBill.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
    final settingsDoc = results[3] as DocumentSnapshot;
    final settings = settingsDoc.exists
        ? AppSettings.fromJson(settingsDoc.data() as Map<String, dynamic>)
        : const AppSettings();
    return LedgerSnapshot(
      people: people,
      transactions: transactions,
      bills: bills,
      settings: settings,
    );
  }

  Future<void> clearAllData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final base = _store.collection('users').doc(user.uid);
    final snapshots = await Future.wait([
      base.collection('people').get(),
      base.collection('transactions').get(),
      base.collection('bills').get(),
      base.collection('settings').get(),
    ]);
    final references = <DocumentReference>[
      for (final snapshot in snapshots)
        ...(snapshot as QuerySnapshot).docs.map(
          (document) => document.reference,
        ),
      base,
    ];
    for (var start = 0; start < references.length; start += 450) {
      final batch = _store.batch();
      for (final reference in references.skip(start).take(450)) {
        batch.delete(reference);
      }
      await batch.commit();
    }
  }
}
