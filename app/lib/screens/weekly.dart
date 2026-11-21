import 'package:flutter/material.dart';

import '../daily.dart';
import '../logic.dart';
import '../repo.dart';
import 'ui.dart';
import 'widgets.dart';

/// بداية الأسبوع (السبت) مع إزاحة بالأسابيع
DateTime weekStart(int offset) {
  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final back = (today.weekday - DateTime.saturday) % 7; // السبت = 6
  return today.subtract(Duration(days: back + 7 * offset));
}

String _dm(DateTime d) => '${d.day}/${d.month}';

String weekTitle(int offset) {
  final a = weekStart(offset);
  final b = a.add(const Duration(days: 5));
  return 'السبت ${_dm(a)} – الخميس ${_dm(b)}';
}

List<Map<String, dynamic>> weekLogs(List<Map<String, dynamic>> logs, int offset) {
  final a = dayKey(weekStart(offset)), b = dayKey(weekStart(offset).add(const Duration(days: 6)));
  final out = logs.where((l) {
    final d = (l['date'] ?? '').toString();
    return d.compareTo(a) >= 0 && d.compareTo(b) <= 0;
  }).toList()
    ..sort((x, y) => (x['date'] ?? '').toString().compareTo((y['date'] ?? '').toString()));
  return out;
}

double _num(dynamic v) => v is num ? v.toDouble() : 0;

/// ملخص أسبوع طالب
class WeekSum {
  final List<Map<String, dynamic>> logs;
  WeekSum(this.logs);
  int get present => logs.where((l) => l['status'] == 'recited' || l['status'] == 'norecite').length;
  int get absent => logs.where((l) => l['status'] == 'absent').length;
  int get sessions => logs.where((l) => l['holiday'] != true || l['status'] == 'recited').length;
  double get newPages => logs.fold(0.0, (a, l) => a + _num(l['newPages']));
  double get reviewPages => logs.fold(0.0, (a, l) => a + _num(l['reviewPages']));
  List<String> get newLabels => [
        for (final l in logs)
          if (l['newMem'] is Map && ((l['newMem'] as Map)['label'] ?? '').toString().isNotEmpty)
            (l['newMem'] as Map)['label'].toString()
      ];
  List<String> get reviewLabels {
    final out = <String>[];
    for (final l in logs) {
      for (final r in ((l['reviews'] as List?) ?? []).whereType<Map>()) {
        final t = (r['label'] ?? '').toString();
        if (t.isNotEmpty && !out.contains(t)) out.add(t);
      }
    }
    return out;
  }
}

Widget _statusDot(String? st) {
  final (Color c, String t) = switch (st) {
    'recited' => (okGreen, '✓'),
    'absent' => (const Color(0xFFC0392B), 'غ'),
    'excused' => (const Color(0xFFC88A12), 'ع'),
    'norecite' => (const Color(0xFFE57373), 'ل'),
    _ => (Colors.grey, '·'),
  };
  return Container(
    width: 20,
    height: 20,
    margin: const EdgeInsetsDirectional.only(end: 4),
    alignment: Alignment.center,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
  );
}

Widget _weekNav(BuildContext context, int offset, ValueChanged<int> set) => Panel(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(children: [
        IconButton(
          tooltip: 'الأسبوع السابق',
          onPressed: () {
            haptic();
            set(offset + 1);
          },
          icon: Transform.flip(flipX: true, child: Icon(Icons.chevron_left_rounded, color: context.accent)),
        ),
        Expanded(
          child: Column(children: [
            Text(weekTitle(offset),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.ink, fontWeight: FontWeight.w800, fontSize: 15)),
            if (offset == 0) Text('هذا الأسبوع', style: TextStyle(color: context.sub, fontSize: 11.5)),
          ]),
        ),
        IconButton(
          tooltip: 'الأسبوع التالي',
          onPressed: offset == 0
              ? null
              : () {
                  haptic();
                  set(offset - 1);
                },
          icon: Icon(Icons.chevron_left_rounded, color: offset == 0 ? context.line : context.accent),
        ),
      ]),
    );

Widget _kpi(BuildContext context, String n, String l, {Color? color}) => Expanded(
      child: Panel(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(children: [
          Text(n, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color ?? context.ink)),
          Text(l, style: TextStyle(fontSize: 12, color: context.sub)),
        ]),
      ),
    );

// ===================== سجل الأسبوع للحلقة =====================
class WeeklyScreen extends StatefulWidget {
  final String halaqaId, halaqaName;
  final List<Student> students;
  const WeeklyScreen({super.key, required this.halaqaId, required this.halaqaName, required this.students});

  @override
  State<WeeklyScreen> createState() => _WeeklyScreenState();
}

class _WeeklyScreenState extends State<WeeklyScreen> {
  int _offset = 0;
  late final Stream<List<Map<String, dynamic>>> _logs = Repo.I.halaqaLogs(widget.halaqaId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const BrandTitle('سجل الأسبوع')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _logs,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final week = weekLogs(snap.data!, _offset);
          final by = <String, List<Map<String, dynamic>>>{};
          for (final l in week) {
            (by[(l['studentId'] ?? '').toString()] ??= []).add(l);
          }
          final all = WeekSum(week);
          final counted = all.present + all.absent + week.where((l) => l['status'] == 'excused').length;
          final att = counted == 0 ? null : (all.present * 100 / counted).round();
          final absentMany = widget.students.where((s) => WeekSum(by[s.id] ?? const []).absent >= 2).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            children: [
              _weekNav(context, _offset, (v) => setState(() => _offset = v)),
              Row(children: [
                _kpi(context, att == null ? '—' : '$att%', 'الحضور', color: context.okFg),
                const SizedBox(width: 8),
                _kpi(context, fmtPages(all.newPages), 'صفحة حفظ'),
                const SizedBox(width: 8),
                _kpi(context, fmtPages(all.reviewPages), 'صفحة مراجعة'),
              ]),
              const SizedBox(height: 10),
              for (final s in absentMany)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: context.goldBg, borderRadius: BorderRadius.circular(14)),
                  child: Text('⚠ ${s.name} غاب ${WeekSum(by[s.id]!).absent} جلسات هالأسبوع',
                      style: TextStyle(color: context.goldFg, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              SectionLabel('${widget.halaqaName.isEmpty ? 'الطلاب' : widget.halaqaName} (${widget.students.length}) — اضغط على الطالب للتفاصيل'),
              if (week.isEmpty)
                const EmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'لا يوجد تسجيل بهذا الأسبوع',
                  text: 'التسميع الذي يُسجَّل في أيام هذا الأسبوع يظهر هنا.',
                ),
              if (week.isNotEmpty)
                for (final s in widget.students) _row(s, by[s.id] ?? const []),
            ],
          );
        },
      ),
    );
  }

  Widget _row(Student s, List<Map<String, dynamic>> logs) {
    final w = WeekSum(logs);
    final color = logs.isEmpty
        ? const Color(0xFF9AAAB6)
        : w.absent >= 2
            ? const Color(0xFFC0392B)
            : (w.present == 0 ? const Color(0xFFC88A12) : okGreen);
    final nl = w.newLabels, rl = w.reviewLabels;
    return Panel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StudentWeekScreen(student: s, halaqaId: widget.halaqaId, offset: _offset))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        NameAvatar(s.name, color: color, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: context.ink)),
            if (logs.isEmpty)
              Text('لا تسجيل هالأسبوع', style: TextStyle(color: context.sub, fontSize: 12.5))
            else ...[
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(children: [for (final l in logs) _statusDot(l['status'] as String?)]),
              ),
              _line('حفظ', nl.isEmpty ? '—' : '${nl.join('، ')}  (${fmtPages(w.newPages)} ص)'),
              _line('راجع', rl.isEmpty ? '—' : '${rl.join('، ')}  (${fmtPages(w.reviewPages)} ص)'),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _line(String a, String b) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '$a: ', style: TextStyle(color: context.sub, fontWeight: FontWeight.w700)),
            TextSpan(text: b, style: TextStyle(color: context.txt, fontWeight: FontWeight.w600)),
          ]),
          style: const TextStyle(fontSize: 12.5, height: 1.6),
        ),
      );
}

// ===================== سجل الطالب الأسبوعي =====================
class StudentWeekScreen extends StatefulWidget {
  final Student student;
  final String halaqaId;
  final int offset;
  const StudentWeekScreen({super.key, required this.student, required this.halaqaId, required this.offset});

  @override
  State<StudentWeekScreen> createState() => _StudentWeekScreenState();
}

class _StudentWeekScreenState extends State<StudentWeekScreen> {
  late int _offset = widget.offset;
  late final Stream<List<Map<String, dynamic>>> _logs = Repo.I.halaqaLogs(widget.halaqaId);

  static String _status(String? s) => switch (s) {
        'recited' => 'سمّع',
        'norecite' => 'لم يسمّع',
        'absent' => 'غائب',
        'excused' => 'غائب بعذر',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    return Scaffold(
      appBar: AppBar(title: const BrandTitle('سجل الطالب الأسبوعي')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _logs,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final logs = weekLogs(snap.data!.where((l) => l['studentId'] == s.id).toList(), _offset);
          final w = WeekSum(logs);
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            children: [
              Panel(
                child: Column(children: [
                  NameAvatar(s.name, color: brandBlue, size: 60),
                  const SizedBox(height: 6),
                  Text(s.name, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: context.ink)),
                ]),
              ),
              _weekNav(context, _offset, (v) => setState(() => _offset = v)),
              Row(children: [
                _kpi(context, '${w.present}/${logs.length}', 'حضر', color: context.okFg),
                const SizedBox(width: 8),
                _kpi(context, fmtPages(w.newPages), 'صفحة حفظ'),
                const SizedBox(width: 8),
                _kpi(context, fmtPages(w.reviewPages), 'صفحة مراجعة'),
              ]),
              const SizedBox(height: 10),
              if (logs.isEmpty)
                const EmptyState(icon: Icons.assignment_outlined, title: 'لا يوجد تسجيل بهذا الأسبوع'),
              for (final l in logs) _day(l),
            ],
          );
        },
      ),
    );
  }

  Widget _day(Map<String, dynamic> l) {
    final d = DateTime.tryParse((l['date'] ?? '').toString());
    final st = (l['status'] ?? '').toString();
    final (Color fg, Color bg) = switch (st) {
      'recited' => (context.okFg, context.okBg),
      'excused' => (context.goldFg, context.goldBg),
      _ => (context.badFg, context.badBg),
    };
    final nm = l['newMem'];
    final revs = ((l['reviews'] as List?) ?? []).whereType<Map>().toList();
    final notes = (l['notes'] ?? '').toString();
    Widget line(String a, String b) => Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '$a: ', style: TextStyle(color: context.sub, fontWeight: FontWeight.w700)),
              TextSpan(text: b, style: TextStyle(color: context.txt, fontWeight: FontWeight.w600)),
            ]),
            style: const TextStyle(fontSize: 13.5, height: 1.6),
          ),
        );
    return Panel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(d == null ? '' : '${dayName(d)} ${d.day}/${d.month}',
                style: TextStyle(color: context.ink, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          Tag(_status(st), fg: fg, bg: bg),
        ]),
        if (l['holiday'] == true) line('ملاحظة', 'جلسة بيوم إجازة'),
        if (nm is Map) line('حفظ', '${nm['label'] ?? ''}  (${fmtPages(_num(l['newPages']))} ص)'),
        if (revs.isNotEmpty)
          line('مراجعة', '${revs.map((r) => r['label'] ?? '').join('، ')}  (${fmtPages(_num(l['reviewPages']))} ص)'),
        if (notes.isNotEmpty) line('ملاحظة', notes),
      ]),
    );
  }
}
