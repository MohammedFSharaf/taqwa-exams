import 'dart:async';

import 'package:flutter/material.dart';

import '../logic.dart';
import 'finish.dart';
import 'widgets.dart';

/// شاشة الأسئلة: زر خطأ (−1) وزر تنبيه (−½) لكل سؤال
class ExamScreen extends StatefulWidget {
  final ExamSetup setup;
  const ExamScreen({super.key, required this.setup});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  final List<QuestionMark> _qs = List.generate(qCount, (_) => QuestionMark());
  final List<List<String>> _history = List.generate(qCount, (_) => <String>[]);
  int _idx = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  QuestionMark get _q => _qs[_idx];

  void _add(String kind) {
    setState(() {
      if (kind == 'e') {
        _q.errors++;
      } else {
        _q.alerts++;
      }
      _history[_idx].add(kind);
    });
    if (_q.deduction >= closeAt) _confirmClose();
  }

  void _undo() {
    if (_history[_idx].isEmpty) return;
    setState(() {
      final k = _history[_idx].removeLast();
      if (k == 'e') {
        _q.errors--;
      } else {
        _q.alerts--;
      }
    });
  }

  Future<void> _confirmClose() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('إغلاق الاختبار'),
        content: Text(
          'وصل الخصم في السؤال ${_idx + 1} إلى ${fmt(_q.deduction)} علامات.\n'
          'بهذا يُغلق الاختبار ويُسجَّل الطالب راسباً.',
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع عن آخر ضغطة')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الإغلاق'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _finish(closedAt: _idx + 1);
    } else {
      _undo();
    }
  }

  void _next() {
    if (_idx < qCount - 1) {
      setState(() => _idx++);
    } else {
      _finish();
    }
  }

  void _finish({int? closedAt}) {
    final n = closedAt ?? qCount;
    final answered = [
      for (var i = 0; i < n; i++) QuestionMark()
        ..errors = _qs[i].errors
        ..alerts = _qs[i].alerts,
    ];
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FinishScreen(setup: widget.setup, questions: answered, closedAt: closedAt),
    ));
  }

  Future<bool> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الخروج من الاختبار؟'),
        content: const Text('لن يُحفظ هذا الاختبار.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('متابعة الاختبار')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('خروج بدون حفظ')),
        ],
      ),
    );
    return ok == true;
  }

  Widget _counterButton(String text, String sub, Color color, String kind) {
    return Expanded(
      child: SizedBox(
        height: 110,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () => _add(kind),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text(sub, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.setup;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: BrandTitle(s.studentName),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 14),
              child: Row(
                children: [
                  const Text('الوقت ', style: TextStyle(fontSize: 14)),
                  Text(fmtDuration(DateTime.now().difference(s.createdAt).inSeconds),
                      style: const TextStyle(fontSize: 16, fontFeatures: [FontFeature.tabularFigures()])),
                ],
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${examTypes[s.type]} — ${juzLabel(s.startJuz, s.endJuz)}',
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            // مؤشر الأسئلة
            Row(
              children: [
                for (var i = 0; i < qCount; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: i <= _idx ? () => setState(() => _idx = i) : null,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: i == _idx ? brandGreen : (i < _idx ? const Color(0xFFDDEBE3) : Colors.white),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: brandGreen.withOpacity(0.4)),
                        ),
                        child: Column(
                          children: [
                            Text('س${i + 1}',
                                style: TextStyle(
                                    color: i == _idx ? Colors.white : brandGreen, fontWeight: FontWeight.bold)),
                            Text(i <= _idx ? fmt(_qs[i].score) : '—',
                                style: TextStyle(color: i == _idx ? Colors.white : Colors.black87)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('السؤال ${_idx + 1} من $qCount',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: brandGreen)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Text('${fmt(_q.score)} / ${fmt(qMax)}',
                      style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('أخطاء: ${_q.errors}    تنبيهات: ${_q.alerts}    الخصم: ${fmt(_q.deduction)}',
                      style: const TextStyle(fontSize: 15, color: Colors.black54)),
                  if (_q.deduction >= closeAt - 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('تنبيه: الاختبار يُغلق عند خصم ${fmt(closeAt)} علامات',
                          style: TextStyle(color: Colors.red.shade700)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _counterButton('خطأ', '−1', Colors.red.shade700, 'e'),
                const SizedBox(width: 12),
                _counterButton('تنبيه', '−½', const Color(0xFFC88A12), 'a'),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _history[_idx].isEmpty ? null : _undo,
              icon: const Icon(Icons.undo),
              label: const Text('تراجع عن آخر ضغطة'),
            ),
            const SizedBox(height: 24),
            BigButton(
              icon: _idx < qCount - 1 ? Icons.arrow_back : Icons.check,
              text: _idx < qCount - 1 ? 'السؤال التالي' : 'إنهاء الأسئلة',
              onPressed: _next,
            ),
          ],
        ),
      ),
    );
  }
}
