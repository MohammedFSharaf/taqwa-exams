import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Halaqa {
  final String id, name;
  Halaqa(this.id, this.name);
}

class Student {
  final String id, name, halaqaId;
  final bool pending;
  Student(this.id, this.name, this.halaqaId, this.pending);
}

/// كل التعامل مع Firebase والتخزين المحلي
class Repo {
  Repo._();
  static final Repo I = Repo._();

  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  late SharedPreferences prefs;
  final List<StreamSubscription> _subs = [];

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
  }

  String? get uid => auth.currentUser?.uid;

  /// أول تشغيل فقط يحتاج إنترنت، بعدها الدخول محفوظ على الجهاز
  Future<bool> ensureSignedIn() async {
    if (auth.currentUser != null) return true;
    try {
      await auth.signInAnonymously().timeout(const Duration(seconds: 25));
      return auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  /// يبقي القوائم محدّثة في ذاكرة الجهاز كلما توفر الإنترنت
  void startSync() {
    if (_subs.isNotEmpty) return;
    for (final c in ['halaqat', 'students', 'examiners']) {
      _subs.add(db.collection(c).snapshots().listen((_) {}, onError: (_) {}));
    }
    _subs.add(db.collection('settings').doc('app').snapshots().listen((d) {
      final p = d.data()?['password'];
      if (p is String && p.isNotEmpty) prefs.setString('appPassword', p);
    }, onError: (_) {}));
  }

  Future<void> fetchPasswordOnce() async {
    try {
      final d = await db.collection('settings').doc('app').get().timeout(const Duration(seconds: 15));
      final p = d.data()?['password'];
      if (p is String && p.isNotEmpty) await prefs.setString('appPassword', p);
    } catch (_) {}
  }

  String? get appPassword => prefs.getString('appPassword');

  String get deviceId {
    var id = prefs.getString('deviceId');
    if (id == null) {
      id = const Uuid().v4();
      prefs.setString('deviceId', id);
    }
    return id;
  }

  String? get examinerName => prefs.getString('examinerName');
  Future<void> setExaminerName(String n) => prefs.setString('examinerName', n);

  Stream<List<Halaqa>> halaqat() => db.collection('halaqat').snapshots().map((s) {
        final l = s.docs.map((d) => Halaqa(d.id, (d.data()['name'] ?? '').toString())).toList();
        l.sort((a, b) => a.name.compareTo(b.name));
        return l;
      });

  Stream<List<Student>> students(String halaqaId) => db
          .collection('students')
          .where('halaqaId', isEqualTo: halaqaId)
          .snapshots()
          .map((s) {
        final l = s.docs
            .map((d) => Student(d.id, (d.data()['name'] ?? '').toString(),
                (d.data()['halaqaId'] ?? '').toString(), d.data()['status'] == 'pending'))
            .toList();
        l.sort((a, b) => a.name.compareTo(b.name));
        return l;
      });

  Stream<List<String>> examiners() => db.collection('examiners').snapshots().map((s) {
        final l = s.docs.map((d) => (d.data()['name'] ?? '').toString()).where((n) => n.isNotEmpty).toList();
        l.sort();
        return l;
      });

  /// طالب جديد يضيفه المختبر — يُحفظ فوراً على الجهاز ويُرفع عند توفر الإنترنت
  Student addPendingStudent(String name, String halaqaId) {
    final ref = db.collection('students').doc();
    ref.set({
      'name': name,
      'halaqaId': halaqaId,
      'status': 'pending',
      'createdBy': examinerName ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    }).then((_) {}, onError: (Object e) {});
    return Student(ref.id, name, halaqaId, true);
  }

  /// حفظ الاختبار — لا ننتظر السيرفر، Firestore يرفعه تلقائياً عند الاتصال
  void saveExam(String id, Map<String, dynamic> data) {
    db.collection('exams').doc(id).set(data).then((_) {}, onError: (Object e) {});
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myExams() => db
      .collection('exams')
      .where('authorUid', isEqualTo: uid)
      .snapshots(includeMetadataChanges: true);
}
