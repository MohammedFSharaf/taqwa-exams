import 'dart:async';

import 'package:flutter/material.dart';

import '../daily.dart';
import '../logic.dart';
import '../quran_data.dart';
import '../repo.dart';
import '../update_check.dart';
import 'gate.dart';
import 'widgets.dart';

// ===================== دخول الشيخ (نموذج داخل شاشة الدخول) =====================
class SheikhLoginForm extends StatefulWidget {
  const SheikhLoginForm({super.key});

  @override
  State<SheikhLoginForm> createState() => _SheikhLoginFormState();
}

class _SheikhLoginFormState extends State<SheikhLoginForm> {
  String? _id = Repo.I.sheikhId;
  final _pin = TextEditingController();
  String? _error;

  void _login(List<Map<String, dynamic>> list) {
    final sh = list.where((x) => x['id'] == _id).toList();
    if (sh.isEmpty) {
      setState(() => _error = 'اختر اسمك');
      return;
    }
    if ((sh.first['pin'] ?? '').toString() != _pin.text.trim()) {
      setState(() => _error = 'رمز الدخول غير صحيح');
      return;
    }
    Repo.I.setSheikhId(_id);
    Repo.I.setLastRole('sheikh');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => SheikhHomeScreen(sheikh: sh.first)),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Halaqa>>(
      stream: Repo.I.halaqat(),
      builder: (context, hs) {
        final hNames = {for (final h in hs.data ?? <Halaqa>[]) h.id: h.name};
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: Repo.I.sheikhs(),
          builder: (context, snap) {
            final list = [...(snap.data ?? <Map<String, dynamic>>[])]
              ..sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  snap.connectionState == ConnectionState.waiting
                      ? 'جارٍ التحميل...'
                      : 'لا توجد حسابات محفّظين — تضيفها الإدارة من لوحة الإدارة.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              );
            }
            final valid = list.any((x) => x['id'] == _id) ? _id : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: valid,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'اسم المحفّظ'),
                  items: [
                    for (final x in list)
                      DropdownMenuItem(
                        value: x['id'] as String,
                        child: Text('${x['name'] ?? ''} — ${hNames[x['halaqaId']] ?? ''}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _id = v),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _pin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'رمز الدخول', prefixIcon: Icon(Icons.lock_outline)),
                  onSubmitted: (_) => _login(list),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 18),
                BigButton(icon: Icons.login, text: 'دخول', onPressed: () => _login(list)),
              ],
            );
          },
        );
      },
    );
  }
}

// ===================== شاشة الحلقة لليوم =====================
class SheikhHomeScreen extends StatefulWidget {
  final Map<String, dynamic> sheikh;
  const SheikhHomeScreen({super.key, required this.sheikh});

  @override
  State<SheikhHomeScreen> createState() => _SheikhHomeScreenState();
}

class _SheikhHomeScreenState extends State<SheikhHomeScreen> {
  final List<StreamSubscription> _subs = [];
  List<Student> _students = [];
  List<Map<String, dynamic>> _logs = [], _progress = [], _exams = [], _holidays = [], _sheikhs = [];
  Map<String, dynamic> _settings = {};
  String _halaqaName = '';
  bool _loaded = false;
  bool _showDone = false;
  String _q = '';

  String get _halaqaId => (widget.sheikh['halaqaId'] ?? '').toString();
  String get _sheikhName => (widget.sheikh['name'] ?? '').toString();
  String get _today => dayKey(DateTime.now());

  List<int> get _sessionDays {
    final v = _settings['sessionDays'];
    if (v is List && v.isNotEmpty) return v.whereType<num>().map((e) => e.toInt()).toList();
    return const [6, 0, 2, 4];
  }

  double get _minNew => (_settings['minNewPages'] as num?)?.toDouble() ?? 1;
  double get _minReview => (_settings['minReviewPages'] as num?)?.toDouble() ?? 7;
  bool get _isSessionDay => _sessionDays.contains(jsDay(DateTime.now()));
  bool get _holidayAll => _holidays.any((h) => h['id'] == 'all_$_today');
  bool get _holidayHalaqa => _holidays.any((h) => h['id'] == '${_halaqaId}_$_today');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkForUpdate(context));
    void on<T>(Stream<T> s, void Function(T) f) => _subs.add(s.listen((v) {
          if (mounted) setState(() => f(v));
        }, onError: (_) {}));
    on(Repo.I.students(_halaqaId), (List<Student> v) {
      _students = v;
      _loaded = true;
    });
    on(Repo.I.halaqaLogs(_halaqaId), (List<Map<String, dynamic>> v) => _logs = v);
    on(Repo.I.halaqaProgress(_halaqaId), (List<Map<String, dynamic>> v) => _progress = v);
    on(Repo.I.halaqaExams(_halaqaId), (List<Map<String, dynamic>> v) => _exams = v);
    on(Repo.I.holidays(), (List<Map<String, dynamic>> v) => _holidays = v);
    on(Repo.I.settings(), (Map<String, dynamic> v) => _settings = v);
    on(Repo.I.sheikhs(), (List<Map<String, dynamic>> v) => _sheikhs = v);
    on(Repo.I.halaqat(), (List<Halaqa> v) {
      final h = v.where((x) => x.id == _halaqaId);
      _halaqaName = h.isEmpty ? '' : h.first.name;
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> _logsOf(String sid) => _logs.where((l) => l['studentId'] == sid).toList();
  Map<String, dynamic>? _todayLog(String sid) {
    final x = _logs.where((l) => l['id'] == '${sid}_$_today');
    return x.isEmpty ? null : x.first;
  }

  DailyStatus _statusOf(Student s) {
    final passed = {
      for (final e in _exams)
        if (e['studentId'] == s.id && e['passed'] == true) '${e['type']}|${e['startJuz']}'
    };
    final pr = _progress.where((p) => p['id'] == s.id);
    return dailyStatus(s.pathDir, s.pathStart, passed, _logsOf(s.id), pr.isEmpty ? null : pr.first, _minNew);
  }

  Map<String, dynamic> _base(Student s, DailyStatus st) => {
        'halaqaId': _halaqaId,
        'studentName': s.name,
        'sheikhId': widget.sheikh['id'],
        'sheikhName': _sheikhName,
        'extraDay': !_isSessionDay,
        'holiday': _holidayAll || _holidayHalaqa,
        'mode': st.mode,
        'dir': s.pathDir,
        'notes': '',
      };

  void _quickRecite(Student s, DailyStatus st) {
    final p = memRangePages(s.pathDir, st.fromG!, st.suggestToG!);
    Repo.I.saveLog(s.id, _today, prev: _todayLog(s.id), {
      ..._base(s, st),
      'status': 'recited',
      'newMem': {
        'fromG': st.fromG,
        'toG': st.suggestToG,
        'pages': p,
        'label': memRangeLabel(s.pathDir, st.fromG!, st.suggestToG!),
      },
      'reviews': <Map<String, dynamic>>[],
      'newPages': p,
      'reviewPages': 0,
    });
  }

  void _quickStatus(Student s, DailyStatus st, String status) {
    Repo.I.saveLog(s.id, _today, prev: _todayLog(s.id), {
      ..._base(s, st),
      'status': status,
      'newMem': null,
      'reviews': <Map<String, dynamic>>[],
      'newPages': 0,
      'reviewPages': 0,
    });
  }

  static String statusText(String? s) => switch (s) {
        'recited' => 'سمّع',
        'norecite' => 'لم يسمّع',
        'absent' => 'غائب',
        'excused' => 'غائب بعذر',
        _ => '',
      };

  String _summary(Map<String, dynamic> l) {
    if (l['status'] != 'recited') return statusText(l['status'] as String?);
    final parts = <String>[];
    final nm = l['newMem'];
    if (nm is Map) parts.add('سمّع: ${nm['label'] ?? ''} (${fmtPages(((nm['pages'] ?? 0) as num).toDouble())} ص)');
    final rp = ((l['reviewPages'] ?? 0) as num).toDouble();
    if (rp > 0) parts.add('راجع: ${fmtPages(rp)} ص');
    return parts.isEmpty ? 'سمّع' : parts.join(' · ');
  }

  String? _warning(Map<String, dynamic> l, DailyStatus st) {
    if (l['status'] != 'recited' || l['holiday'] == true) return null;
    final np = ((l['newPages'] ?? 0) as num).toDouble();
    final rp = ((l['reviewPages'] ?? 0) as num).toDouble();
    if (l['newMem'] is Map && np < _minNew - 1e-9) return 'أقل من الحد الأدنى للحفظ (${fmt(_minNew)} صفحة)';
    if (l['newMem'] == null && st.isReview && rp < _minReview - 1e-9) {
      return 'أقل من الحد الأدنى للمراجعة (${fmt(_minReview)} صفحات)';
    }
    return null;
  }

  Future<void> _toggleHoliday() async {
    final on = !_holidayHalaqa;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(on ? 'تعليم اليوم إجازة للحلقة؟' : 'إلغاء إجازة اليوم؟'),
        content: Text(on ? 'لن يُحسب غياب ولا تنبيهات على طلاب الحلقة اليوم.' : 'سيعود اليوم يوم تحفيظ عادي.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (ok == true) Repo.I.setHalaqaHoliday(_halaqaId, _today, on, _sheikhName);
  }

  Widget _header(DateTime now, int done, int todo, int absent, int pending, int total) {
    final names = _sheikhs
        .where((x) => x['halaqaId'] == _halaqaId)
        .map((x) => (x['name'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .join('، ');
    const white70 = TextStyle(color: Color(0xFFDCEBE3), fontSize: 13);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF174A36), brandGreen],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(_halaqaName.isEmpty ? 'الحلقة' : _halaqaName,
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
            ),
            Text('${dayName(now)} ', style: const TextStyle(color: brandGold, fontSize: 15, fontWeight: FontWeight.bold)),
            Text('${now.day}/${now.month}/${now.year}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ]),
          Row(children: [
            Expanded(
                child: Text('المشايخ: ${names.isEmpty ? _sheikhName : names}',
                    style: white70, overflow: TextOverflow.ellipsis)),
            if (!_holidayAll)
              InkWell(
                onTap: _toggleHoliday,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(_holidayHalaqa ? 'إلغاء الإجازة' : 'إجازة',
                      style: const TextStyle(color: brandGold, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
          ]),
          if (_holidayAll || _holidayHalaqa || !_isSessionDay)
            Text(
              [
                if (_holidayAll) 'اليوم إجازة للمركز',
                if (!_holidayAll && _holidayHalaqa) 'اليوم إجازة للحلقة',
                if (!_isSessionDay) 'جلسة إضافية (ليس يوم تحفيظ)',
              ].join(' — '),
              style: const TextStyle(color: brandGold, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 6),
          Text(
            (_holidayAll || _holidayHalaqa)
                ? 'يوم إجازة — التسجيل اختياري · سمّع $done${pending > 0 ? ' · بانتظار الرفع $pending' : ''}'
                : 'سُجّل $done · لم يُسجّل $todo · غياب $absent${pending > 0 ? ' · بانتظار الرفع $pending' : ''}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 6,
              color: brandGold,
              backgroundColor: Colors.white24,
            ),
          ),
        ],
      ),
    );
  }

  /// شو سمّع الطالب بالضبط وكم صفحة
  String _shortSummary(Map<String, dynamic> l) {
    if (l['status'] != 'recited') return '';
    final lines = <String>[if (l['holiday'] == true) 'جلسة بيوم إجازة'];
    final nm = l['newMem'];
    if (nm is Map) {
      lines.add('سمّع: ${nm['label'] ?? ''} (${fmtPages(((l['newPages'] ?? 0) as num).toDouble())} ص)');
    }
    final revs = ((l['reviews'] as List?) ?? []).whereType<Map>().toList();
    if (revs.isNotEmpty) {
      final labels = revs.map((r) => (r['label'] ?? '').toString()).join('، ');
      lines.add('راجع: $labels (${fmtPages(((l['reviewPages'] ?? 0) as num).toDouble())} ص)');
    }
    return lines.isEmpty ? 'سمّع' : lines.join('\n');
  }

  Future<void> _longPress(Student s, DailyStatus st, Map<String, dynamic>? l) async {
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(s.name),
        children: [
          for (final e in const {'absent': 'غائب', 'excused': 'غائب بعذر', 'norecite': 'حضر ولم يسمّع'}.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, e.key),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(e.value, style: const TextStyle(fontSize: 16))),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'details'),
            child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('تسجيل مفصّل', style: TextStyle(fontSize: 16, color: brandGreen))),
          ),
        ],
      ),
    );
    if (r == null) return;
    if (r == 'details') {
      _open(s, st, l);
    } else {
      _quickStatus(s, st, r);
    }
  }

  Future<void> _markRestAbsent(List<Student> todo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الباقين غائب؟'),
        content: Text('سيُسجَّل ${todo.length} طالب غائبين لهذا اليوم. يمكن تعديل أي واحد بعدها.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (ok != true) return;
    for (final s in todo) {
      _quickStatus(s, _statusOf(s), 'absent');
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final all = [..._students];
    final numbers = {for (var i = 0; i < all.length; i++) all[i].id: i + 1};
    final students = _q.isEmpty ? all : all.where((s) => s.name.contains(_q)).toList();
    final todo = students.where((s) => _todayLog(s.id) == null).toList();
    final done = students.where((s) => _todayLog(s.id) != null).toList();
    final doneAll = all.where((s) => _todayLog(s.id) != null).toList();
    final todoAll = all.where((s) => _todayLog(s.id) == null).toList();
    final absent = doneAll.where((s) {
      final l = _todayLog(s.id)!;
      return l['status'] == 'absent' || l['status'] == 'excused';
    }).length;
    final pending = _logs.where((l) => l['_pending'] == true).length;
    return Scaffold(
      appBar: AppBar(
        title: const BrandTitle('السجل اليومي'),
        actions: [
          TextButton(
            onPressed: () {
              Repo.I.setSheikhId(null);
              Navigator.of(context)
                  .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const GateScreen()), (r) => false);
            },
            child: const Text('خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
              children: [
                _header(now, doneAll.length, todoAll.length, absent, pending, all.length),
                const SizedBox(height: 8),
                if (all.length > 6)
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'بحث عن طالب',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _q = v.trim()),
                  ),
                if (all.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('لا يوجد طلاب في الحلقة', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ),
                if (todo.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
                    child: Text('${(_holidayAll || _holidayHalaqa) ? 'إجازة' : 'لم يُسجّل بعد'} (${todo.length})',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black54)),
                  ),
                  if (!(_holidayAll || _holidayHalaqa))
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
                      child: Text('اضغط مطوّلاً على الطالب لتسجيل الغياب', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    )
                  else
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
                    child: Text('لا يُحسب غياب اليوم. من يسمّع يُسجَّل له حفظه ومراجعته.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF9A6700))),
                  ),
                  for (final s in todo) _studentRow(s, numbers[s.id] ?? 0),
                ],
                if (done.isNotEmpty)
                  InkWell(
                    onTap: () => setState(() => _showDone = !_showDone),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                      child: Row(children: [
                        Expanded(
                          child: Text('تم التسجيل (${done.length})',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black54)),
                        ),
                        Text(_showDone ? 'إخفاء' : 'عرض',
                            style: const TextStyle(color: brandGreen, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                if (_showDone || _q.isNotEmpty)
                  for (final s in done) _studentRow(s, numbers[s.id] ?? 0),
                if (todoAll.isNotEmpty && !_holidayAll && !_holidayHalaqa && _q.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        foregroundColor: Colors.red.shade700,
                      ),
                      onPressed: () => _markRestAbsent(todoAll),
                      child: Text('تسجيل الباقين غائب (${todoAll.length})'),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _studentRow(Student s, int number) {
    final st = _statusOf(s);
    final l = _todayLog(s.id);
    final warn = l == null ? null : _warning(l, st);
    final Color modeColor = switch (st.mode) {
      'memorize' => brandGreen,
      'review_surah' => Colors.red.shade700,
      'needs_start' => const Color(0xFF9A6700),
      _ => const Color(0xFF1F4E8C),
    };
    final status = l == null ? null : (l['status'] ?? '').toString();
    final Color stColor = switch (status) {
      'recited' => brandGreen,
      'absent' => Colors.red.shade700,
      'excused' => const Color(0xFF9A6700),
      'norecite' => Colors.red.shade400,
      _ => Colors.grey,
    };
    final canQuick = l == null && st.mode == 'memorize' && st.fromG != null && st.suggestToG != null;
    String sub = st.title;
    if (canQuick) {
      sub = '${st.title}\nالحفظ التالي: ${memRangeLabel(s.pathDir, st.fromG!, st.suggestToG!)} '
          '(${fmtPages(memRangePages(s.pathDir, st.fromG!, st.suggestToG!))} ص)';
    } else if (l != null && status == 'recited') {
      sub = '${st.title}\n${_shortSummary(l)}';
    }
    final holiday = _holidayAll || _holidayHalaqa;
    Widget action;
    if (l == null && holiday && st.mode == 'needs_start') {
      action = const Text('إجازة', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold));
    } else if (l != null) {
      action = Text(statusText(status), style: TextStyle(color: stColor, fontWeight: FontWeight.bold));
    } else if (st.mode == 'needs_start') {
      action = OutlinedButton(onPressed: () => _open(s, st, l), child: const Text('تحديد البداية'));
    } else if (canQuick) {
      action = FilledButton(onPressed: () => _quickRecite(s, st), child: const Text('سمّع'));
    } else {
      action = FilledButton.tonal(onPressed: () => _open(s, st, l), child: const Text('تسجيل'));
    }
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(s, st, l),
        onLongPress: () => _longPress(s, st, l),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: const Color(0xFFE8F3EC),
                child: Text('$number', style: const TextStyle(color: brandGreen, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name + (s.pending ? ' (جديد)' : ''),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(sub, style: TextStyle(color: modeColor, fontSize: 12.5, height: 1.4)),
                    if (warn != null) Text(warn, style: const TextStyle(color: Color(0xFF9A6700), fontSize: 12)),
                    if (l != null && l['_pending'] == true)
                      const Text('بانتظار الرفع', style: TextStyle(color: Color(0xFF9A6700), fontSize: 11.5)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              action,
            ],
          ),
        ),
      ),
    );
  }

  /// بيانات الطالب لشاشة التسجيل: الحالة محسوبة بدون تسجيل اليوم (حتى يظهر المطلوب لليوم نفسه عند التعديل)
  DayCtx _ctx(Student s) {
    final all = _logsOf(s.id);
    final before = all.where((l) => (l['date'] ?? '').toString().compareTo(_today) < 0).toList()
      ..sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
    final passed = {
      for (final e in _exams)
        if (e['studentId'] == s.id && e['passed'] == true) '${e['type']}|${e['startJuz']}'
    };
    final pr = _progress.where((p) => p['id'] == s.id);
    final st = dailyStatus(s.pathDir, s.pathStart, passed, before, pr.isEmpty ? null : pr.first, _minNew);
    return DayCtx(st, _todayLog(s.id), _base(s, st), before.take(5).toList());
  }

  void _open(Student s, DailyStatus st, Map<String, dynamic>? l) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _dayScreen(s)));
  }

  Widget _dayScreen(Student s) => StudentDayScreen(
        student: s,
        ctxFn: _ctx,
        order: [..._students],
        halaqaId: _halaqaId,
        sheikhName: _sheikhName,
        minNew: _minNew,
        minReview: _minReview,
        date: _today,
        builder: _dayScreen,
      );
}

/// سياق تسجيل طالب
class DayCtx {
  final DailyStatus st;
  final Map<String, dynamic>? todayLog;
  final Map<String, dynamic> base;
  final List<Map<String, dynamic>> recent; // آخر الجلسات قبل اليوم (الأحدث أولاً)
  DayCtx(this.st, this.todayLog, this.base, this.recent);
}

// ===================== تسجيل طالب لليوم =====================
class StudentDayScreen extends StatefulWidget {
  final Student student;
  final DayCtx Function(Student) ctxFn;
  final List<Student> order;
  final String halaqaId, sheikhName, date;
  final double minNew, minReview;
  final Widget Function(Student) builder;
  const StudentDayScreen({
    super.key,
    required this.student,
    required this.ctxFn,
    required this.order,
    required this.halaqaId,
    required this.sheikhName,
    required this.minNew,
    required this.minReview,
    required this.date,
    required this.builder,
  });

  @override
  State<StudentDayScreen> createState() => _StudentDayScreenState();
}

class _StudentDayScreenState extends State<StudentDayScreen> {
  late final DayCtx _c = widget.ctxFn(widget.student);
  String _att = 'recited';
  bool _hasNew = false;
  int? _from, _to;
  final List<Map<String, dynamic>> _reviews = [];
  final _notes = TextEditingController();

  // نقطة البداية
  int? _startSurah, _startAyah;

  String get _dir => widget.student.pathDir;
  DailyStatus get _st => _c.st;
  MemOrder get _o => memOrder(_dir);

  @override
  void initState() {
    super.initState();
    final l = _c.todayLog;
    if (l != null) {
      _att = (l['status'] ?? 'recited').toString();
      _notes.text = (l['notes'] ?? '').toString();
      for (final r in (l['reviews'] as List?) ?? []) {
        if (r is Map) _reviews.add(Map<String, dynamic>.from(r));
      }
      final nm = l['newMem'];
      if (nm is Map && nm['fromG'] is num && nm['toG'] is num) {
        _hasNew = true;
        _from = (nm['fromG'] as num).toInt();
        _to = (nm['toG'] as num).toInt();
      }
    }
    if (_from == null && _st.mode == 'memorize' && _st.fromG != null) {
      _hasNew = l == null;
      _from = _st.fromG;
      _to = _st.suggestToG;
    }
  }

  int get _juz => _from != null ? juzOfG(_from!) : _st.juz;

  bool get _surahReviewDone {
    if (_st.mode != 'review_surah') return true;
    return _reviews.any((r) => (r['fromG'] as num) <= _st.segFrom! && (r['toG'] as num) >= _st.segTo!);
  }

  bool get _canNew {
    if (_c.todayLog?['newMem'] is Map) return true;
    if (_st.mode == 'memorize') return true;
    return _st.mode == 'review_surah' && _surahReviewDone;
  }

  void _ensureNewAfterSurahReview() {
    if (_from != null || _st.mode != 'review_surah' || !_surahReviewDone) return;
    final p = _o.pos[_st.segTo!] + 1;
    final j = _st.juz;
    if (p > _o.jEnd[j]) return;
    _from = _o.order[p];
    _to = _toForPages(widget.minNew);
    _hasNew = true;
  }

  /// "إلى" بحيث يكون الحفظ بعدد صفحات معيّن (ضمن الجزء)
  int _toForPages(double pages) {
    final p = _o.pos[_from!];
    final end = _o.jEnd[_juz];
    var t = 0.0;
    var toPos = p;
    for (var i = p; i <= end; i++) {
      t += ayahFrac(_o.order[i]);
      toPos = i;
      if (t >= pages - 1e-9) break;
    }
    return _o.order[toPos];
  }

  double get _newPages => (_hasNew && _from != null && _to != null) ? memRangePages(_dir, _from!, _to!) : 0;
  double get _reviewPages => _reviews.fold(0.0, (a, r) => a + ((r['pages'] ?? 0) as num).toDouble());

  List<int> _ayahsIn(int s, int j) {
    final lo = qJuz[j - 1][0] > surahFirst(s) ? qJuz[j - 1][0] : surahFirst(s);
    final hi = qJuz[j - 1][1] < surahEnd(s) ? qJuz[j - 1][1] : surahEnd(s);
    return [for (var g = lo; g <= hi; g++) g];
  }

  /// يقسم مجموعة آيات إلى مقاطع متصلة في المصحف
  List<List<int>> _chunks(Iterable<int> gs) {
    final l = gs.toList()..sort();
    final out = <List<int>>[];
    for (final g in l) {
      if (out.isNotEmpty && out.last[1] + 1 == g) {
        out.last[1] = g;
      } else {
        out.add([g, g]);
      }
    }
    return out;
  }

  Map<String, dynamic> _rev(String kind, int a, int b, [String? label]) =>
      {'kind': kind, 'fromG': a, 'toG': b, 'pages': pagesOfRange(a, b), 'label': label ?? rangeLabel(a, b)};

  Map<String, dynamic>? get _suggestedReview {
    if (_st.mode == 'review_exam') {
      final a = qJuz[_st.juzFrom - 1][0], b = qJuz[_st.juzTo - 1][1];
      return _rev('juz', a, b, _st.juzFrom == _st.juzTo ? 'الجزء ${_st.juzFrom}' : 'الأجزاء ${_st.juzFrom}–${_st.juzTo}');
    }
    if (_st.mode == 'review_surah') return _rev('surah', _st.segFrom!, _st.segTo!);
    return null;
  }

  /// موضع آخر آية محفوظة قبل اليوم (في ترتيب الحفظ)
  int? get _cursorPos {
    if (_st.mode == 'memorize' && _st.fromG != null) return _o.pos[_st.fromG!] - 1;
    if (_st.mode == 'review_surah') return _o.pos[_st.segTo!];
    return null;
  }

  /// مراجعات سريعة: آخر ما حفظه (5 صفحات) والجزء الحالي من أوله
  List<MapEntry<String, List<Map<String, dynamic>>>> get _quickReviews {
    final cp = _cursorPos;
    if (cp == null) return [];
    final j = _st.juz;
    final js = _o.jStart[j];
    if (cp < js) return [];
    final last = <int>[];
    var t = 0.0;
    for (var i = cp; i >= js && t < 5 - 1e-9; i--) {
      last.add(_o.order[i]);
      t += ayahFrac(_o.order[i]);
    }
    final whole = [for (var i = js; i <= cp; i++) _o.order[i]];
    List<Map<String, dynamic>> toRevs(List<int> gs) => [for (final c in _chunks(gs)) _rev('ayat', c[0], c[1])];
    return [
      MapEntry('آخر ما حفظه (${fmtPages(t)} ص)', toRevs(last)),
      MapEntry('الجزء $j من أوله', toRevs(whole)),
    ];
  }

  void _addReview(Map<String, dynamic> r) => setState(() {
        _reviews.add(r);
        _ensureNewAfterSurahReview();
      });

  String? get _todayRequired {
    if (_st.mode == 'memorize' && _st.fromG != null && _st.suggestToG != null) {
      return 'المطلوب اليوم: ${memRangeLabel(_dir, _st.fromG!, _st.suggestToG!)} '
          '(${fmtPages(memRangePages(_dir, _st.fromG!, _st.suggestToG!))} صفحة)';
    }
    final r = _suggestedReview;
    if (r != null) return 'المطلوب اليوم: مراجعة ${r['label']} (${fmtPages((r['pages'] as num).toDouble())} صفحة)';
    return null;
  }

  Future<void> _reviewDialog(String kind) async {
    var s = 1, a1 = 1, a2 = qCounts[0], j1 = 30, j2 = 30;
    final r = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        Widget surahPick() => DropdownButtonFormField<int>(
              value: s,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'السورة'),
              items: [for (var i = 1; i <= 114; i++) DropdownMenuItem(value: i, child: Text('$i. ${surahName(i)}'))],
              onChanged: (v) => setD(() {
                s = v ?? 1;
                a1 = 1;
                a2 = qCounts[s - 1];
              }),
            );
        Widget ayahPick(String label, int v, void Function(int) f) => DropdownButtonFormField<int>(
              value: v,
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: [for (var i = 1; i <= qCounts[s - 1]; i++) DropdownMenuItem(value: i, child: Text('$i'))],
              onChanged: (x) => setD(() => f(x ?? v)),
            );
        Widget juzPick(String label, int v, void Function(int) f) => DropdownButtonFormField<int>(
              value: v,
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: [for (var i = 1; i <= 30; i++) DropdownMenuItem(value: i, child: Text('الجزء $i'))],
              onChanged: (x) => setD(() => f(x ?? v)),
            );
        final children = <Widget>[];
        if (kind == 'juz') {
          children.addAll([
            juzPick('من الجزء', j1, (x) => j1 = x),
            const SizedBox(height: 10),
            juzPick('إلى الجزء', j2, (x) => j2 = x),
          ]);
        } else {
          children.add(surahPick());
          if (kind == 'ayat') {
            children.addAll([
              const SizedBox(height: 10),
              ayahPick('من الآية', a1, (x) => a1 = x),
              const SizedBox(height: 10),
              ayahPick('إلى الآية', a2, (x) => a2 = x),
            ]);
          }
        }
        return AlertDialog(
          title: Text(kind == 'juz' ? 'مراجعة أجزاء' : kind == 'surah' ? 'مراجعة سورة' : 'مراجعة آيات'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: children)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                int fromG, toG;
                String label;
                if (kind == 'juz') {
                  final lo = j1 < j2 ? j1 : j2, hi = j1 < j2 ? j2 : j1;
                  fromG = qJuz[lo - 1][0];
                  toG = qJuz[hi - 1][1];
                  label = lo == hi ? 'الجزء $lo' : 'الأجزاء $lo–$hi';
                } else if (kind == 'surah') {
                  fromG = surahFirst(s);
                  toG = surahEnd(s);
                  label = 'سورة ${surahName(s)}';
                } else {
                  final lo = a1 < a2 ? a1 : a2, hi = a1 < a2 ? a2 : a1;
                  fromG = gidOf(s, lo);
                  toG = gidOf(s, hi);
                  label = rangeLabel(fromG, toG);
                }
                Navigator.pop(ctx, {
                  'kind': kind,
                  'fromG': fromG,
                  'toG': toG,
                  'pages': pagesOfRange(fromG, toG),
                  'label': label,
                });
              },
              child: const Text('إضافة'),
            ),
          ],
        );
      }),
    );
    if (r != null) _addReview(r);
  }

  int? get _nextIndex {
    final i = widget.order.indexWhere((x) => x.id == widget.student.id);
    for (var k = i + 1; k < widget.order.length; k++) {
      if (widget.ctxFn(widget.order[k]).todayLog == null) return k;
    }
    return null;
  }

  void _save({bool next = false}) {
    final recited = _att == 'recited';
    final withNew = recited && _hasNew && _canNew && _from != null && _to != null;
    final np = withNew ? _newPages : 0.0;
    Repo.I.saveLog(widget.student.id, widget.date, prev: _c.todayLog, {
      ..._c.base,
      'status': _att,
      'newMem': withNew
          ? {'fromG': _from, 'toG': _to, 'pages': np, 'label': memRangeLabel(_dir, _from!, _to!)}
          : null,
      'reviews': recited ? _reviews : <Map<String, dynamic>>[],
      'newPages': np,
      'reviewPages': recited ? _reviewPages : 0,
      'notes': _notes.text.trim(),
    });
    final messenger = ScaffoldMessenger.of(context);
    final ni = next ? _nextIndex : null;
    if (ni != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => widget.builder(widget.order[ni])));
    } else {
      Navigator.of(context).pop();
    }
    messenger.showSnackBar(SnackBar(
      content: Text('تم حفظ ${widget.student.name}'),
      duration: const Duration(seconds: 2),
    ));
  }

  // ---------- عناصر التصميم ----------
  Widget _card({required Widget child, String? title, Widget? trailing}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: brandGreen)),
                  ),
                  if (trailing != null) trailing,
                ]),
              ),
            child,
          ],
        ),
      );

  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      );

  Widget _box(String text, Color bg, Color fg) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.bold, height: 1.5)),
      );

  Widget _h(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: brandGreen)),
      );

  static const _blue = Color(0xFF1F4E8C);
  static const _amber = Color(0xFF9A6700);

  // ---------- المربع العلوي ----------
  Widget _topCard() {
    final j = _st.juz;
    final cp = _cursorPos;
    String? pctText;
    double? pct;
    if (j > 0 && cp != null) {
      final js = _o.jStart[j];
      var done = 0.0;
      for (var i = js; i <= cp; i++) {
        done += ayahFrac(_o.order[i]);
      }
      final total = pagesOfRange(qJuz[j - 1][0], qJuz[j - 1][1]);
      pct = total == 0 ? 0 : (done / total).clamp(0.0, 1.0);
      pctText = 'أنجز ${(pct * 100).round()}% من الجزء';
    } else if (_st.mode == 'review_exam' && _st.juzFrom == _st.juzTo) {
      pct = 1;
      pctText = 'أنهى حفظ الجزء';
    }
    // خريطة سور الجزء
    final chips = <Widget>[];
    if ((_st.mode == 'memorize' || _st.mode == 'review_surah') && j > 0) {
      final curS = _st.fromG != null ? surahOf(_st.fromG!) : null;
      for (final s in surahsOfJuz(_dir, j)) {
        final g = _ayahsIn(s, j);
        final doneS = cp != null && _o.pos[g.reduce((a, b) => _o.pos[a] > _o.pos[b] ? a : b)] <= cp;
        final cur = !doneS && s == curS;
        chips.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: doneS ? brandGreen : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: cur ? const Color(0xFFC88A12) : (doneS ? brandGreen : const Color(0xFFB9D3C4)), width: cur ? 2 : 1),
          ),
          child: Text(surahName(s),
              style: TextStyle(
                  fontSize: 11.5,
                  color: doneS ? Colors.white : (cur ? _amber : brandGreen),
                  fontWeight: cur ? FontWeight.bold : FontWeight.normal)),
        ));
      }
    }
    // آخر الجلسات
    final rec = _c.recent;
    String? lastLine;
    if (rec.isNotEmpty) {
      final l = rec.first;
      final d = DateTime.tryParse((l['date'] ?? '').toString());
      final when = d == null ? '' : '${dayName(d)} ${d.day}/${d.month}';
      final parts = <String>[];
      if (l['status'] != 'recited') {
        parts.add(SheikhHomeScreenStateText.of(l['status'] as String?));
      } else {
        final nm = l['newMem'];
        if (nm is Map) parts.add('سمّع ${nm['label'] ?? ''}');
        final rv = ((l['reviews'] as List?) ?? []).whereType<Map>().map((r) => r['label']).join('، ');
        if (rv.isNotEmpty) parts.add('راجع $rv');
      }
      lastLine = 'آخر مرة ($when): ${parts.join(' · ')}';
    }
    Widget dot(String? st) {
      final (Color c, String t) = switch (st) {
        'recited' => (brandGreen, '✓'),
        'absent' => (Colors.red.shade700, 'غ'),
        'excused' => (const Color(0xFFC88A12), 'ع'),
        'norecite' => (Colors.red.shade300, 'ل'),
        _ => (Colors.grey, '·'),
      };
      return Container(
        width: 22,
        height: 22,
        margin: const EdgeInsetsDirectional.only(start: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }

    final req = _todayRequired;
    final holidayToday = _c.base['holiday'] == true;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: const Color(0xFFE8F3EC), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (holidayToday)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFFFF4DE), borderRadius: BorderRadius.circular(8)),
              child: const Text('يوم إجازة — التسجيل اختياري ولا يُحسب غياب',
                  style: TextStyle(color: _amber, fontSize: 12.5, fontWeight: FontWeight.bold)),
            ),
          Row(children: [
            Expanded(child: Text(_st.title, style: const TextStyle(color: brandGreen, fontSize: 13.5))),
            if (pctText != null) Text(pctText, style: const TextStyle(color: brandGreen, fontSize: 13)),
          ]),
          if (pct != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                    value: pct, minHeight: 6, color: brandGreen, backgroundColor: const Color(0xFFCFE3D8)),
              ),
            ),
          if (req != null)
            Text(req, style: const TextStyle(color: brandGreen, fontWeight: FontWeight.bold, fontSize: 16, height: 1.5)),
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 4, runSpacing: 4, children: chips),
            ),
          if (lastLine != null || rec.isNotEmpty) ...[
            const Divider(height: 18, color: Color(0xFFB9D3C4)),
            if (lastLine != null) Text(lastLine, style: const TextStyle(color: Color(0xFF5B6B63), fontSize: 12.5)),
            const SizedBox(height: 6),
            Row(children: [
              const Text('آخر الجلسات:', style: TextStyle(color: Color(0xFF5B6B63), fontSize: 12.5)),
              for (final l in rec.reversed) dot(l['status'] as String?),
            ]),
          ],
        ],
      ),
    );
  }

  // ---------- تحديد نقطة البداية ----------
  Widget _startPointView() {
    final j = _st.juz;
    final surahs = surahsOfJuz(_dir, j);
    final s = _startSurah ?? surahs.first;
    final ayahs = _ayahsIn(s, j).map(ayahNo).toList();
    final a = (_startAyah != null && ayahs.contains(_startAyah)) ? _startAyah! : ayahs.last;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _box('أول مرة للطالب في السجل اليومي.\nحدّد آخر آية حفظها في الجزء $j (${juzNames[j]})، وبعدها يكمل التطبيق تلقائياً.',
            const Color(0xFFFFF4DE), const Color(0xFF9A6700)),
        const SizedBox(height: 16),
        BigButton(
          icon: Icons.play_arrow,
          text: 'لم يبدأ حفظ الجزء $j بعد',
          filled: false,
          onPressed: () {
            Repo.I.setProgress(widget.student.id, widget.halaqaId, null, widget.sheikhName);
            Navigator.of(context).pop();
          },
        ),
        _h('أو: آخر آية حفظها'),
        DropdownButtonFormField<int>(
          value: s,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'السورة'),
          items: [for (final x in surahs) DropdownMenuItem(value: x, child: Text(surahName(x)))],
          onChanged: (v) => setState(() {
            _startSurah = v;
            _startAyah = null;
          }),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          value: a,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'الآية'),
          items: [for (final x in ayahs) DropdownMenuItem(value: x, child: Text('$x'))],
          onChanged: (v) => setState(() => _startAyah = v),
        ),
        const SizedBox(height: 6),
        const Text('إذا أنهى الجزء كاملاً اختر آخر آية فيه.', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 16),
        BigButton(
          icon: Icons.save,
          text: 'حفظ نقطة البداية',
          onPressed: () {
            Repo.I.setProgress(widget.student.id, widget.halaqaId, gidOf(s, a), widget.sheikhName);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  // ---------- الحفظ الجديد ----------
  Widget _newMemBody() {
    final o = _o;
    final j = _juz;
    final fromPos = o.pos[_from!];
    final surahs = surahsOfJuz(_dir, j).where((s) => _ayahsIn(s, j).any((x) => o.pos[x] >= fromPos)).toList();
    final toS = surahOf(_to!);
    final toAyahs = _ayahsIn(toS, j).where((g) => o.pos[g] >= fromPos).toList();
    final pages = _newPages;
    final p1 = pageOf(_from! < _to! ? _from! : _to!), p2 = pageOf(_from! < _to! ? _to! : _from!);
    final seg = _ayahsIn(toS, j);
    final segDone = seg.where((g) => o.pos[g] <= o.pos[_to!]).length;
    Widget chip(String t, double v) {
      final on = (pages - v).abs() < 0.26;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 6),
              backgroundColor: on ? const Color(0xFFE8F3EC) : null,
              side: BorderSide(color: on ? brandGreen : const Color(0xFFCFD6D2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () => setState(() => _to = _toForPages(v)),
            child: Text(t, style: TextStyle(fontSize: 12.5, color: on ? brandGreen : Colors.black87)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [chip('½ صفحة', 0.5), chip('صفحة', 1), chip('صفحتين', 2), chip('3 صفحات', 3)]),
        const SizedBox(height: 10),
        Row(children: [
          const SizedBox(width: 34, child: Text('من', style: TextStyle(color: Colors.black54))),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7F6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD5DAD7)),
              ),
              child: Text(posLabel(_from!), style: const TextStyle(fontSize: 15)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const SizedBox(width: 34, child: Text('إلى', style: TextStyle(color: Colors.black54))),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: surahs.contains(toS) ? toS : null,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: [for (final s in surahs) DropdownMenuItem(value: s, child: Text(surahName(s)))],
              onChanged: (v) => setState(() {
                if (v == null) return;
                _to = _ayahsIn(v, j).where((g) => o.pos[g] >= fromPos).toList().last;
              }),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: DropdownButtonFormField<int>(
              value: toAyahs.contains(_to) ? _to : null,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: [for (final g in toAyahs) DropdownMenuItem(value: g, child: Text('${ayahNo(g)}'))],
              onChanged: (v) => setState(() => _to = v ?? _to),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFF6F7F6), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Expanded(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: memRangeLabel(_dir, _from!, _to!), style: const TextStyle(fontSize: 15)),
                TextSpan(
                    text: p1 == p2 ? '  (ص $p1)' : '  (ص $p1–$p2)',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ])),
            ),
            _pill('${fmtPages(pages)} صفحة', pages < widget.minNew - 1e-9 ? _amber : brandGreen),
          ]),
        ),
        if (pages < widget.minNew - 1e-9)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('أقل من الحد الأدنى للحفظ (${fmt(widget.minNew)} صفحة)',
                style: const TextStyle(color: _amber, fontSize: 12.5)),
          ),
        const SizedBox(height: 8),
        Text('سورة ${surahName(toS)}: $segDone من ${seg.length} آية بعد اليوم',
            style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: seg.isEmpty ? 0 : segDone / seg.length,
            minHeight: 7,
            color: const Color(0xFF7FBF9F),
            backgroundColor: const Color(0xFFEEEEEE),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final idx = widget.order.indexWhere((x) => x.id == s.id);
    final counter = idx >= 0 ? 'الطالب ${idx + 1} من ${widget.order.length}' : '';
    final appBar = AppBar(
      title: BrandTitle(s.name),
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 14),
          child: Center(child: Text(counter, style: const TextStyle(color: Color(0xFFCFE3D8), fontSize: 13))),
        ),
      ],
    );
    if (_st.mode == 'needs_start') {
      return Scaffold(appBar: appBar, body: _startPointView());
    }
    final recited = _att == 'recited';
    final sugg = _suggestedReview;
    bool added(Map<String, dynamic> r) => _reviews.any((x) => x['fromG'] == r['fromG'] && x['toG'] == r['toG']);
    final quick = _quickReviews;
    final hasNext = _nextIndex != null;
    final summary = recited
        ? 'اليوم: ${_hasNew && _canNew ? 'حفظ ${fmtPages(_newPages)} ص · ' : ''}مراجعة ${fmtPages(_reviewPages)} ص'
        : 'اليوم: ${SheikhHomeScreenStateText.of(_att)}';
    return Scaffold(
      appBar: appBar,
      backgroundColor: const Color(0xFFF3F2EC),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          _topCard(),
          _card(
            title: 'الحضور',
            child: SegmentedRow(
              items: const ['سمّع', 'لم يسمّع', 'غائب', 'بعذر'],
              selected: const ['recited', 'norecite', 'absent', 'excused'].indexOf(_att),
              onChanged: (i) => setState(() => _att = const ['recited', 'norecite', 'absent', 'excused'][i]),
            ),
          ),
          if (recited) ...[
            _card(
              title: 'الحفظ الجديد',
              trailing: (_canNew && _from != null) ? Switch(value: _hasNew, onChanged: (v) => setState(() => _hasNew = v)) : null,
              child: (_st.mode == 'review_surah' && !_surahReviewDone)
                  ? _box('لازم يراجع ${rangeLabel(_st.segFrom!, _st.segTo!)} كاملة قبل الحفظ الجديد.', Colors.red.shade50,
                      Colors.red.shade800)
                  : (_canNew && _from != null)
                      ? (_hasNew
                          ? _newMemBody()
                          : const Text('لم يسمّع حفظاً جديداً اليوم.', style: TextStyle(color: Colors.black54)))
                      : Text(
                          _st.mode == 'review_exam'
                              ? 'لا حفظ جديد: الطالب في مرحلة المراجعة للاختبار.'
                              : _st.mode == 'hafiz'
                                  ? 'الطالب حافظ للقرآن — مراجعة فقط.'
                                  : 'لا يوجد حفظ جديد متاح.',
                          style: const TextStyle(color: Colors.black54),
                        ),
            ),
            _card(
              title: 'المراجعة',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if ((sugg != null && !added(sugg)) || quick.isNotEmpty)
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      if (sugg != null && !added(sugg))
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE6EEF8), foregroundColor: _blue),
                          onPressed: () => _addReview(sugg),
                          child: Text('المطلوبة: ${sugg['label']}'),
                        ),
                      for (final q in quick)
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE6EEF8), foregroundColor: _blue),
                          onPressed: () => setState(() {
                            for (final r in q.value) {
                              if (!added(r)) _reviews.add(r);
                            }
                            _ensureNewAfterSurahReview();
                          }),
                          child: Text(q.key),
                        ),
                    ]),
                  for (var i = 0; i < _reviews.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
                      child: Row(children: [
                        Expanded(child: Text('${_reviews[i]['label']}', style: const TextStyle(fontSize: 14))),
                        _pill('${fmtPages(((_reviews[i]['pages'] ?? 0) as num).toDouble())} ص', _blue),
                        TextButton(
                          onPressed: () => setState(() => _reviews.removeAt(i)),
                          child: Text('حذف', style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (final e in const {'ayat': '+ آيات', 'surah': '+ سورة', 'juz': '+ جزء'}.entries)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: OutlinedButton(onPressed: () => _reviewDialog(e.key), child: Text(e.value)),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Expanded(child: Text('مجموع المراجعة', style: TextStyle(fontWeight: FontWeight.bold))),
                    Text('${fmtPages(_reviewPages)} صفحة', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  if (_st.isReview && _reviewPages < widget.minReview - 1e-9)
                    Text('أقل من الحد الأدنى للمراجعة (${fmt(widget.minReview)} صفحات)',
                        style: const TextStyle(color: _amber, fontSize: 12.5)),
                ],
              ),
            ),
          ],
          _card(
            title: 'ملاحظة',
            child: TextField(
              controller: _notes,
              decoration: const InputDecoration(hintText: 'اختياري', isDense: true),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, -2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(summary, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () => _save(),
                    child: const Text('حفظ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (hasNext) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () => _save(next: true),
                      child: const Text('حفظ والتالي ←', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// نصوص حالات الحضور
class SheikhHomeScreenStateText {
  static String of(String? s) => switch (s) {
        'recited' => 'سمّع',
        'norecite' => 'لم يسمّع',
        'absent' => 'غائب',
        'excused' => 'غائب بعذر',
        _ => '',
      };
}
