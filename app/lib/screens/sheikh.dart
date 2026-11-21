import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../daily.dart';
import '../logic.dart';
import '../quran_data.dart';
import '../repo.dart';
import '../update_check.dart';
import 'gate.dart';
import 'ui.dart';
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
                    child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: context.badFg, fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(height: 18),
                BigButton(icon: Icons.login, text: 'دخول', onPressed: () => _login(list), gold: true),
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
  bool _showDone = true;
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

  /// شرط الاختبار من السجل اليومي (تسميع الجزء كاملاً في جلسة)
  ExamReady _readiness(Student s, List<Map<String, dynamic>> logs) {
    final mine = _exams.where((e) => e['studentId'] == s.id);
    final passed = {
      for (final e in mine)
        if (e['passed'] == true) '${e['type']}|${e['startJuz']}'
    };
    var m = 0;
    for (final e in mine) {
      final t = e['createdAt'];
      final ms = t is Timestamp ? t.millisecondsSinceEpoch : 0;
      if (ms > m) m = ms;
    }
    final last = m == 0 ? '' : dayKey(DateTime.fromMillisecondsSinceEpoch(m));
    final pr = _progress.where((p) => p['id'] == s.id);
    return examReadiness(s.pathDir, s.pathStart, passed, logs, pr.isEmpty ? null : pr.first, last, fromKey: s.pathFrom);
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
    return dailyStatus(s.pathDir, s.pathStart, passed, _logsOf(s.id), pr.isEmpty ? null : pr.first, _minNew,
        fromKey: s.pathFrom);
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
    final holiday = _holidayAll || _holidayHalaqa;
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Flexible(
              child: Text(_halaqaName.isEmpty ? 'الحلقة' : _halaqaName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.ink, fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('${dayName(now)} ${now.day}/${now.month}',
                  style: TextStyle(color: context.sub, fontSize: 13)),
            ),
            const Spacer(),
            if (!_holidayAll)
              InkWell(
                onTap: _toggleHoliday,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(_holidayHalaqa ? 'إلغاء الإجازة' : 'إجازة',
                      style: const TextStyle(color: brandGold, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
          ]),
          Text('المشايخ: ${names.isEmpty ? _sheikhName : names}',
              style: TextStyle(color: context.sub, fontSize: 12.5), overflow: TextOverflow.ellipsis),
          if (holiday || !_isSessionDay)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: context.goldBg, borderRadius: BorderRadius.circular(8)),
              child: Text(
                [
                  if (_holidayAll) 'اليوم إجازة للمركز — التسجيل اختياري',
                  if (!_holidayAll && _holidayHalaqa) 'اليوم إجازة للحلقة — التسجيل اختياري',
                  if (!_isSessionDay) 'جلسة إضافية (ليس يوم تحفيظ)',
                ].join(' · '),
                style: TextStyle(color: context.goldFg, fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 10),
          Row(children: [
            Text('$done من $total سجّلوا',
                style: TextStyle(color: context.accent, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(width: 10),
            Expanded(child: MiniBar(total == 0 ? 0 : done / total, color: context.accent, height: 7)),
          ]),
          if (absent > 0 || pending > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [if (absent > 0) 'غياب $absent', if (pending > 0) 'بانتظار الرفع $pending'].join(' · '),
                style: TextStyle(color: context.sub, fontSize: 12.5),
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
    haptic();
    final r = await showAppSheet<String>(
      context,
      title: s.name,
      builder: (ctx, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in const {'absent': 'غائب', 'excused': 'غائب بعذر', 'norecite': 'حضر ولم يسمّع'}.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => Navigator.pop(ctx, e.key),
                child: Text(e.value, style: TextStyle(fontSize: 16, color: ctx.ink, fontWeight: FontWeight.w700)),
              ),
            ),
          const SizedBox(height: 4),
          NavyButton(text: 'تسجيل مفصّل', onPressed: () => Navigator.pop(ctx, 'details')),
        ],
      ),
    );
    if (r == null) return;
    if (r == 'details') {
      _open(s, st, l);
    } else {
      _quickStatus(s, st, r);
      if (mounted) showSavedTick(context, sub: s.name);
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
    if (mounted) showSavedTick(context, sub: 'سُجّل ${todo.length} غائبين');
  }

  /// نقطة البداية (نافذة من تحت)
  Future<void> _startSheet(Student s, DailyStatus st) async {
    final j = st.juz;
    if (j <= 0) return;
    final dir = s.pathDir;
    final surahs = surahsOfJuz(dir, j);
    List<int> ayahsIn(int x) {
      final lo = qJuz[j - 1][0] > surahFirst(x) ? qJuz[j - 1][0] : surahFirst(x);
      final hi = qJuz[j - 1][1] < surahEnd(x) ? qJuz[j - 1][1] : surahEnd(x);
      return [for (var g = lo; g <= hi; g++) ayahNo(g)];
    }

    var fresh = true;
    var sel = surahs.first;
    var ay = ayahsIn(sel).last;
    final res = await showAppSheet<int?>(
      context,
      title: 'من وين بيبلش «${s.name}»؟',
      subtitle: 'مرة واحدة فقط — بعدها التطبيق بيكمل لحاله',
      builder: (ctx, setS) {
        Widget opt(String t, bool on, VoidCallback f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: on ? ctx.soft : ctx.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: on ? ctx.accent : ctx.line, width: on ? 2 : 1),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    haptic();
                    setS(f);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(children: [
                      Icon(on ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: on ? ctx.accent : ctx.sub, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ctx.ink))),
                    ]),
                  ),
                ),
              ),
            );
        final ayahs = ayahsIn(sel);
        if (!ayahs.contains(ay)) ay = ayahs.last;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            opt('بيبلش الجزء $j من أوله', fresh, () => fresh = true),
            opt('حافظ لحد آية معيّنة', !fresh, () => fresh = false),
            if (!fresh) ...[
              Row(children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int>(
                    value: sel,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'السورة'),
                    items: [for (final x in surahs) DropdownMenuItem(value: x, child: Text(surahName(x)))],
                    onChanged: (v) => setS(() {
                      sel = v ?? sel;
                      ay = ayahsIn(sel).last;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    value: ay,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الآية'),
                    items: [for (final x in ayahs) DropdownMenuItem(value: x, child: Text('$x'))],
                    onChanged: (v) => setS(() => ay = v ?? ay),
                  ),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('آخر آية حفظها. إذا أنهى الجزء كاملاً اختر آخر آية فيه.',
                    style: TextStyle(color: ctx.sub, fontSize: 12.5)),
              ),
            ],
            const SizedBox(height: 16),
            NavyButton(text: 'حفظ', onPressed: () => Navigator.pop(ctx, fresh ? 0 : gidOf(sel, ay))),
          ],
        );
      },
    );
    if (res == null) return;
    Repo.I.setProgress(s.id, _halaqaId, res == 0 ? null : res, _sheikhName);
    if (mounted) showSavedTick(context, title: 'تم تحديد البداية', sub: s.name);
  }

  void _logout() {
    Repo.I.setSheikhId(null);
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const GateScreen()), (r) => false);
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
    final holiday = _holidayAll || _holidayHalaqa;
    return Scaffold(
      appBar: AppBar(
        title: const BrandTitle('السجل اليومي'),
        actions: [
          const SettingsButton(),
          TextButton(onPressed: _logout, child: Text('خروج', style: TextStyle(color: context.sub))),
        ],
      ),
      body: Column(children: [
        const OfflineBanner(),
        Expanded(
          child: !_loaded
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  children: [
                    _header(now, doneAll.length, todoAll.length, absent, pending, all.length),
                    if (all.length > 6)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'بحث عن طالب',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() => _q = v.trim()),
                        ),
                      ),
                    if (all.isEmpty)
                      const EmptyState(
                        icon: Icons.groups_rounded,
                        title: 'لا يوجد طلاب في الحلقة',
                        text: 'تضيف الإدارة الطلاب من لوحة الإدارة، وبيظهروا هنا مباشرة.',
                      ),
                    if (all.isNotEmpty && todo.isEmpty && done.isNotEmpty && _q.isEmpty)
                      Panel(
                        color: context.okBg,
                        child: Row(children: [
                          Icon(Icons.check_circle_rounded, color: context.okFg),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('سجّلت كل الطلاب اليوم — بارك الله فيك',
                                style: TextStyle(color: context.okFg, fontWeight: FontWeight.w800)),
                          ),
                        ]),
                      ),
                    if (todo.isNotEmpty) ...[
                      SectionLabel('${holiday ? 'إجازة' : 'لم يُسجّل بعد'} (${todo.length})'),
                      for (final s in todo) _studentRow(s, numbers[s.id] ?? 0),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
                        child: Text(
                            holiday
                                ? 'لا يُحسب غياب اليوم. من يسمّع يُسجَّل له حفظه ومراجعته.'
                                : 'اضغط مطوّلاً على الطالب لتسجيل الغياب',
                            style: TextStyle(fontSize: 12, color: holiday ? context.goldFg : context.sub)),
                      ),
                    ],
                    if (done.isNotEmpty)
                      SectionLabel(
                        'تم التسجيل (${done.length})',
                        trailing: InkWell(
                          onTap: () => setState(() => _showDone = !_showDone),
                          child: Text(_showDone ? 'إخفاء' : 'عرض',
                              style: TextStyle(color: context.accent, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    if (_showDone || _q.isNotEmpty)
                      for (final s in done) _studentRow(s, numbers[s.id] ?? 0),
                    if (todoAll.isNotEmpty && !holiday && _q.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: context.badFg,
                          ),
                          onPressed: () => _markRestAbsent(todoAll),
                          child: Text('تسجيل الباقين غائب (${todoAll.length})'),
                        ),
                      ),
                  ],
                ),
        ),
      ]),
    );
  }

  Widget _studentRow(Student s, int number) {
    final st = _statusOf(s);
    final l = _todayLog(s.id);
    final warn = l == null ? null : _warning(l, st);
    final status = l == null ? null : (l['status'] ?? '').toString();
    final (Color stFg, Color stBg) = switch (status) {
      'recited' => (context.okFg, context.okBg),
      'absent' => (context.badFg, context.badBg),
      'excused' => (context.goldFg, context.goldBg),
      'norecite' => (context.badFg, context.badBg),
      _ => (context.sub, context.field),
    };
    final Color avatar = switch (status) {
      'recited' => okGreen,
      'absent' => const Color(0xFFC0392B),
      'excused' => const Color(0xFFC88A12),
      'norecite' => const Color(0xFFE57373),
      _ => const Color(0xFF9AAAB6),
    };
    final canQuick = l == null && st.mode == 'memorize' && st.fromG != null && st.suggestToG != null;
    String sub = st.title;
    Color subColor = context.sub;
    String? nextLine;
    if (canQuick) {
      nextLine = 'التالي: ${memRangeLabel(s.pathDir, st.fromG!, st.suggestToG!)}';
    } else if (l != null && status == 'recited') {
      sub = _shortSummary(l);
    } else if (l != null) {
      sub = statusText(status);
    }
    if (st.mode == 'review_surah' && l == null) subColor = context.badFg;
    var ready = false;
    if (st.mode == 'review_exam') {
      final r = _readiness(s, _logsOf(s.id));
      ready = r.ok;
      if (l == null) {
        sub += r.ok
            ? ' · جاهز للاختبار ✓'
            : ' · قبل الاختبار: ${st.juzFrom == st.juzTo ? 'تسميع الجزء كاملاً في جلسة' : 'تسميع كل جزء كاملاً'}';
      }
    }
    final prog = l == null ? juzProgress(s.pathDir, st) : null;
    final holiday = _holidayAll || _holidayHalaqa;
    Widget action;
    if (l == null && holiday && st.mode == 'needs_start') {
      action = Tag('إجازة', fg: context.sub, bg: context.field);
    } else if (l != null) {
      action = Tag(statusText(status), fg: stFg, bg: stBg);
    } else if (st.mode == 'needs_start') {
      action = FilledButton.tonal(onPressed: () => _startSheet(s, st), child: const Text('تحديد البداية'));
    } else if (canQuick) {
      action = FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: brandBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(76, 46),
          textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w800),
        ),
        onPressed: () {
          _quickRecite(s, st);
          showSavedTick(context, sub: s.name);
        },
        child: const Text('سمّع'),
      );
    } else {
      action = FilledButton.tonal(
        style: FilledButton.styleFrom(backgroundColor: context.soft, foregroundColor: context.accent),
        onPressed: () => _open(s, st, l),
        child: const Text('تسجيل'),
      );
    }
    return Panel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      onTap: () {
        if (st.mode == 'needs_start' && l == null) {
          _startSheet(s, st);
        } else {
          _open(s, st, l);
        }
      },
      onLongPress: () => _longPress(s, st, l),
      child: Row(
        children: [
          NameAvatar(s.name, color: avatar, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name + (s.pending ? ' (جديد)' : ''),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.ink)),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: sub),
                    if (nextLine != null) const TextSpan(text: ' · '),
                    if (nextLine != null)
                      TextSpan(text: nextLine, style: TextStyle(color: context.accent, fontWeight: FontWeight.w700)),
                  ]),
                  style: TextStyle(color: subColor, fontSize: 12.5, height: 1.5),
                ),
                if (warn != null) Text(warn, style: TextStyle(color: context.goldFg, fontSize: 12)),
                if (l != null && l['_pending'] == true)
                  Text('بانتظار الرفع', style: TextStyle(color: context.goldFg, fontSize: 11.5)),
                if (prog != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 8),
                    child: MiniBar(prog, color: ready ? okGreen : goldButton),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          action,
        ],
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
    final st = dailyStatus(s.pathDir, s.pathStart, passed, before, pr.isEmpty ? null : pr.first, _minNew,
        fromKey: s.pathFrom);
    return DayCtx(st, _todayLog(s.id), _base(s, st), before.take(5).toList(),
        ready: st.mode == 'review_exam' ? _readiness(s, before) : null);
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
  final ExamReady? ready; // شرط الاختبار (قبل تسجيل اليوم)
  DayCtx(this.st, this.todayLog, this.base, this.recent, {this.ready});
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
  bool _showNote = false;

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
    return reviewsCoverRange(_reviews, _st.segFrom!, _st.segTo!);
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

);

  /// نافذة «إضافة مراجعة»
  Future<void> _addReviewSheet() async {
    var kind = 'surah';
    var s = 1, a1 = 1, a2 = qCounts[0], j1 = _st.juz > 0 ? _st.juz : 30, j2 = _st.juz > 0 ? _st.juz : 30;
    final sugg = _suggestedReview;
    bool added(Map<String, dynamic> r) => _reviews.any((x) => x['fromG'] == r['fromG'] && x['toG'] == r['toG']);
    final quick = [
      if (sugg != null && !added(sugg)) MapEntry('المطلوبة: ${sugg['label']}', [sugg]),
      ..._quickReviews,
    ];
    final r = await showAppSheet<List<Map<String, dynamic>>>(
      context,
      title: 'إضافة مراجعة',
      builder: (ctx, setD) {
        Widget quickTile(MapEntry<String, List<Map<String, dynamic>>> q) {
          final p = q.value.fold(0.0, (a, r) => a + ((r['pages'] ?? 0) as num).toDouble());
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: ctx.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: ctx.line)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.pop(ctx, q.value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Expanded(
                        child: Text(q.key, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ctx.ink))),
                    Text('${fmtPages(p)} ص', style: TextStyle(color: ctx.sub, fontSize: 15)),
                  ]),
                ),
              ),
            ),
          );
        }

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
        const kinds = ['surah', 'ayat', 'juz'];
        final pickers = <Widget>[];
        if (kind == 'juz') {
          pickers.addAll([
            Row(children: [
              Expanded(child: juzPick('من الجزء', j1, (x) => j1 = x)),
              const SizedBox(width: 8),
              Expanded(child: juzPick('إلى الجزء', j2, (x) => j2 = x)),
            ]),
          ]);
        } else {
          pickers.add(surahPick());
          if (kind == 'ayat') {
            pickers.addAll([
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: ayahPick('من الآية', a1, (x) => a1 = x)),
                const SizedBox(width: 8),
                Expanded(child: ayahPick('إلى الآية', a2, (x) => a2 = x)),
              ]),
            ]);
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (quick.isNotEmpty) ...[
              Text('سريع', style: TextStyle(color: ctx.sub, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final q in quick) quickTile(q),
              const SizedBox(height: 8),
              Text('أو حدّد', style: TextStyle(color: ctx.sub, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
            ],
            PillChoice(
              items: const ['سورة', 'آيات', 'جزء'],
              selected: kinds.indexOf(kind),
              onChanged: (i) => setD(() => kind = kinds[i]),
            ),
            const SizedBox(height: 12),
            ...pickers,
            const SizedBox(height: 16),
            NavyButton(
              text: 'إضافة',
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
                Navigator.pop(ctx, [
                  {'kind': kind, 'fromG': fromG, 'toG': toG, 'pages': pagesOfRange(fromG, toG), 'label': label}
                ]);
              },
            ),
          ],
        );
      },
    );
    if (r == null) return;
    setState(() {
      for (final x in r) {
        if (!added(x)) _reviews.add(x);
      }
      _ensureNewAfterSurahReview();
    });
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
    showSavedTick(context, sub: widget.student.name);
    final ni = next ? _nextIndex : null;
    if (ni != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => widget.builder(widget.order[ni])));
    } else {
      Navigator.of(context).pop();
    }
  }

  /// شرط الاختبار: تسميع الجزء كاملاً مراجعةً في جلسة واحدة
  Widget _readyBox() {
    final r = _c.ready!;
    final step = _st.step;
    String text;
    var ok = r.ok;
    if (r.ok) {
      text = 'جاهز للاختبار ✓ — سمّع المطلوب كاملاً';
    } else if (step != null && r.reason == 'review') {
      final nowDone = _att == 'recited' &&
          r.missing.any((j) => reviewsCoverRange(_reviews, qJuz[j - 1][0], qJuz[j - 1][1]));
      final left = r.missing
          .where((j) => !(_att == 'recited' && reviewsCoverRange(_reviews, qJuz[j - 1][0], qJuz[j - 1][1])))
          .toList();
      if (left.isEmpty) {
        ok = true;
        text = 'بهذا التسجيل يصبح جاهزاً للاختبار ✓';
      } else {
        text = step.type == 1
            ? 'المطلوب قبل الاختبار: تسميع الجزء ${step.start} كاملاً في جلسة واحدة (زر «الجزء من أوله» في المراجعة)'
            : 'المطلوب قبل الاختبار: تسميع كل جزء كاملاً في جلسة — بقي: ${left.map((j) => 'الجزء $j').join('، ')}';
        if (nowDone) text += '\nهذا التسجيل يُكمل جزءاً منها ✓';
      }
    } else {
      text = step != null ? r.message(step) : '';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: ok ? context.okBg : context.goldBg, borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          style: TextStyle(
              color: ok ? context.okFg : context.goldFg, fontWeight: FontWeight.bold, fontSize: 13.5, height: 1.5)),
    );
  }

  // ---------- عناصر التصميم ----------
  Widget _tagPages(double p, {bool warn = false}) => Tag('${fmtPages(p)} ص',
      fg: warn ? context.goldFg : context.accent, bg: warn ? context.goldBg : context.soft);

  Widget _link(String t, VoidCallback f, {Color? color}) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          haptic();
          f();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Text(t, style: TextStyle(color: color ?? context.accent, fontWeight: FontWeight.w800, fontSize: 14.5)),
        ),
      );

  Widget _box(String text, Color bg, Color fg) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, height: 1.6, fontSize: 13.5)),
      );

  // ---------- السطر العلوي ----------
  Widget _topLine() {
    final pct = juzProgress(_dir, _st);
    final rec = _c.recent;
    Widget dot(String? st) {
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
        margin: const EdgeInsetsDirectional.only(start: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
      );
    }

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
    var title = _st.title;
    if (_st.mode == 'memorize' && _st.fromG != null) title += ' · ${surahName(surahOf(_st.fromG!))}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 12),
      child: Column(children: [
        if (_c.base['holiday'] == true)
          _box('يوم إجازة — التسجيل اختياري ولا يُحسب غياب', context.goldBg, context.goldFg),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _st.mode == 'review_surah' ? context.badFg : context.sub,
                fontSize: 13.5,
                fontWeight: _st.mode == 'review_surah' ? FontWeight.w800 : FontWeight.w500)),
        if (pct != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 8, 40, 0),
            child: MiniBar(pct, height: 7),
          ),
        if (_c.ready != null) Padding(padding: const EdgeInsets.only(top: 10), child: _readyBox()),
        if (rec.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(
                child: Text(lastLine ?? '',
                    overflow: TextOverflow.ellipsis, style: TextStyle(color: context.sub, fontSize: 12)),
              ),
              const SizedBox(width: 4),
              for (final l in rec.reversed) dot(l['status'] as String?),
            ]),
          ),
      ]),
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
            context.goldBg, context.goldFg),
        const SizedBox(height: 8),
        NavyButton(
          text: 'بيبلش الجزء $j من أوله',
          onPressed: () {
            Repo.I.setProgress(widget.student.id, widget.halaqaId, null, widget.sheikhName);
            Navigator.of(context).pop();
            showSavedTick(context, title: 'تم تحديد البداية', sub: widget.student.name);
          },
        ),
        const SizedBox(height: 18),
        Text('أو: آخر آية حفظها', style: TextStyle(color: context.ink, fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 10),
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
        Text('إذا أنهى الجزء كاملاً اختر آخر آية فيه.', style: TextStyle(color: context.sub)),
        const SizedBox(height: 16),
        GoldButton(
          text: 'حفظ نقطة البداية',
          onPressed: () {
            Repo.I.setProgress(widget.student.id, widget.halaqaId, gidOf(s, a), widget.sheikhName);
            Navigator.of(context).pop();
            showSavedTick(context, title: 'تم تحديد البداية', sub: widget.student.name);
          },
        ),
      ],
    );
  }

  // ---------- نافذة «تغيير» الحفظ الجديد ----------
  Future<void> _newMemSheet() async {
    if (_from == null) return;
    _to ??= _toForPages(widget.minNew);
    _hasNew = true;
    setState(() {});
    await showAppSheet<void>(
      context,
      title: 'الحفظ الجديد',
      builder: (ctx, setS) {
        void upd(VoidCallback f) {
          setState(f);
          setS(() {});
        }

        final o = _o;
        final j = _juz;
        final fromPos = o.pos[_from!];
        final surahs = surahsOfJuz(_dir, j).where((s) => _ayahsIn(s, j).any((x) => o.pos[x] >= fromPos)).toList();
        final toS = surahOf(_to!);
        final toAyahs = _ayahsIn(toS, j).where((g) => o.pos[g] >= fromPos).toList();
        final pages = _newPages;
        final idx = toAyahs.indexOf(_to!);
        const chips = [0.5, 1.0, 2.0, 3.0];
        final selChip = chips.indexWhere((v) => (pages - v).abs() < 0.26);
        Widget stepBtn(IconData ic, VoidCallback? f) => IconButton(
              onPressed: f == null
                  ? null
                  : () {
                      haptic();
                      f();
                    },
              icon: Icon(ic, color: f == null ? ctx.line : ctx.ink),
            );
        final p1 = pageOf(_from! < _to! ? _from! : _to!), p2 = pageOf(_from! < _to! ? _to! : _from!);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('من ${posLabel(_from!)}', style: TextStyle(color: ctx.sub, fontSize: 13)),
            const SizedBox(height: 8),
            PillChoice(
              items: const ['½ ص', '1 ص', '2 ص', '3 ص'],
              selected: selChip,
              height: 52,
              fontSize: 16,
              onChanged: (i) => upd(() => _to = _toForPages(chips[i])),
            ),
            const SizedBox(height: 14),
            Text('أو حدّد آخر آية سمّعها', style: TextStyle(color: ctx.sub, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  value: surahs.contains(toS) ? toS : null,
                  isExpanded: true,
                  items: [for (final s in surahs) DropdownMenuItem(value: s, child: Text(surahName(s)))],
                  onChanged: (v) => upd(() {
                    if (v == null) return;
                    _to = _ayahsIn(v, j).where((g) => o.pos[g] >= fromPos).toList().last;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                      color: ctx.field, borderRadius: BorderRadius.circular(14), border: Border.all(color: ctx.line)),
                  child: Row(children: [
                    stepBtn(Icons.add, idx >= 0 && idx < toAyahs.length - 1 ? () => upd(() => _to = toAyahs[idx + 1]) : null),
                    Expanded(
                      child: Text('${ayahNo(_to!)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ctx.ink)),
                    ),
                    stepBtn(Icons.remove, idx > 0 ? () => upd(() => _to = toAyahs[idx - 1]) : null),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(color: ctx.soft, borderRadius: BorderRadius.circular(14)),
              child: Text(
                '${memRangeLabel(_dir, _from!, _to!)} · ${fmtPages(pages)} صفحة  (ص ${p1 == p2 ? '$p1' : '$p1–$p2'})',
                textAlign: TextAlign.center,
                style: TextStyle(color: ctx.accent, fontWeight: FontWeight.w800, fontSize: 15.5),
              ),
            ),
            if (pages < widget.minNew - 1e-9)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('أقل من الحد الأدنى للحفظ (${fmt(widget.minNew)} صفحة)',
                    textAlign: TextAlign.center, style: TextStyle(color: ctx.goldFg, fontSize: 12.5)),
              ),
            const SizedBox(height: 14),
            NavyButton(text: 'تم', onPressed: () => Navigator.pop(ctx)),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () {
                setState(() => _hasNew = false);
                Navigator.pop(ctx);
              },
              child: Text('ما سمّع حفظاً جديداً اليوم', style: TextStyle(color: ctx.badFg, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  // ---------- البطاقة الرئيسية: الحفظ + المراجعة ----------
  Widget _mainCard() {
    final rows = <Widget>[];
    Widget label(String t) =>
        Text(t, style: TextStyle(color: context.sub, fontSize: 13, fontWeight: FontWeight.w700));
    // الحفظ الجديد
    Widget newBody;
    Widget? newAction;
    if (_st.mode == 'review_surah' && !_surahReviewDone) {
      newBody = Text('لازم يراجع ${rangeLabel(_st.segFrom!, _st.segTo!)} كاملة قبل الحفظ الجديد',
          style: TextStyle(color: context.badFg, fontWeight: FontWeight.w700, height: 1.5));
    } else if (_canNew && _from != null) {
      if (_hasNew && _to != null) {
        final pages = _newPages;
        newBody = Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
          Text(memRangeLabel(_dir, _from!, _to!),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.ink)),
          _tagPages(pages, warn: pages < widget.minNew - 1e-9),
        ]);
      } else {
        newBody = Text('ما سمّع حفظاً جديداً', style: TextStyle(color: context.sub, fontSize: 15));
      }
      newAction = _link('تغيير', _newMemSheet);
    } else {
      newBody = Text(
        _st.mode == 'review_exam'
            ? 'لا حفظ جديد — مرحلة المراجعة للاختبار'
            : _st.mode == 'hafiz'
                ? 'حافظ للقرآن — مراجعة فقط'
                : 'لا يوجد حفظ جديد متاح',
        style: TextStyle(color: context.sub, fontSize: 14.5),
      );
    }
    rows.add(Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          label('الحفظ الجديد'),
          const SizedBox(height: 4),
          newBody,
        ]),
      ),
      if (newAction != null) newAction,
    ]));
    rows.add(Divider(height: 26, color: context.line));
    // المراجعة
    final sugg = _suggestedReview;
    bool added(Map<String, dynamic> r) => _reviews.any((x) => x['fromG'] == r['fromG'] && x['toG'] == r['toG']);
    rows.add(Row(children: [
      Expanded(child: label('المراجعة')),
      if (_reviews.isNotEmpty) _tagPages(_reviewPages, warn: _st.isReview && _reviewPages < widget.minReview - 1e-9),
    ]));
    rows.add(const SizedBox(height: 4));
    if (_reviews.isEmpty) {
      rows.add(Text('لا مراجعة بعد', style: TextStyle(color: context.sub, fontSize: 15)));
    }
    for (var i = 0; i < _reviews.length; i++) {
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(
            child: Text('${_reviews[i]['label']}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.ink)),
          ),
          Text('${fmtPages(((_reviews[i]['pages'] ?? 0) as num).toDouble())} ص',
              style: TextStyle(color: context.sub, fontSize: 13)),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'حذف',
            onPressed: () {
              haptic();
              setState(() => _reviews.removeAt(i));
            },
            icon: Icon(Icons.close_rounded, size: 20, color: context.sub),
          ),
        ]),
      ));
    }
    // اقتراحات بضغطة
    final quick = [
      if (sugg != null && !added(sugg)) MapEntry('المطلوبة: ${sugg['label']}', [sugg]),
      for (final q in _quickReviews)
        if (!q.value.every(added)) q,
    ];
    if (quick.isNotEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (final q in quick)
            ActionChip(
              avatar: Icon(Icons.add, size: 18, color: context.accent),
              label: Text(q.key),
              labelStyle: TextStyle(color: context.accent, fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
              backgroundColor: context.soft,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onPressed: () {
                haptic();
                setState(() {
                  for (final r in q.value) {
                    if (!added(r)) _reviews.add(r);
                  }
                  _ensureNewAfterSurahReview();
                });
              },
            ),
        ]),
      ));
    }
    rows.add(Divider(height: 26, color: context.line));
    rows.add(Wrap(alignment: WrapAlignment.start, children: [
      _link('+ إضافة مراجعة', _addReviewSheet),
      if (!_showNote && _notes.text.isEmpty)
        _link('+ ملاحظة', () => setState(() => _showNote = true)),
    ]));
    if (_showNote || _notes.text.isNotEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: TextField(
          controller: _notes,
          decoration: const InputDecoration(hintText: 'ملاحظة (اختياري)', isDense: true),
        ),
      ));
    }
    return Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows));
  }

  List<String> get _warnings {
    final w = <String>[];
    if (_att != 'recited' || _c.base['holiday'] == true) return w;
    if (_hasNew && _canNew && _from != null && _newPages < widget.minNew - 1e-9) {
      w.add('الحفظ أقل من ${fmt(widget.minNew)} صفحة');
    }
    if (_st.isReview && _reviewPages < widget.minReview - 1e-9) w.add('المراجعة أقل من ${fmt(widget.minReview)} صفحات');
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final idx = widget.order.indexWhere((x) => x.id == s.id);
    final counter = idx >= 0 ? '${idx + 1} من ${widget.order.length}' : '';
    final appBar = AppBar(
      title: BrandTitle(s.name),
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 14),
          child: Center(child: Text(counter, style: TextStyle(color: context.sub, fontSize: 13))),
        ),
      ],
    );
    if (_st.mode == 'needs_start') {
      return Scaffold(appBar: appBar, body: _startPointView());
    }
    const atts = ['recited', 'norecite', 'absent', 'excused'];
    final ai = atts.indexOf(_att);
    final recited = _att == 'recited';
    final hasNext = _nextIndex != null;
    final summary = recited
        ? [
            if (_hasNew && _canNew && _from != null && _to != null) 'سمّع ${fmtPages(_newPages)} ص',
            'راجع ${fmtPages(_reviewPages)} ص',
          ].join(' · ')
        : SheikhHomeScreenStateText.of(_att);
    final warns = _warnings;
    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        children: [
          _topLine(),
          PillChoice(
            items: [ai == 0 ? '✓ سمّع' : 'سمّع', 'لم يسمّع', 'غائب', 'بعذر'],
            selected: ai,
            height: 50,
            fontSize: 15,
            onChanged: (i) => setState(() => _att = atts[i]),
          ),
          const SizedBox(height: 12),
          if (recited)
            _mainCard()
          else
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('سيُسجَّل: ${SheikhHomeScreenStateText.of(_att)}',
                    style: TextStyle(color: context.ink, fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 10),
                TextField(
                  controller: _notes,
                  decoration: const InputDecoration(hintText: 'ملاحظة (اختياري)', isDense: true),
                ),
              ]),
            ),
          for (final w in warns) _box(w, context.goldBg, context.goldFg),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          decoration: BoxDecoration(
            color: context.surface,
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, -2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(summary, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: context.sub)),
              const SizedBox(height: 6),
              GoldButton(
                text: hasNext ? 'حفظ والتالي ←' : 'حفظ',
                onPressed: () => _save(next: hasNext),
              ),
              if (hasNext)
                TextButton(
                  onPressed: () => _save(),
                  child: Text('حفظ فقط', style: TextStyle(color: context.accent, fontWeight: FontWeight.w800)),
                )
              else
                const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// نسبة إنجاز الجزء الحالي (للشريط الصغير)
double? juzProgress(String dir, DailyStatus st) {
  if (st.mode == 'review_exam') return st.juzFrom == st.juzTo ? 1.0 : null;
  final j = st.juz;
  if (j <= 0) return null;
  final o = memOrder(dir);
  int? cp;
  if (st.mode == 'memorize' && st.fromG != null) cp = o.pos[st.fromG!] - 1;
  if (st.mode == 'review_surah' && st.segTo != null) cp = o.pos[st.segTo!];
  if (cp == null) return null;
  final js = o.jStart[j];
  var done = 0.0;
  for (var i = js; i <= cp; i++) {
    done += ayahFrac(o.order[i]);
  }
  final total = pagesOfRange(qJuz[j - 1][0], qJuz[j - 1][1]);
  return total == 0 ? 0 : (done / total).clamp(0.0, 1.0);
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
