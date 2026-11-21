import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../logic.dart';
import '../repo.dart';
import 'ui.dart';
import 'widgets.dart';

/// إدخال التجويد والأداء والملاحظات
class FinishScreen extends StatefulWidget {
  final ExamSetup setup;
  final List<QuestionMark> questions;
  final int? closedAt;
  const FinishScreen({super.key, required this.setup, required this.questions, this.closedAt});

  @override
  State<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends State<FinishScreen> {
  double? _taj, _perf;
  final _notes = TextEditingController();

  bool get _closed => widget.closedAt != null;
  double get _qSum => widget.questions.fold(0.0, (a, q) => a + q.score);
  double? get _total => (_taj != null && _perf != null) ? _qSum + _taj! + _perf! : null;

  String? get _closeReason => _closed
      ? 'السؤال ${widget.closedAt}: خصم ${fmt(widget.questions[widget.closedAt! - 1].deduction)} علامات'
      : null;

  Future<void> _typeValue(String title, double max, double? cur, ValueChanged<double> set) async {
    final c = TextEditingController(text: cur == null ? '' : fmt(cur));
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          decoration: InputDecoration(hintText: 'من 0 إلى ${fmt(max)}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final x = parseNum(c.text);
              if (x != null && x >= 0 && x <= max) Navigator.pop(ctx, x);
            },
            child: const Text('تم'),
          ),
        ],
      ),
    );
    if (v != null) set(v);
  }

  Widget _stepper(String title, double max, double? v, ValueChanged<double> set) {
    Widget btn(IconData ic, bool plus) {
      final enabled = v == null || (plus ? v < max : v > 0);
      return SizedBox(
        width: 74,
        height: 74,
        child: Material(
          color: plus ? brandBlue : context.field,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: plus ? BorderSide.none : BorderSide(color: context.line),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: !enabled
                ? null
                : () {
                    haptic();
                    if (v == null) {
                      set(plus ? max : max - 0.5);
                    } else {
                      set(((plus ? v + 0.5 : v - 0.5).clamp(0.0, max)).toDouble());
                    }
                  },
            child: Icon(ic, size: 30, color: plus ? Colors.white : (enabled ? context.ink : context.line)),
          ),
        ),
      );
    }

    return Panel(
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.ink))),
          Text('من ${fmt(max)}', style: TextStyle(color: context.sub)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          btn(Icons.add_rounded, true),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _typeValue(title, max, v, set),
              child: Text(v == null ? '—' : fmt(v),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: context.ink)),
            ),
          ),
          btn(Icons.remove_rounded, false),
        ]),
      ]),
    );
  }

  void _next() {
    if (!_closed && _total == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدّد علامة التجويد والأداء أولاً')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultScreen(
        setup: widget.setup,
        questions: widget.questions,
        closedAt: widget.closedAt,
        closeReason: _closeReason,
        tajweed: _closed ? null : _taj,
        performance: _closed ? null : _perf,
        notes: _notes.text.trim(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final passed = total != null && total >= passMark;
    return Scaffold(
      appBar: AppBar(title: const BrandTitle('إنهاء الاختبار')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
        children: [
          Panel(
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: Text('علامة الحفظ (الأسئلة)',
                      style: TextStyle(fontWeight: FontWeight.w800, color: context.ink, fontSize: 15.5)),
                ),
                Text('${fmt(_qSum)} / ${fmt(qMax * qCount)}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: context.okFg, fontSize: 20)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                for (var i = 0; i < qCount; i++)
                  Expanded(
                    child: Column(children: [
                      Text('س${i + 1}', style: TextStyle(color: context.sub, fontSize: 12)),
                      Text(i < widget.questions.length ? fmt(widget.questions[i].score) : '—',
                          style: TextStyle(color: context.ink, fontWeight: FontWeight.w700)),
                    ]),
                  ),
              ]),
            ]),
          ),
          if (_closed)
            Panel(
              color: context.badBg,
              child: Column(children: [
                Text('راسب – أُغلق الاختبار',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: context.badFg)),
                const SizedBox(height: 4),
                Text(_closeReason!, style: TextStyle(fontSize: 15, color: context.badFg)),
              ]),
            )
          else ...[
            _stepper('التجويد', tajweedMax, _taj, (x) => setState(() => _taj = x)),
            _stepper('الأداء', perfMax, _perf, (x) => setState(() => _perf = x)),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('اضغط + أو − (نصف علامة)، أو اضغط على الرقم لكتابته',
                  textAlign: TextAlign.center, style: TextStyle(color: context.sub, fontSize: 12.5)),
            ),
          ],
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: context.surface,
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, -2))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!_closed)
              Row(children: [
                Text('المجموع', style: TextStyle(color: context.ink, fontWeight: FontWeight.w800, fontSize: 16)),
                const Spacer(),
                Text(
                  total == null ? '— / 100' : '${fmt(total)} / 100 · ${passed ? 'ناجح' : 'راسب'}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: total == null ? context.sub : (passed ? context.okFg : context.badFg),
                  ),
                ),
              ]),
            const SizedBox(height: 8),
            GoldButton(text: 'إنهاء وعرض النتيجة', height: 58, onPressed: _next),
          ]),
        ),
      ),
    );
  }
}

/// نتيجة الاختبار: عرض ثم حفظ
class ResultScreen extends StatefulWidget {
  final ExamSetup setup;
  final List<QuestionMark> questions;
  final int? closedAt;
  final String? closeReason;
  final double? tajweed, performance;
  final String notes;
  const ResultScreen({
    super.key,
    required this.setup,
    required this.questions,
    required this.closedAt,
    required this.closeReason,
    required this.tajweed,
    required this.performance,
    required this.notes,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _saved = false;
  late final DateTime _finishedAt = DateTime.now();

  bool get _closed => widget.closedAt != null;
  double get _qSum => widget.questions.fold(0.0, (a, q) => a + q.score);
  double? get _total => _closed ? null : _qSum + (widget.tajweed ?? 0) + (widget.performance ?? 0);
  bool get _passed => !_closed && _total != null && _total! >= passMark;

  void _save() {
    if (_saved) return;
    final s = widget.setup;
    final total = _total;
    final durationSec = _finishedAt.difference(s.createdAt).inSeconds;
    final data = <String, dynamic>{
      'authorUid': Repo.I.uid,
      'deviceId': Repo.I.deviceId,
      'examinerName': Repo.I.examinerName ?? '',
      'studentId': s.studentId,
      'studentName': s.studentName,
      'halaqaId': s.halaqaId,
      'halaqaName': s.halaqaName,
      'type': s.type,
      'startJuz': s.startJuz,
      'endJuz': s.endJuz,
      'isRetest': s.isRetest,
      'questions': [
        for (var i = 0; i < qCount; i++) i < widget.questions.length ? widget.questions[i].toMap() : null,
      ],
      'closed': _closed,
      'closedAtQuestion': widget.closedAt,
      'closeReason': widget.closeReason,
      'tajweed': _closed ? null : widget.tajweed,
      'performance': _closed ? null : widget.performance,
      'total': total,
      'passed': _passed,
      'notes': widget.notes,
      'createdAt': Timestamp.fromDate(s.createdAt),
      'createdAtText': dateText(s.createdAt),
      'finishedAt': Timestamp.fromDate(_finishedAt),
      'durationSeconds': durationSec,
      'syncedAt': FieldValue.serverTimestamp(),
    };
    Repo.I.saveExam(const Uuid().v4(), data);
    setState(() => _saved = true);
    showSavedTick(context, title: 'تم حفظ النتيجة', sub: 'تُرفع تلقائياً عند توفر الإنترنت');
  }

  String get _parts {
    final s = widget.setup;
    return s.type == 1 ? 'الجزء ${s.startJuz}' : 'الأجزاء ${s.startJuz}–${s.endJuz}';
  }

  Future<void> _share() async {
    final s = widget.setup;
    final res = _closed ? 'لم يُكمل الاختبار' : '${fmt(_total)} من 100 — ${_passed ? 'ناجح' : 'لم ينجح هذه المرة'}';
    final msg = 'السلام عليكم ورحمة الله\n'
        'نتيجة اختبار الطالب ${s.studentName} في مركز التقوى لتعليم وتحفيظ القرآن الكريم:\n'
        '${examTypes[s.type] ?? ''} — ${juzLabel(s.startJuz, s.endJuz)}\n'
        'النتيجة: $res\n'
        '${_passed ? 'بارك الله فيه وزاده حفظاً وإتقاناً.' : 'يراجع $_parts ويعيد الاختبار بإذن الله.'}';
    try {
      await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}'), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _home() => Navigator.of(context).popUntil((r) => r.isFirst);

  Widget _row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Expanded(child: Text(a, style: TextStyle(color: context.sub, fontSize: 15))),
          Text(b, style: TextStyle(color: context.ink, fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.setup;
    final total = _total;
    final color = _passed ? okGreen : const Color(0xFFC0392B);
    return PopScope(
      canPop: !_saved,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _saved) _home();
      },
      child: Scaffold(
        appBar: AppBar(title: const BrandTitle('نتيجة الاختبار'), automaticallyImplyLeading: !_saved),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
          children: [
            Center(
              child: SizedBox(
                width: 170,
                height: 170,
                child: CustomPaint(
                  painter: _RingPainter(_closed ? 1 : (total ?? 0) / 100, color,
                      context.dark ? const Color(0xFF263644) : const Color(0xFFE6EDF2)),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_closed ? '✕' : fmt(total),
                          style: TextStyle(fontSize: 46, fontWeight: FontWeight.w800, color: context.ink, height: 1.1)),
                      Text(_closed ? 'أُغلق' : 'من 100', style: TextStyle(color: context.sub, fontSize: 13)),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _passed ? 'ناجح — بارك الله فيه' : (_closed ? 'أُغلق الاختبار' : 'لم ينجح هذه المرة'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _passed ? context.okFg : context.badFg),
            ),
            Text(
              '${s.studentName}${s.isRetest ? ' (إعادة)' : ''} · ${juzLabel(s.startJuz, s.endJuz)}',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.sub, fontSize: 14),
            ),
            if (!_passed)
              Text('النجاح من ${fmt(passMark)} — بالتوفيق في الإعادة',
                  textAlign: TextAlign.center, style: TextStyle(color: context.sub, fontSize: 14)),
            const SizedBox(height: 14),
            Panel(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Column(children: [
                _row('الحفظ', '${fmt(_qSum)} / ${fmt(qMax * qCount)}'),
                if (!_closed) ...[
                  Divider(height: 1, color: context.line),
                  _row('التجويد', '${fmt(widget.tajweed)} / ${fmt(tajweedMax)}'),
                  Divider(height: 1, color: context.line),
                  _row('الأداء', '${fmt(widget.performance)} / ${fmt(perfMax)}'),
                ] else ...[
                  Divider(height: 1, color: context.line),
                  _row('سبب الإغلاق', widget.closeReason ?? ''),
                ],
                Divider(height: 1, color: context.line),
                _row('مدة الاختبار', fmtDuration(_finishedAt.difference(s.createdAt).inSeconds)),
              ]),
            ),
            if (!_passed)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: context.goldBg, borderRadius: BorderRadius.circular(16)),
                child: Text(
                  'المطلوب للإعادة: يراجع $_parts ويسمّعه كاملاً في جلسة واحدة عند الشيخ',
                  style: TextStyle(color: context.goldFg, fontWeight: FontWeight.w700, height: 1.6),
                ),
              ),
            if (widget.notes.isNotEmpty)
              Panel(child: Text('ملاحظة: ${widget.notes}', style: TextStyle(color: context.txt))),
            const SizedBox(height: 6),
            if (!_saved) ...[
              NavyButton(text: 'حفظ النتيجة', height: 58, onPressed: _save),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('رجوع للتعديل', style: TextStyle(color: context.accent, fontWeight: FontWeight.w700)),
              ),
              Text('بعد الحفظ لا يمكن التعديل إلا من الإدارة.',
                  textAlign: TextAlign.center, style: TextStyle(color: context.sub, fontSize: 12.5)),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: context.okBg, borderRadius: BorderRadius.circular(14)),
                child: Text('✓ تم الحفظ — يُرفع تلقائياً عند توفر الإنترنت',
                    textAlign: TextAlign.center, style: TextStyle(color: context.okFg, fontWeight: FontWeight.w800)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                onPressed: _share,
                icon: const Icon(Icons.send_rounded),
                label: const Text('إرسال لولي الأمر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 10),
              NavyButton(text: 'رجوع للرئيسية', onPressed: _home),
            ],
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color, track;
  _RingPainter(this.value, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    const w = 16.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(w / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value.clamp(0.0, 1.0), false, p..color = color);
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) => o.value != value || o.color != color || o.track != track;
}
