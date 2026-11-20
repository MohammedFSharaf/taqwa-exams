import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../daily.dart';
import '../logic.dart';
import '../repo.dart';
import 'new_exam.dart';
import 'widgets.dart';

class ReadyEntry {
  final Student student;
  final Halaqa? halaqa;
  final PathStep step;
  final bool byPermit;
  ReadyEntry(this.student, this.halaqa, this.step, this.byPermit);
}

/// يتابع الطلاب الجاهزين للاختبار (سمّعوا المطلوب كاملاً في السجل اليومي)
class ReadyWatcher extends ChangeNotifier {
  static final ReadyWatcher I = ReadyWatcher._();
  ReadyWatcher._();

  bool _started = false;
  bool loaded = false;
  List<ReadyEntry> entries = [];
  List<Student> _students = [];
  List<Halaqa> _halaqat = [];
  List<Map<String, dynamic>> _exams = [], _logs = [], _progress = [], _permits = [];
  int _got = 0;
  Timer? _debounce;

  void start() {
    if (_started) return;
    _started = true;
    void got() {
      _got++;
      _schedule();
    }

    Repo.I.allStudents().listen((v) {
      _students = v;
      got();
    }, onError: (_) {});
    Repo.I.halaqat().listen((v) {
      _halaqat = v;
      got();
    }, onError: (_) {});
    Repo.I.allExams().listen((q) {
      _exams = q.docs.map((d) => d.data()).toList();
      got();
    }, onError: (_) {});
    Repo.I.recentLogs(180).listen((v) {
      _logs = v;
      got();
    }, onError: (_) {});
    Repo.I.allProgress().listen((v) {
      _progress = v;
      got();
    }, onError: (_) {});
    Repo.I.allPermits().listen((v) {
      _permits = v;
      got();
    }, onError: (_) {});
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _recalc);
  }

  static int _ms(dynamic t) => t is Timestamp ? t.millisecondsSinceEpoch : 0;

  void _recalc() {
    final logsBy = <String, List<Map<String, dynamic>>>{};
    for (final l in _logs) {
      (logsBy[(l['studentId'] ?? '').toString()] ??= []).add(l);
    }
    final examsBy = <String, List<Map<String, dynamic>>>{};
    for (final e in _exams) {
      (examsBy[(e['studentId'] ?? '').toString()] ??= []).add(e);
    }
    final progBy = {for (final p in _progress) (p['id'] ?? '').toString(): p};
    final hById = {for (final h in _halaqat) h.id: h};
    final out = <ReadyEntry>[];
    for (final s in _students) {
      if (s.pending) continue;
      final ex = examsBy[s.id] ?? const [];
      final passed = {
        for (final e in ex)
          if (e['passed'] == true) '${e['type']}|${e['startJuz']}'
      };
      final step = nextPathStep(s.pathDir, s.pathStart, passed);
      if (step == null) continue;
      var last = 0;
      for (final e in ex) {
        final m = _ms(e['createdAt']);
        if (m > last) last = m;
      }
      final lastDate = last == 0 ? '' : dayKey(DateTime.fromMillisecondsSinceEpoch(last));
      var lastSame = 0;
      for (final e in ex) {
        if (e['type'] == step.type && e['startJuz'] == step.start) {
          final m = _ms(e['createdAt']);
          if (m > lastSame) lastSame = m;
        }
      }
      final permit = _permits.any((p) =>
          p['studentId'] == s.id &&
          p['type'] == step.type &&
          p['startJuz'] == step.start &&
          ((p['grantedAtMs'] ?? 0) as num) > lastSame);
      final logs = logsBy[s.id] ?? const <Map<String, dynamic>>[];
      final hasDaily = logs.isNotEmpty || progBy.containsKey(s.id);
      if (!hasDaily && !permit) continue;
      final r = examReadiness(s.pathDir, s.pathStart, passed, logs, progBy[s.id], lastDate);
      if (r.ok || permit) out.add(ReadyEntry(s, hById[s.halaqaId], step, !r.ok && permit));
    }
    out.sort((a, b) {
      final c = (a.halaqa?.name ?? '').compareTo(b.halaqa?.name ?? '');
      return c != 0 ? c : a.student.name.compareTo(b.student.name);
    });
    entries = out;
    loaded = _got >= 6;
    notifyListeners();
  }
}

/// بطاقة الصفحة الرئيسية للمختبر
class ReadyCard extends StatelessWidget {
  const ReadyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ReadyWatcher.I,
      builder: (context, _) {
        final n = ReadyWatcher.I.entries.length;
        return Card(
          color: n > 0 ? const Color(0xFFE8F3EC) : null,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            title: const Text('جاهزون للاختبار', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            subtitle: Text(
              !ReadyWatcher.I.loaded
                  ? 'جارٍ التحميل…'
                  : n == 0
                      ? 'لا يوجد طلاب جاهزون الآن'
                      : 'سمّعوا المطلوب كاملاً في السجل اليومي',
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: n > 0 ? brandGreen : Colors.grey.shade400, borderRadius: BorderRadius.circular(14)),
              child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReadyScreen())),
          ),
        );
      },
    );
  }
}

class ReadyScreen extends StatelessWidget {
  const ReadyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const BrandTitle('جاهزون للاختبار')),
      body: AnimatedBuilder(
        animation: ReadyWatcher.I,
        builder: (context, _) {
          final w = ReadyWatcher.I;
          if (!w.loaded) return const Center(child: CircularProgressIndicator());
          if (w.entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'لا يوجد طلاب جاهزون للاختبار الآن.\n\nيظهر الطالب هنا بعد أن يُتمّ حفظ الجزء ويُسمّعه كاملاً مراجعةً في جلسة واحدة في السجل اليومي، أو بتصريح من الإدارة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 15, height: 1.7),
                ),
              ),
            );
          }
          final items = <Widget>[];
          String? lastH;
          var i = 0;
          for (final e in w.entries) {
            final hn = e.halaqa?.name ?? '';
            if (hn != lastH) {
              lastH = hn;
              items.add(Padding(
                padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
                child: Text(hn, style: const TextStyle(color: brandGreen, fontWeight: FontWeight.bold, fontSize: 15)),
              ));
            }
            i++;
            items.add(Card(
              color: Colors.white,
              surfaceTintColor: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE8F3EC),
                  child: Text('$i', style: const TextStyle(color: brandGreen, fontWeight: FontWeight.bold)),
                ),
                title: Text(e.student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(e.step.label + (e.byPermit ? '\nبتصريح من الإدارة' : ''),
                    style: TextStyle(color: e.byPermit ? const Color(0xFF9A6700) : Colors.black54)),
                isThreeLine: e.byPermit,
                trailing: FilledButton(
                  onPressed: e.halaqa == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => NewExamScreen(initialHalaqa: e.halaqa, initialStudent: e.student))),
                  child: const Text('اختبار'),
                ),
              ),
            ));
          }
          return ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: items);
        },
      ),
    );
  }
}
