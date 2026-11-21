import 'dart:async';

import 'package:flutter/material.dart';

import '../logic.dart';
import 'finish.dart';
import 'ui.dart';
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
        height: 120,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: color.withOpacity(0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          ),
          onPressed: () {
            haptic(true);
            _add(kind);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(text, style: const TextStyle(fontFamily: 'Cairo', fontSize: 26, fontWeight: FontWeight.w800)),
              Text(sub, style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circle(int i) {
    final cur = i == _idx, done = i < _idx;
    final Color bg = cur ? context.chosen : (done ? context.okBg : context.surface);
    final Color fg = cur ? Colors.white : (done ? context.okFg : context.sub);
    return Expanded(
      child: GestureDetector(
        onTap: i <= _idx
            ? () {
                haptic();
                setState(() => _idx = i);
              }
            : null,
        child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: cur ? context.chosen : (done ? context.okFg.withOpacity(0.4) : context.line), width: 1.5),
            ),
            child: Text('${i + 1}', style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 17)),
          ),
          const SizedBox(height: 4),
          Text(i <= _idx ? fmt(_qs[i].score) : '—',
              style: TextStyle(color: cur ? context.ink : context.sub, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.setup;
    final last = _idx == qCount - 1;
    final danger = _q.deduction >= closeAt - 2;
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
              child: Center(
                child: Text(fmtDuration(DateTime.now().difference(s.createdAt).inSeconds),
                    style: TextStyle(
                        fontSize: 15, color: context.sub, fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            Text('${examTypes[s.type]} — ${juzLabel(s.startJuz, s.endJuz)}',
                textAlign: TextAlign.center, style: TextStyle(color: context.sub, fontSize: 13.5)),
            const SizedBox(height: 12),
            Row(children: [for (var i = 0; i < qCount; i++) _circle(i)]),
            const SizedBox(height: 16),
            Panel(
              color: danger ? context.badBg : null,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                children: [
                  Text('السؤال ${_idx + 1} من $qCount',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.sub)),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: fmt(_q.score),
                          style: TextStyle(
                              fontSize: 64, fontWeight: FontWeight.w800, color: danger ? context.badFg : context.ink)),
                      TextSpan(text: ' / ${fmt(qMax)}', style: TextStyle(fontSize: 20, color: context.sub)),
                    ]),
                  ),
                  Text('أخطاء ${_q.errors} · تنبيهات ${_q.alerts} · الخصم ${fmt(_q.deduction)}',
                      style: TextStyle(fontSize: 14.5, color: context.sub)),
                  if (danger)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('تنبيه: الاختبار يُغلق عند خصم ${fmt(closeAt)} علامات',
                          style: TextStyle(color: context.badFg, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _counterButton('خطأ', '−1', const Color(0xFFC0392B), 'e'),
                const SizedBox(width: 12),
                _counterButton('تنبيه', '−½', const Color(0xFFD39A12), 'a'),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _history[_idx].isEmpty
                  ? null
                  : () {
                      haptic();
                      _undo();
                    },
              icon: const Icon(Icons.undo_rounded),
              label: const Text('تراجع عن آخر ضغطة'),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: last
                ? GoldButton(text: 'إنهاء الأسئلة', icon: Icons.check_rounded, height: 58, onPressed: _next)
                : NavyButton(text: 'السؤال التالي ←', height: 58, onPressed: _next),
          ),
        ),
      ),
    );
  }
}
