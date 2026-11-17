import 'package:flutter/material.dart';

import '../logic.dart';
import '../repo.dart';
import 'exam.dart';
import 'widgets.dart';

/// بيانات الاختبار: الحلقة، الطالب، النوع، جزء البداية، إعادة
class NewExamScreen extends StatefulWidget {
  const NewExamScreen({super.key});

  @override
  State<NewExamScreen> createState() => _NewExamScreenState();
}

class _NewExamScreenState extends State<NewExamScreen> {
  Halaqa? _halaqa;
  Student? _student;
  int? _type;
  int? _startJuz;
  bool _retest = false;

  int? get _endJuz => (_type == null || _startJuz == null) ? null : _startJuz! + _type! - 1;
  bool get _ready => _halaqa != null && _student != null && _type != null && _startJuz != null;

  void _setType(int t) {
    setState(() {
      _type = t;
      if (t == 30) {
        _startJuz = 1;
      } else if (_startJuz != null && _startJuz! + t - 1 > 30) {
        _startJuz = null;
      }
    });
  }

  Future<void> _pickStudent() async {
    final res = await showModalBottomSheet<Student>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StudentPicker(halaqa: _halaqa!),
    );
    if (res != null) setState(() => _student = res);
  }

  void _start() {
    final setup = ExamSetup(
      halaqaId: _halaqa!.id,
      halaqaName: _halaqa!.name,
      studentId: _student!.id,
      studentName: _student!.name,
      type: _type!,
      startJuz: _startJuz!,
      endJuz: _endJuz!,
      isRetest: _retest,
      createdAt: DateTime.now(),
    );
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExamScreen(setup: setup)));
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: brandGreen)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اختبار جديد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _label('الحلقة'),
          StreamBuilder<List<Halaqa>>(
            stream: Repo.I.halaqat(),
            builder: (context, snap) {
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return Text(
                  snap.connectionState == ConnectionState.waiting
                      ? 'جارٍ التحميل...'
                      : 'لا توجد حلقات — يجب أن تضيفها الإدارة ويتصل الجهاز بالإنترنت مرة.',
                  style: const TextStyle(color: Colors.grey),
                );
              }
              final selected = list.where((h) => h.id == _halaqa?.id).isEmpty ? null : _halaqa!.id;
              return DropdownButtonFormField<String>(
                value: selected,
                isExpanded: true,
                hint: const Text('اختر الحلقة'),
                items: [for (final h in list) DropdownMenuItem(value: h.id, child: Text(h.name))],
                onChanged: (id) => setState(() {
                  _halaqa = list.firstWhere((h) => h.id == id);
                  _student = null;
                }),
              );
            },
          ),
          _label('اسم الطالب'),
          OutlinedButton.icon(
            onPressed: _halaqa == null ? null : _pickStudent,
            icon: const Icon(Icons.person_search),
            label: Text(
              _student == null ? (_halaqa == null ? 'اختر الحلقة أولاً' : 'اختر الطالب') : _student!.name,
              style: const TextStyle(fontSize: 16),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              alignment: AlignmentDirectional.centerStart,
              backgroundColor: Colors.white,
            ),
          ),
          _label('نوع الاختبار'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in examTypes.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: _type == e.key,
                  onSelected: (_) => _setType(e.key),
                ),
            ],
          ),
          if (_type != null) ...[
            _label(_type == 1 ? 'الجزء' : 'جزء البداية'),
            if (_type == 30)
              const Text('القرآن كاملاً: من الجزء 1 إلى الجزء 30', style: TextStyle(fontSize: 16))
            else
              DropdownButtonFormField<int>(
                value: _startJuz,
                isExpanded: true,
                hint: const Text('اختر الجزء'),
                items: [
                  for (var i = 1; i <= 31 - _type!; i++)
                    DropdownMenuItem(value: i, child: Text('الجزء $i — ${juzNames[i]}')),
                ],
                onChanged: (v) => setState(() => _startJuz = v),
              ),
            if (_startJuz != null && _type! > 1 && _type != 30)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(juzLabel(_startJuz!, _endJuz!), style: const TextStyle(color: Colors.black54)),
              ),
          ],
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _retest,
            onChanged: (v) => setState(() => _retest = v ?? false),
            title: const Text('اختبار إعادة'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          BigButton(icon: Icons.play_arrow, text: 'بدء الاختبار', onPressed: _ready ? _start : null),
          if (!_ready)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('أكمل كل البيانات لبدء الاختبار',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ),
        ],
      ),
    );
  }
}

/// قائمة طلاب الحلقة مع بحث وإضافة طالب جديد
class StudentPicker extends StatefulWidget {
  final Halaqa halaqa;
  const StudentPicker({super.key, required this.halaqa});

  @override
  State<StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<StudentPicker> {
  String _q = '';

  Future<void> _addNew() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طالب جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('سيُضاف إلى حلقة ${widget.halaqa.name}، وتراجعه الإدارة لاحقاً.'),
            const SizedBox(height: 12),
            TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'اسم الطالب رباعياً')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('إضافة')),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final s = Repo.I.addPendingStudent(name, widget.halaqa.id);
    Navigator.pop(context, s);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(labelText: 'بحث عن طالب', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _q = v.trim()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_add, color: brandGreen),
              title: const Text('إضافة طالب جديد (غير موجود بالقائمة)',
                  style: TextStyle(color: brandGreen, fontWeight: FontWeight.bold)),
              onTap: _addNew,
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<Student>>(
                stream: Repo.I.students(widget.halaqa.id),
                builder: (context, snap) {
                  final list = (snap.data ?? []).where((s) => _q.isEmpty || s.name.contains(_q)).toList();
                  if (list.isEmpty) {
                    return const Center(child: Text('لا يوجد طلاب', style: TextStyle(color: Colors.grey)));
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(list[i].name),
                      subtitle: list[i].pending ? const Text('جديد — بانتظار اعتماد الإدارة') : null,
                      onTap: () => Navigator.pop(context, list[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
