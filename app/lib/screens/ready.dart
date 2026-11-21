import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../daily.dart';
import '../logic.dart';
import '../repo.dart';
import 'new_exam.dart';
import 'pick_student.dart';
import 'ui.dart';
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
  /// معلومات كل طالب: الاختبار التالي، وهل رسب فيه سابقاً
  Map<String, ({String label, bool retest})> info = {};
  List<Student> get students => _students;
  List<Halaqa> get halaqat => _halaqat;
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
    final inf = <String, ({String label, bool retest})>{};
    for (final s in _students) {
      final ex = examsBy[s.id] ?? const [];
      final passed = {
        for (final e in ex)
          if (e['passed'] == true) '${e['type']}|${e['startJuz']}'
      };
      final step = nextPathStep(s.pathDir, s.pathStart, passed, s.pathFrom);
      inf[s.id] = (
        label: step?.label ?? 'أتمّ المسار',
        retest: step != null && ex.any((e) => e['type'] == step.type && e['startJuz'] == step.start && e['passed'] != true),
      );
      if (s.pending) continue;
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
      final r = examReadiness(s.pathDir, s.pathStart, passed, logs, progBy[s.id], lastDate, fromKey: s.pathFrom);
      if (r.ok || permit) out.add(ReadyEntry(s, hById[s.halaqaId], step, !r.ok && permit));
    }
    out.sort((a, b) {
      final c = (a.halaqa?.name ?? '').compareTo(b.halaqa?.name ?? '');
      return c != 0 ? c : a.student.name.compareTo(b.student.name);
    });
    entries = out;
    info = inf;
    loaded = _got >= 6;
    notifyListeners();
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
            return SingleChildScrollView(
              child: EmptyState(
                icon: Icons.fact_check_outlined,
                title: 'لا يوجد جاهزون الآن',
                text: 'يظهر الطالب هنا بعد أن يُتمّ حفظ الجزء ويُسمّعه كاملاً في جلسة واحدة، أو بتصريح من الإدارة.',
                action: SizedBox(
                  width: 220,
                  child: GoldButton(
                    text: 'اختبار جديد',
                    icon: Icons.add_rounded,
                    onPressed: () => Navigator.of(context)
                        .pushReplacement(MaterialPageRoute(builder: (_) => const PickStudentScreen())),
                  ),
                ),
              ),
            );
          }
          final items = <Widget>[];
          String? lastH;
          for (final e in w.entries) {
            final hn = e.halaqa?.name ?? '';
            if (hn != lastH) {
              lastH = hn;
              items.add(SectionLabel(hn, color: context.accent));
            }
            items.add(Panel(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              onTap: e.halaqa == null
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => NewExamScreen(initialHalaqa: e.halaqa, initialStudent: e.student))),
              child: Row(children: [
                NameAvatar(e.student.name, color: okGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.student.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.ink)),
                    Text(e.step.label + (e.byPermit ? ' · بتصريح من الإدارة' : ''),
                        style: TextStyle(color: e.byPermit ? context.goldFg : context.sub, fontSize: 12.5)),
                  ]),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFF2C94C), Color(0xFFDDA915)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('اختبار',
                      style: TextStyle(color: Color(0xFF3B2C00), fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ]),
            ));
          }
          return ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 24), children: items);
        },
      ),
    );
  }
}
