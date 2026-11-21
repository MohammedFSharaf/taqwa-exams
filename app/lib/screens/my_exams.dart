import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../logic.dart';
import '../repo.dart';
import 'ui.dart';
import 'widgets.dart';

/// الاختبارات: اختباراتي / كل الاختبارات، مجمّعة حسب اليوم
class MyExamsScreen extends StatefulWidget {
  const MyExamsScreen({super.key});

  static String resultText(Map<String, dynamic> e) =>
      e['closed'] == true ? 'أُغلق' : (e['passed'] == true ? 'ناجح' : 'راسب');

  static void details(BuildContext context, Map<String, dynamic> e) {
    final qs = (e['questions'] as List?) ?? [];
    Widget row(String a, String b, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Text(a, style: TextStyle(color: context.sub))),
            Expanded(
              child: Text(b,
                  style: TextStyle(color: context.ink, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
            ),
          ]),
        );
    showAppSheet<void>(
      context,
      title: '${e['studentName'] ?? ''}${e['isRetest'] == true ? ' (إعادة)' : ''}',
      subtitle: '${examTypes[e['type']] ?? ''} · ${juzLabel(e['startJuz'] ?? 1, e['endJuz'] ?? 1, type: (e['type'] as num?)?.toInt() ?? 0, dir: (e['pathDir'] ?? 'desc').toString())}',
      builder: (ctx, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        row('التاريخ', '${e['createdAtText'] ?? ''}'),
        row('الحلقة', '${e['halaqaName'] ?? ''}'),
        row('المختبر', '${e['examinerName'] ?? ''}'),
        Divider(color: ctx.line),
        for (var i = 0; i < qs.length; i++)
          row('السؤال ${i + 1}',
              qs[i] == null ? '—' : '${fmt(qs[i]['score'])}  (أخطاء ${qs[i]['errors']}، تنبيهات ${qs[i]['alerts']})'),
        if (e['closed'] != true) ...[
          row('أحكام التجويد', fmt(e['tajweed'])),
          row('الأداء', fmt(e['performance'])),
          row('المجموع', fmt(e['total']), bold: true),
        ],
        row('النتيجة', resultText(e), bold: true),
        if (e['closeReason'] != null) row('سبب الإغلاق', '${e['closeReason']}'),
        if ((e['notes'] ?? '').toString().isNotEmpty) row('ملاحظات', '${e['notes']}'),
      ]),
    );
  }

  @override
  State<MyExamsScreen> createState() => _MyExamsScreenState();
}

class _MyExamsScreenState extends State<MyExamsScreen> {
  bool _mine = true;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _myStream = Repo.I.myExams();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _allStream = Repo.I.allExams();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const BrandTitle('الاختبارات')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: TwoWaySwitch(
            first: 'اختباراتي',
            second: 'كل الاختبارات',
            firstSelected: _mine,
            onChanged: (f) => setState(() => _mine = f),
          ),
        ),
        Expanded(
          child: IndexedStack(index: _mine ? 0 : 1, children: [
            ExamList(stream: _myStream, searchable: false),
            ExamList(stream: _allStream, searchable: true),
          ]),
        ),
      ]),
    );
  }
}

/// قائمة اختبارات مع بحث اختياري باسم الطالب أو المختبر
class ExamList extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final bool searchable;
  const ExamList({super.key, required this.stream, required this.searchable});

  @override
  State<ExamList> createState() => _ExamListState();
}

class _ExamListState extends State<ExamList> {
  String _q = '';
  int _limit = 60;

  static String _dayHeader(DateTime d) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    final date = '${dayName(d)} ${d.day}/${d.month}';
    if (diff == 0) return 'اليوم — $date';
    if (diff == 1) return 'أمس — $date';
    return '$date/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.searchable)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: TextField(
              decoration: const InputDecoration(hintText: 'بحث باسم الطالب أو المختبر', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(child: Text('تعذّر عرض الاختبارات'));
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs.where((d) {
                if (_q.isEmpty) return true;
                final e = d.data();
                return (e['studentName'] ?? '').toString().contains(_q) ||
                    (e['examinerName'] ?? '').toString().contains(_q);
              }).toList();
              docs.sort((a, b) {
                final ta = a.data()['createdAt'], tb = b.data()['createdAt'];
                if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
                return 0;
              });
              if (docs.isEmpty) {
                return SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.assignment_outlined,
                    title: _q.isEmpty ? 'لا توجد اختبارات بعد' : 'لا توجد نتائج',
                    text: _q.isEmpty ? 'الاختبارات التي تسجّلها تظهر هنا مجمّعة حسب اليوم.' : null,
                  ),
                );
              }
              final items = <Widget>[];
              String? lastDay;
              for (final d in docs.take(_limit)) {
                final e = d.data();
                final t = e['createdAt'];
                final dt = t is Timestamp ? t.toDate() : null;
                final h = dt == null ? '' : _dayHeader(dt);
                if (h != lastDay) {
                  lastDay = h;
                  items.add(SectionLabel(h, color: context.accent));
                }
                items.add(_tile(e, dt, d.metadata.hasPendingWrites));
              }
              if (docs.length > _limit) {
                items.add(TextButton(
                  onPressed: () => setState(() => _limit += 60),
                  child: Text('عرض المزيد (${docs.length - _limit})'),
                ));
              }
              return ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 24), children: items);
            },
          ),
        ),
      ],
    );
  }

  Widget _tile(Map<String, dynamic> e, DateTime? dt, bool pending) {
    final closed = e['closed'] == true;
    final passed = e['passed'] == true;
    final (Color fg, Color bg) = closed
        ? (context.goldFg, context.goldBg)
        : passed
            ? (context.okFg, context.okBg)
            : (context.badFg, context.badBg);
    final sj = e['startJuz'] ?? 1, ej = e['endJuz'] ?? 1;
    final tp = (e['type'] as num?)?.toInt() ?? 1;
    final dir = (e['pathDir'] ?? 'desc').toString();
    final parts = tp == 1
        ? 'الجزء ${unitNum(dir, (sj as num).toInt())}'
        : tp == 30
            ? 'المصحف كاملاً'
            : '$tp أجزاء: $sj–$ej';
    final time = dt == null ? '' : '${two(dt.hour)}:${two(dt.minute)}';
    return Panel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () => MyExamsScreen.details(context, e),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${e['studentName'] ?? ''}${e['isRetest'] == true ? ' (إعادة)' : ''}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.ink)),
            Text(
              [
                parts,
                if (time.isNotEmpty) time,
                if (widget.searchable) '${e['examinerName'] ?? ''}',
              ].join(' · '),
              style: TextStyle(color: context.sub, fontSize: 12.5),
            ),
            if (pending)
              Row(children: [
                Icon(Icons.cloud_upload_outlined, size: 14, color: context.goldFg),
                const SizedBox(width: 4),
                Text('بانتظار الرفع', style: TextStyle(color: context.goldFg, fontSize: 11.5)),
              ]),
          ]),
        ),
        Text(closed ? '—' : fmt(e['total']),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: fg)),
        const SizedBox(width: 10),
        Tag(MyExamsScreen.resultText(e), fg: fg, bg: bg),
      ]),
    );
  }
}
