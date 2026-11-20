import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../daily.dart';
import '../logic.dart';
import '../repo.dart';
import 'exam.dart';
import 'widgets.dart';

/// بيانات الاختبار: الحلقة، الطالب، النوع، جزء البداية، إعادة
class NewExamScreen extends StatefulWidget {
  final Halaqa? initialHalaqa;
  final Student? initialStudent;
  const NewExamScreen({super.key, this.initialHalaqa, this.initialStudent});

  @override
  State<NewExamScreen> createState() => _NewExamScreenState();
}

class _NewExamScreenState extends State<NewExamScreen> {
  Halaqa? _halaqa;
  Student? _student;
  int? _type;
  int? _startJuz;
  bool _retest = false;
  StreamSubscription? _sub;
  List<Map<String, dynamic>>? _sExams; // كل اختبارات الطالب المختار
  StreamSubscription? _permSub;
  List<Map<String, dynamic>> _permits = []; // أذونات الإدارة لإعادة اختبار ناجح
  StreamSubscription? _logSub, _progSub;
  List<Map<String, dynamic>> _sLogs = [];
  Map<String, dynamic>? _sProg;
  StreamSubscription? _setSub;
  bool _enforce = false; // شرط التسميع مفعّل من الإدارة

  /// آخر اختبار سابق لنفس الطالب بنفس النوع والأجزاء
  Map<String, dynamic>? get _prev {
    if (_sExams == null || _type == null || _startJuz == null) return null;
    final m = _sExams!.where((e) => e['type'] == _type && e['startJuz'] == _startJuz).toList();
    if (m.isEmpty) return null;
    m.sort((a, b) {
      final ta = a['createdAt'], tb = b['createdAt'];
      if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
      return 0;
    });
    return m.first;
  }

  /// تاريخ آخر اختبار للطالب (أي نتيجة)
  String get _lastExamDate {
    var m = 0;
    for (final e in _sExams ?? const <Map<String, dynamic>>[]) {
      final t = _ms(e['createdAt']);
      if (t > m) m = t;
    }
    return m == 0 ? '' : dayKey(DateTime.fromMillisecondsSinceEpoch(m));
  }

  /// شرط السجل اليومي: يُطبَّق على الاختبار التالي في المسار فقط (لا على إعادة ناجح بإذن)
  ExamReady? get _logReady {
    final s = _suggested;
    if (s == null || _student == null || _sExams == null) return null;
    if (_type != s.type || _startJuz != s.start) return null;
    final passed = {
      for (final e in _sExams!)
        if (e['passed'] == true) '${e['type']}|${e['startJuz']}'
    };
    return examReadiness(_student!.pathDir, _student!.pathStart, passed, _sLogs, _sProg, _lastExamDate,
        fromKey: _student!.pathFrom);
  }

  /// يمرّ الشرط إذا تحقق أو بتصريح اختبار من الإدارة
  bool get _logOk {
    final r = _logReady;
    return r == null || r.ok || _permitted || !_enforce;
  }

  bool get _forcedRetest => _prev != null && _prev!['passed'] != true;

  static int _ms(dynamic t) => t is Timestamp ? t.millisecondsSinceEpoch : 0;
  Iterable<Map<String, dynamic>> get _sameExams =>
      (_sExams ?? []).where((e) => e['type'] == _type && e['startJuz'] == _startJuz);

  /// الطالب نجح سابقاً بهذا الاختبار (نفس النوع والأجزاء)
  bool get _passedBefore => _sameExams.any((e) => e['passed'] == true);

  /// إذن من الإدارة لم يُستخدم بعد (أحدث من آخر محاولة)
  bool get _permitted {
    final last = _sameExams.fold<int>(0, (m, e) => _ms(e['createdAt']) > m ? _ms(e['createdAt']) : m);
    return _permits.any((p) =>
        p['type'] == _type && p['startJuz'] == _startJuz && ((p['grantedAtMs'] ?? 0) as num) > last);
  }

  bool get _blocked => _passedBefore && !_permitted;
  bool get _isRetest => _forcedRetest || (_passedBefore && _permitted) || _retest;

  bool get _pathKnown => _student != null && _sExams != null;
  PathStep? get _suggested {
    if (!_pathKnown) return null;
    final passed = {
      for (final e in _sExams!)
        if (e['passed'] == true) '${e['type']}|${e['startJuz']}'
    };
    return nextPathStep(_student!.pathDir, _student!.pathStart, passed, _student!.pathFrom);
  }

  /// اختبارات ناجحة سابقاً معها إذن إعادة من الإدارة لم يُستخدم بعد
  List<PathStep> get _permittedSteps {
    if (_sExams == null) return [];
    final out = <PathStep>[];
    for (final p in _permits) {
      final t = p['type'], st = p['startJuz'];
      if (t is! num || st is! num) continue;
      final ti = t.toInt(), si = st.toInt();
      final same = _sExams!.where((e) => e['type'] == ti && e['startJuz'] == si).toList();
      if (!same.any((e) => e['passed'] == true)) continue;
      final last = same.fold<int>(0, (m, e) => max(m, _ms(e['createdAt'])));
      if (((p['grantedAtMs'] ?? 0) as num) > last && !out.any((x) => x.type == ti && x.start == si)) {
        out.add(PathStep(ti, si));
      }
    }
    return out;
  }

  /// الاختبارات المسموحة فقط: التالي في المسار + إعادة بإذن الإدارة
  List<PathStep> get _options => [if (_suggested != null) _suggested!, ..._permittedSteps];
  bool get _selectedAllowed => _options.any((o) => o.type == _type && o.start == _startJuz);

  void _applySuggestion() {
    if (_selectedAllowed) return;
    final opts = _options;
    setState(() {
      _type = opts.isEmpty ? null : opts.first.type;
      _startJuz = opts.isEmpty ? null : opts.first.start;
    });
  }

  void _watchStudent() {
    _sub?.cancel();
    _sub = null;
    _sExams = null;
    _type = null;
    _startJuz = null;
    _retest = false;
    _permSub?.cancel();
    _permSub = null;
    _permits = [];
    _logSub?.cancel();
    _progSub?.cancel();
    _sLogs = [];
    _sProg = null;
    if (_student == null) return;
    _logSub = Repo.I.studentLogs(_student!.id).listen((l) {
      if (mounted) setState(() => _sLogs = l);
    }, onError: (_) {});
    _progSub = Repo.I.studentProgress(_student!.id).listen((p) {
      if (mounted) setState(() => _sProg = p);
    }, onError: (_) {});
    _permSub = Repo.I.permitsFor(_student!.id).listen((list) {
      if (!mounted) return;
      setState(() => _permits = list);
      _applySuggestion();
    }, onError: (_) {});
    _sub = Repo.I.studentExams(_student!.id).listen((list) {
      if (!mounted) return;
      setState(() => _sExams = list);
      _applySuggestion();
    }, onError: (_) {});
  }

  @override
  void initState() {
    super.initState();
    _setSub = Repo.I.settings().listen((v) {
      if (mounted) setState(() => _enforce = v['examRequiresLog'] == true);
    }, onError: (_) {});
    if (widget.initialHalaqa != null && widget.initialStudent != null) {
      _halaqa = widget.initialHalaqa;
      _student = widget.initialStudent;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _watchStudent();
      });
    }
  }

  @override
  void dispose() {
    _setSub?.cancel();
    _sub?.cancel();
    _permSub?.cancel();
    _logSub?.cancel();
    _progSub?.cancel();
    super.dispose();
  }

  int? get _endJuz => (_type == null || _startJuz == null) ? null : _startJuz! + _type! - 1;
  bool get _ready =>
      _halaqa != null && _student != null && _type != null && _startJuz != null && _selectedAllowed && !_blocked && _logOk;

  Future<void> _pickStudent() async {
    final res = await showModalBottomSheet<Student>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StudentPicker(halaqa: _halaqa!),
    );
    if (res != null) {
      setState(() => _student = res);
      _watchStudent();
    }
  }

  Future<void> _quickSearch() async {
    final res = await showModalBottomSheet<(Student, Halaqa)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const GlobalStudentPicker(),
    );
    if (res == null) return;
    setState(() {
      _student = res.$1;
      _halaqa = res.$2;
    });
    _watchStudent();
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
      isRetest: _isRetest,
      createdAt: DateTime.now(),
    );
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExamScreen(setup: setup)));
  }

  Widget _prevBox() {
    final p = _prev!;
    final failed = p['passed'] != true;
    final result = p['closed'] == true ? 'راسب – أُغلق الاختبار' : (failed ? 'راسب' : 'ناجح');
    final total = p['closed'] == true ? '' : ' (${fmt(p['total'])})';
    final details = 'آخر نتيجة: $result$total — ${p['createdAtText'] ?? ''} — المختبر: ${p['examinerName'] ?? ''}';
    final String head;
    final Color bg, fg;
    final IconData icon;
    if (_passedBefore && !_permitted) {
      head = 'الطالب ناجح سابقاً بهذا الاختبار، ولا يمكن إعادته إلا بإذن من الإدارة.\n';
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
      icon = Icons.warning_amber;
    } else if (_passedBefore && _permitted) {
      head = 'إعادة بإذن الإدارة لاختبار ناجح سابقاً.\n';
      bg = const Color(0xFFFFF4DE);
      fg = const Color(0xFF9A6700);
      icon = Icons.replay;
    } else {
      head = 'هذا اختبار إعادة. ';
      bg = Colors.red.shade50;
      fg = Colors.red.shade700;
      icon = Icons.replay;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(child: Text(head + details, style: TextStyle(height: 1.5, color: fg))),
        ],
      ),
    );
  }

  Widget _pathBox() {
    if (!_pathKnown) {
      return const Padding(
        padding: EdgeInsets.only(top: 14),
        child: Text('جارٍ تحديد الاختبار التالي للطالب...', style: TextStyle(color: Colors.grey)),
      );
    }
    final Color bg, fg;
    final String text;
    final s = _suggested;
    if (s == null) {
      bg = const Color(0xFFE8F3EC);
      fg = brandGreen;
      text = 'الطالب حافظ للقرآن الكريم — أتمّ المسار.\nأي اختبار الآن يكون مراجعة بإذن من الإدارة.';
    } else {
      final failedBefore = _sExams!.any((e) => e['type'] == s.type && e['startJuz'] == s.start && e['passed'] != true);
      bg = failedBefore ? Colors.red.shade50 : const Color(0xFFE8F3EC);
      fg = failedBefore ? Colors.red.shade800 : brandGreen;
      text = (failedBefore ? 'إعادة: ' : 'الاختبار التالي حسب المسار: ') + s.label;
    }
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 15, height: 1.5)),
          if (s != null && _logReady != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'السجل اليومي: ${_logReady!.message(s)}'
                    '${!_logReady!.ok && _permitted ? '\nمسموح بتصريح من الإدارة' : ''}'
                    '${!_logReady!.ok && !_permitted && !_enforce ? '\n(تنبيه فقط — الشرط غير مفعّل حالياً)' : ''}',
                style: TextStyle(
                    color: _logReady!.ok || _permitted
                        ? const Color(0xFF1F4E8C)
                        : _enforce
                            ? Colors.red.shade800
                            : const Color(0xFF9A6700),
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: brandGreen)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const BrandTitle('اختبار جديد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _quickSearch,
            icon: const Icon(Icons.search),
            label: const Text('بحث سريع عن الطالب (من كل الحلقات)', style: TextStyle(fontSize: 16)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: Colors.white,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('أو اختر الحلقة ثم الطالب:', style: TextStyle(color: Colors.black54)),
          ),
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
                onChanged: (id) {
                  setState(() {
                    _halaqa = list.firstWhere((h) => h.id == id);
                    _student = null;
                  });
                  _watchStudent();
                },
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
          if (_student != null) _pathBox(),
          if (_pathKnown) ...[
            _label('الاختبار'),
            if (_options.isEmpty)
              Text(
                'لا يوجد اختبار متاح لهذا الطالب الآن: أتمّ المسار، واختبار المراجعة يحتاج إذناً من الإدارة.',
                style: TextStyle(color: Colors.red.shade700, height: 1.6),
              )
            else
              for (final o in _options)
                RadioListTile<String>(
                  value: o.key,
                  groupValue: (_type == null || _startJuz == null) ? null : '$_type|$_startJuz',
                  onChanged: (_) => setState(() {
                    _type = o.type;
                    _startJuz = o.start;
                  }),
                  title: Text(o.label),
                  subtitle: (_suggested != null && o.key == _suggested!.key)
                      ? const Text('حسب ترتيب المسار')
                      : const Text('إعادة اختبار ناجح بإذن الإدارة'),
                  contentPadding: EdgeInsets.zero,
                ),
            const SizedBox(height: 6),
            // نوع الاختبار للعرض فقط (يُحدد تلقائياً حسب المسار)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in examTypes.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _type == e.key,
                    onSelected: null,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('الترتيب ثابت حسب مسار الطالب، ولا يمكن اختيار جزء آخر.',
                style: TextStyle(color: Colors.black54, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          if (_prev != null) _prevBox(),
          CheckboxListTile(
            value: _isRetest,
            onChanged: _forcedRetest ? null : (v) => setState(() => _retest = v ?? false),
            subtitle: _forcedRetest ? const Text('تلقائي: الطالب راسب سابقاً بنفس الاختبار') : null,
            title: const Text('اختبار إعادة'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          BigButton(icon: Icons.play_arrow, text: 'بدء الاختبار', onPressed: _ready ? _start : null),
          if (!_ready)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  _blocked
                      ? 'لا يمكن بدء الاختبار: الطالب ناجح فيه سابقاً، ويحتاج إذن الإدارة.'
                      : !_logOk
                          ? 'لا يمكن بدء الاختبار قبل تسميع ${(_suggested?.type ?? 1) == 1 ? 'الجزء كاملاً في جلسة واحدة' : 'كل الأجزاء المطلوبة كاملة'} في السجل اليومي، أو بتصريح من الإدارة.'
                          : (_student == null ? 'اختر الطالب لبدء الاختبار' : 'لا يوجد اختبار متاح لبدئه'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _blocked || !_logOk ? Colors.red.shade700 : Colors.grey)),
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
    var dir = 'desc';
    var start = 30;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('طالب جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('سيُضاف إلى حلقة ${widget.halaqa.name}، وتراجعه الإدارة لاحقاً.'),
                const SizedBox(height: 12),
                TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'اسم الطالب رباعياً')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: dir,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الاتجاه'),
                  items: [for (final e in pathDirs.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                  onChanged: (v) => setD(() {
                    dir = v ?? 'desc';
                    start = dir == 'asc' ? 1 : 30;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: start,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'جزء البداية'),
                  items: [
                    for (var j = 1; j <= 30; j++) DropdownMenuItem(value: j, child: Text('الجزء $j: ${juzNames[j]}')),
                  ],
                  onChanged: (v) => setD(() => start = v ?? start),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة')),
          ],
        ),
      ),
    );
    final name = ctrl.text.trim();
    if (ok != true || name.isEmpty || !mounted) return;
    final s = Repo.I.addPendingStudent(name, widget.halaqa.id, dir, start);
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

/// بحث عن طالب في كل الحلقات
class GlobalStudentPicker extends StatefulWidget {
  const GlobalStudentPicker({super.key});

  @override
  State<GlobalStudentPicker> createState() => _GlobalStudentPickerState();
}

class _GlobalStudentPickerState extends State<GlobalStudentPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(labelText: 'اكتب اسم الطالب', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _q = v.trim()),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Halaqa>>(
                stream: Repo.I.halaqat(),
                builder: (context, hs) {
                  final names = {for (final h in hs.data ?? <Halaqa>[]) h.id: h.name};
                  return StreamBuilder<List<Student>>(
                    stream: Repo.I.allStudents(),
                    builder: (context, snap) {
                      if (_q.isEmpty) {
                        return const Center(
                            child: Text('اكتب جزءاً من اسم الطالب', style: TextStyle(color: Colors.grey)));
                      }
                      final list = (snap.data ?? []).where((s) => s.name.contains(_q)).toList();
                      if (list.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'لا يوجد طالب بهذا الاسم.\nلإضافة طالب جديد: اختر الحلقة ثم "إضافة طالب جديد".',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, height: 1.6),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final s = list[i];
                          final hName = names[s.halaqaId] ?? '';
                          return ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(s.name),
                            subtitle: Text(hName + (s.pending ? ' — جديد بانتظار الاعتماد' : '')),
                            onTap: () => Navigator.pop(context, (s, Halaqa(s.halaqaId, hName))),
                          );
                        },
                      );
                    },
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
