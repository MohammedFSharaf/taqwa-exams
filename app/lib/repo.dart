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
  final bool inactive; // منقطع: لا يظهر في القوائم
  final String pathDir; // desc = من الناس، asc = من البقرة
  final int pathStart;
  final String? pathFrom; // مرحلة البداية (اختيارية)
  Student(this.id, this.name, this.halaqaId, this.pending, {this.pathDir = 'desc', int? pathStart, this.inactive = false, this.pathFrom})
      : pathStart = pathStart ?? (pathDir == 'asc' ? 1 : 30);

  static Student fromDoc(String id, Map<String, dynamic> d) {
    final dir = d['pathDir'] == 'asc' ? 'asc' : 'desc';
    final st = d['pathStart'];
    final start = (st is num && st >= 1 && st <= 30) ? st.toInt() : null;
    return Student(id, (d['name'] ?? '').toString(), (d['halaqaId'] ?? '').toString(), d['status'] == 'pending',
        pathDir: dir,
        pathStart: start,
        inactive: d['status'] == 'inactive',
        pathFrom: d['pathFrom'] is String && (d['pathFrom'] as String).isNotEmpty ? d['pathFrom'] as String : null);
  }
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
    for (final c in ['halaqat', 'students', 'examiners', 'exams', 'permits', 'sheikhs', 'holidays']) {
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
            .map((d) => Student.fromDoc(d.id, d.data()))
            .where((x) => !x.inactive)
            .toList();
        l.sort((a, b) => a.name.compareTo(b.name));
        return l;
      });

  /// كل الطلاب من كل الحلقات (للبحث السريع)
  Stream<List<Student>> allStudents() => db.collection('students').snapshots().map((s) {
        final l = s.docs
            .map((d) => Student.fromDoc(d.id, d.data()))
            .where((x) => !x.inactive)
            .toList();
        l.sort((a, b) => a.name.compareTo(b.name));
        return l;
      });

  /// كل اختبارات المركز
  Stream<QuerySnapshot<Map<String, dynamic>>> allExams() =>
      db.collection('exams').snapshots(includeMetadataChanges: true);

  Stream<List<String>> examiners() => db.collection('examiners').snapshots().map((s) {
        final l = s.docs.map((d) => (d.data()['name'] ?? '').toString()).where((n) => n.isNotEmpty).toList();
        l.sort();
        return l;
      });

  /// طالب جديد يضيفه المختبر — يُحفظ فوراً على الجهاز ويُرفع عند توفر الإنترنت
  Student addPendingStudent(String name, String halaqaId, String pathDir, int pathStart) {
    final ref = db.collection('students').doc();
    ref.set({
      'name': name,
      'halaqaId': halaqaId,
      'status': 'pending',
      'pathDir': pathDir,
      'pathStart': pathStart,
      'createdBy': examinerName ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    }).then((_) {}, onError: (Object e) {});
    return Student(ref.id, name, halaqaId, true, pathDir: pathDir, pathStart: pathStart);
  }

  /// حفظ الاختبار — لا ننتظر السيرفر، Firestore يرفعه تلقائياً عند الاتصال
  void saveExam(String id, Map<String, dynamic> data) {
    db.collection('exams').doc(id).set(data).then((_) {}, onError: (Object e) {});
  }

  /// اختبارات طالب معيّن من كل الأجهزة (لمعرفة الإعادة)
  Stream<List<Map<String, dynamic>>> studentExams(String studentId) => db
      .collection('exams')
      .where('studentId', isEqualTo: studentId)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  /// أذونات الإدارة لإعادة اختبار ناجح لطالب معيّن
  Stream<List<Map<String, dynamic>>> permitsFor(String studentId) => db
      .collection('permits')
      .where('studentId', isEqualTo: studentId)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  // ===== السجل اليومي =====
  List<Map<String, dynamic>> _docs(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map((d) => <String, dynamic>{'id': d.id, ...d.data()}).toList();

  Stream<List<Map<String, dynamic>>> sheikhs() => db.collection('sheikhs').snapshots().map(_docs);
  Stream<Map<String, dynamic>> settings() =>
      db.collection('settings').doc('app').snapshots().map((d) => d.data() ?? <String, dynamic>{});
  Stream<List<Map<String, dynamic>>> holidays() => db.collection('holidays').snapshots().map(_docs);
  Stream<List<Map<String, dynamic>>> halaqaLogs(String halaqaId) => db
      .collection('logs')
      .where('halaqaId', isEqualTo: halaqaId)
      .snapshots(includeMetadataChanges: true)
      .map((s) => s.docs
          .map((d) => <String, dynamic>{'id': d.id, '_pending': d.metadata.hasPendingWrites, ...d.data()})
          .toList());
  Stream<List<Map<String, dynamic>>> halaqaProgress(String halaqaId) =>
      db.collection('progress').where('halaqaId', isEqualTo: halaqaId).snapshots().map(_docs);
  Stream<List<Map<String, dynamic>>> halaqaExams(String halaqaId) =>
      db.collection('exams').where('halaqaId', isEqualTo: halaqaId).snapshots().map(_docs);
  /// كل سجل طالب مرة واحدة (لمن بدأ جزءه قبل نافذة السجل الحديث)
  Future<List<Map<String, dynamic>>> studentLogsOnce(String studentId) async {
    final q = await db.collection('logs').where('studentId', isEqualTo: studentId).get();
    return q.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  Stream<List<Map<String, dynamic>>> studentLogs(String studentId) =>
      db.collection('logs').where('studentId', isEqualTo: studentId).snapshots().map(_docs);
  /// سجل آخر [days] يوماً لكل المركز (لقائمة الجاهزين للاختبار)
  Stream<List<Map<String, dynamic>>> recentLogs(int days) {
    final n = DateTime.now();
    final d = DateTime(n.year, n.month, n.day - days);
    String two(int n) => n.toString().padLeft(2, '0');
    final from = '${d.year}-${two(d.month)}-${two(d.day)}';
    return db.collection('logs').where('date', isGreaterThanOrEqualTo: from).snapshots().map(_docs);
  }

  Stream<List<Map<String, dynamic>>> allProgress() => db.collection('progress').snapshots().map(_docs);
  Stream<List<Map<String, dynamic>>> allPermits() => db.collection('permits').snapshots().map(_docs);

  Stream<Map<String, dynamic>?> studentProgress(String studentId) =>
      db.collection('progress').doc(studentId).snapshots().map((d) => d.data());

  void _fire(Future<void> f) => f.then((_) {}, onError: (Object e) {});

  /// سجل الطالب لليوم: مستند واحد لكل طالب في كل يوم
  void saveLog(String studentId, String date, Map<String, dynamic> data, {Map<String, dynamic>? prev}) {
    _fire(db.collection('logs').doc('${studentId}_$date').set({
      ...data,
      'studentId': studentId,
      'date': date,
      'updatedAt': FieldValue.serverTimestamp(),
      'clientAt': DateTime.now().millisecondsSinceEpoch,
    }));
    // تعديل تسميع سبق تسجيله ← سجل التعديلات
    if (prev != null && prev['status'] != null) {
      final before = logBrief(prev), after = logBrief(data);
      if (before != after) {
        _fire(db.collection('audit').add({
          'atMs': DateTime.now().millisecondsSinceEpoch,
          'at': FieldValue.serverTimestamp(),
          'by': (data['sheikhName'] ?? '').toString(),
          'source': 'app',
          'action': 'تعديل تسميع',
          'target': (data['studentName'] ?? '').toString(),
          'studentId': studentId,
          'details': date,
          'before': before,
          'after': after,
        }));
      }
    }
  }

  static String logBrief(Map<String, dynamic> l) {
    String f(dynamic n) => (n is num ? n.toDouble() : 0.0).toStringAsFixed(1);
    final st = switch (l['status']) {
      'recited' => 'سمّع',
      'norecite' => 'لم يسمّع',
      'absent' => 'غائب',
      'excused' => 'غائب بعذر',
      _ => (l['status'] ?? '').toString(),
    };
    final parts = <String>[st];
    final nm = l['newMem'];
    if (nm is Map) parts.add('حفظ: ${nm['label'] ?? ''} (${f(l['newPages'])} ص)');
    final rv = l['reviews'];
    if (rv is List && rv.isNotEmpty) parts.add('مراجعة: ${f(l['reviewPages'])} ص');
    return parts.join(' · ');
  }

  /// نقطة البداية / آخر آية محفوظة
  void setProgress(String studentId, String halaqaId, int? lastG, String by) {
    _fire(db.collection('progress').doc(studentId).set({
      'halaqaId': halaqaId,
      'lastG': lastG,
      'fresh': lastG == null,
      'setBy': by,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)));
  }

  /// سورة البداية في جزء ('first' أول سورة بترتيب المصحف، 'last' آخر سورة)
  void setJuzStart(String studentId, String halaqaId, int juz, String start, String by) {
    _fire(db.collection('progress').doc(studentId).set({
      'halaqaId': halaqaId,
      'juzOrder': {'$juz': start},
      'juzOrderBy': by,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)));
  }

  void setHalaqaHoliday(String halaqaId, String date, bool on, String by) {
    final ref = db.collection('holidays').doc('${halaqaId}_$date');
    if (on) {
      _fire(ref.set({'halaqaId': halaqaId, 'date': date, 'reason': 'إجازة الحلقة', 'by': by}));
    } else {
      _fire(ref.delete());
    }
  }

  String? get sheikhId => prefs.getString('sheikhId');
  Future<void> setSheikhId(String? id) =>
      id == null ? prefs.remove('sheikhId') : prefs.setString('sheikhId', id);
  String? get lastRole => prefs.getString('lastRole');
  Future<void> setLastRole(String r) => prefs.setString('lastRole', r);

  Stream<QuerySnapshot<Map<String, dynamic>>> myExams() => db
      .collection('exams')
      .where('authorUid', isEqualTo: uid)
      .snapshots(includeMetadataChanges: true);
}
