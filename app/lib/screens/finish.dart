import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../logic.dart';
import '../repo.dart';
import 'widgets.dart';

/// إدخال التجويد والأداء والملاحظات ثم الحفظ
class FinishScreen extends StatefulWidget {
  final ExamSetup setup;
  final List<QuestionMark> questions;
  final int? closedAt;
  const FinishScreen({super.key, required this.setup, required this.questions, this.closedAt});

  @override
  State<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends State<FinishScreen> {
  final _taj = TextEditingController();
  final _perf = TextEditingController();
  final _notes = TextEditingController();
  bool _saved = false;

  bool get _closed => widget.closedAt != null;
  double get _qSum => widget.questions.fold(0.0, (a, q) => a + q.score);
  double? get _tajV => parseNum(_taj.text);
  double? get _perfV => parseNum(_perf.text);
  bool get _tajOk => _tajV != null && _tajV! >= 0 && _tajV! <= tajweedMax;
  bool get _perfOk => _perfV != null && _perfV! >= 0 && _perfV! <= perfMax;
  double? get _total => (_tajOk && _perfOk) ? _qSum + _tajV! + _perfV! : null;

  String? get _closeReason => _closed
      ? 'السؤال ${widget.closedAt}: خصم ${fmt(widget.questions[widget.closedAt! - 1].deduction)} علامات'
      : null;

  void _save() {
    if (_saved) return;
    if (!_closed && (!_tajOk || !_perfOk)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل علامة التجويد (0–20) والأداء (0–5) بشكل صحيح')),
      );
      return;
    }
    _saved = true;
    final s = widget.setup;
    final total = _closed ? null : _total;
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
      'closeReason': _closeReason,
      'tajweed': _closed ? null : _tajV,
      'performance': _closed ? null : _perfV,
      'total': total,
      'passed': !_closed && total != null && total >= passMark,
      'notes': _notes.text.trim(),
      'createdAt': Timestamp.fromDate(s.createdAt),
      'createdAtText': dateText(s.createdAt),
      'syncedAt': FieldValue.serverTimestamp(),
    };
    Repo.I.saveExam(const Uuid().v4(), data);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((r) => r.isFirst);
    messenger.showSnackBar(const SnackBar(
      content: Text('تم حفظ الاختبار — يُرفع تلقائياً عند توفر الإنترنت'),
      duration: Duration(seconds: 3),
    ));
  }

  Widget _row(String a, String b, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(a, style: const TextStyle(color: Colors.black54))),
            Text(b, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color, fontSize: 16)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.setup;
    final total = _total;
    final passed = total != null && total >= passMark;
    return Scaffold(
      appBar: AppBar(title: const Text('نتيجة الاختبار')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _row('الطالب', s.studentName + (s.isRetest ? ' (إعادة)' : ''), bold: true),
                  _row('الحلقة', s.halaqaName),
                  _row('النوع', examTypes[s.type] ?? ''),
                  _row('الأجزاء', juzLabel(s.startJuz, s.endJuz)),
                  _row('التاريخ', dateText(s.createdAt)),
                  const Divider(),
                  for (var i = 0; i < qCount; i++)
                    _row('السؤال ${i + 1}',
                        i < widget.questions.length ? '${fmt(widget.questions[i].score)} / ${fmt(qMax)}' : '—'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_closed)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Text('راسب – أُغلق الاختبار',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                  const SizedBox(height: 6),
                  Text(_closeReason!, style: const TextStyle(fontSize: 15)),
                ],
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taj,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'أحكام التجويد (من 20)',
                      errorText: _taj.text.isNotEmpty && !_tajOk ? 'من 0 إلى 20' : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _perf,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'الأداء (من 5)',
                      errorText: _perf.text.isNotEmpty && !_perfOk ? 'من 0 إلى 5' : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: total == null ? Colors.white : (passed ? const Color(0xFFE8F3EC) : Colors.red.shade50),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(total == null ? 'المجموع: —' : 'المجموع: ${fmt(total)} / 100',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  if (total != null)
                    Text(passed ? 'ناجح' : 'راسب',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: passed ? brandGreen : Colors.red.shade800)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'ملاحظات المختبر'),
          ),
          const SizedBox(height: 20),
          BigButton(icon: Icons.save, text: 'حفظ الاختبار', onPressed: _save),
        ],
      ),
    );
  }
}
