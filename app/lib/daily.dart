import 'dart:math';
import 'logic.dart';
import 'quran_data.dart';

// ===== محرك السجل اليومي (مطابق لمنطق لوحة الإدارة) =====
const int nAyah = 6236;

final List<int> _surahStart = () {
  final s = <int>[0];
  var g = 1;
  for (final c in qCounts) {
    s.add(g);
    g += c;
  }
  return s;
}();

int surahOf(int g) {
  var lo = 1, hi = 114;
  while (lo < hi) {
    final m = (lo + hi + 1) >> 1;
    if (_surahStart[m] <= g) {
      lo = m;
    } else {
      hi = m - 1;
    }
  }
  return lo;
}

int ayahNo(int g) => g - _surahStart[surahOf(g)] + 1;
int gidOf(int s, int a) => _surahStart[s] + a - 1;
int surahFirst(int s) => _surahStart[s];
int surahEnd(int s) => _surahStart[s] + qCounts[s - 1] - 1;
String surahName(int s) => qNames[s - 1];

int pageOf(int g) {
  var lo = 1, hi = 604;
  while (lo < hi) {
    final m = (lo + hi + 1) >> 1;
    if (qPageStart[m - 1] <= g) {
      lo = m;
    } else {
      hi = m - 1;
    }
  }
  return lo;
}

double ayahFrac(int g) {
  final p = pageOf(g);
  return 1 / (qPageStart[p] - qPageStart[p - 1]);
}

double pagesOfRange(int a, int b) {
  var t = 0.0;
  for (var g = a; g <= b; g++) {
    t += ayahFrac(g);
  }
  return t;
}

/// رقم وحدة الحفظ (الجزء حسب خطة المركز) التي فيها الآية
int juzOfG(String dir, int g) => unitAt(dir, g).n1;

/// جزء السورة داخل وحدة الحفظ [من، إلى]
List<int> segmentOf(String dir, int g) {
  final u = unitAt(dir, g), s = surahOf(g);
  return [u.a > surahFirst(s) ? u.a : surahFirst(s), u.b < surahEnd(s) ? u.b : surahEnd(s)];
}

String posLabel(int g) => '${surahName(surahOf(g))} ${ayahNo(g)}';

String rangeLabel(int a, int b) {
  final sa = surahOf(a), sb = surahOf(b);
  if (sa == sb) {
    if (a == surahFirst(sa) && b == surahEnd(sa)) return 'سورة ${surahName(sa)}';
    return '${surahName(sa)} ${ayahNo(a)}–${ayahNo(b)}';
  }
  return '${posLabel(a)} ← ${posLabel(b)}';
}

String fmtPages(double p) => p.toStringAsFixed(1);

class MemOrder {
  final List<int> order;
  final List<int> pos;
  final List<int> jStart, jEnd;
  MemOrder(this.order, this.pos, this.jStart, this.jEnd);
}

final Map<String, MemOrder> _orders = {};

/// سورة البداية في كل جزء: 'first' = أول سورة فيه بترتيب المصحف، 'last' = آخر سورة
typedef JuzOrd = Map<int, String>;

String juzStartDefault(String dir) => dir == 'asc' ? 'first' : 'last';

/// المفتاح: رقم أول جزء في الوحدة
int juzOrdKey(String dir, int j) => unitOf(dir, j).n1;

String juzStartOf(String dir, int j, JuzOrd ord) => ord[juzOrdKey(dir, j)] ?? juzStartDefault(dir);

/// اختيارات سورة البداية المحفوظة في مستند progress
JuzOrd juzOrdOf(Map<String, dynamic>? progress) {
  final m = progress?['juzOrder'];
  if (m is! Map) return const {};
  final r = <int, String>{};
  m.forEach((k, v) {
    final n = int.tryParse('$k');
    if (n != null && (v == 'first' || v == 'last')) r[n] = v as String;
  });
  return r;
}

/// هل للجزء أكثر من سورة (يظهر خيار سورة البداية)
bool juzHasChoice(String dir, int j) {
  final u = unitOf(dir, j);
  return surahOf(u.a) != surahOf(u.b);
}

/// اسم سورة البداية لاختيار معيّن
String juzStartSurahName(String dir, int j, String start) {
  final u = unitOf(dir, j);
  return surahName(start == 'first' ? surahOf(u.a) : surahOf(u.b));
}

/// ترتيب الحفظ: من البقرة = الوحدات بترتيب المصحف، من الناس = الوحدات تنازلياً.
/// داخل كل وحدة السور حسب سورة البداية (الافتراضي: تنازلياً لمن الناس، تصاعدياً لمن البقرة)، وكل سورة من أولها
MemOrder memOrder(String dir, [JuzOrd ord = const {}]) {
  final d = dir == 'asc' ? 'asc' : 'desc';
  final units = unitsOf(d);
  final over = <int, String>{};
  for (final u in units) {
    final v = ord[u.n1];
    if (v != null && v != juzStartDefault(d)) over[u.n1] = v;
  }
  final key = over.isEmpty ? d : '$d|${(over.keys.toList()..sort()).map((k) => '$k${over[k]![0]}').join(',')}';
  final cached = _orders[key];
  if (cached != null) return cached;
  final order = <int>[];
  final seq = d == 'asc' ? units : units.reversed;
  for (final u in seq) {
    final sa = surahOf(u.a), sb = surahOf(u.b);
    final first = (over[u.n1] ?? juzStartDefault(d)) == 'first';
    for (var k = 0; k <= sb - sa; k++) {
      final s = first ? sa + k : sb - k;
      final lo = u.a > surahFirst(s) ? u.a : surahFirst(s);
      final hi = u.b < surahEnd(s) ? u.b : surahEnd(s);
      for (var g = lo; g <= hi; g++) {
        order.add(g);
      }
    }
  }
  final pos = List<int>.filled(nAyah + 1, 0);
  for (var i = 0; i < order.length; i++) {
    pos[order[i]] = i;
  }
  final jStart = List<int>.filled(31, 0), jEnd = List<int>.filled(31, 0);
  for (final u in units) {
    var mn = 1 << 30, mx = -1;
    for (var g = u.a; g <= u.b; g++) {
      if (pos[g] < mn) mn = pos[g];
      if (pos[g] > mx) mx = pos[g];
    }
    for (var n = u.n1; n <= u.n2; n++) {
      jStart[n] = mn;
      jEnd[n] = mx;
    }
  }
  final o = MemOrder(order, pos, jStart, jEnd);
  _orders[key] = o;
  return o;
}

double memRangePages(String dir, int fromG, int toG, [JuzOrd ord = const {}]) {
  final o = memOrder(dir, ord);
  var t = 0.0;
  for (var i = o.pos[fromG]; i <= o.pos[toG]; i++) {
    t += ayahFrac(o.order[i]);
  }
  return t;
}

String memRangeLabel(String dir, int fromG, int toG, [JuzOrd ord = const {}]) {
  final o = memOrder(dir, ord);
  final a = o.pos[fromG], b = o.pos[toG];
  // متصل بترتيب المصحف (مثل من البقرة) ← صيغة المدى المعتادة
  if (dir == 'asc' && toG - fromG == b - a) return rangeLabel(fromG, toG);
  final parts = <String>[];
  var i = a;
  while (i <= b) {
    final s = surahOf(o.order[i]);
    var j = i;
    while (j + 1 <= b && surahOf(o.order[j + 1]) == s) {
      j++;
    }
    parts.add(rangeLabel(o.order[i], o.order[j]));
    i = j + 1;
  }
  return parts.join('، ');
}

/// السور الموجودة في وحدة الحفظ بترتيب الحفظ
List<int> surahsOfJuz(String dir, int j, [JuzOrd ord = const {}]) {
  final u = unitOf(dir, j);
  final list = <int>[for (var s = surahOf(u.a); s <= surahOf(u.b); s++) s];
  return juzStartOf(dir, j, ord) == 'first' ? list : list.reversed.toList();
}

/// مدى الوحدة [a, b]
List<int> unitRange(String dir, int j) {
  final u = unitOf(dir, j);
  return [u.a, u.b];
}

class DailyStatus {
  /// memorize | review_exam | review_surah | needs_start | hafiz
  final String mode;
  final PathStep? step;
  final int juz, juzFrom, juzTo;
  final int? fromG, suggestToG, juzEndG, segFrom, segTo;
  final bool ready;
  final JuzOrd ord;
  DailyStatus(this.mode,
      {this.ord = const {},
      this.step,
      this.juz = 0,
      this.juzFrom = 0,
      this.juzTo = 0,
      this.fromG,
      this.suggestToG,
      this.juzEndG,
      this.segFrom,
      this.segTo,
      this.ready = false});

  String get title {
    switch (mode) {
      case 'hafiz':
        return 'حافظ للقرآن الكريم';
      case 'needs_start':
        return 'يحتاج تحديد نقطة البداية';
      case 'review_surah':
        return 'مراجعة سورة ${rangeLabel(segFrom!, segTo!).replaceFirst('سورة ', '')} كاملة (إجباري)';
      case 'review_exam':
        if (step?.type == 30) return 'مراجعة المصحف كاملاً للاختبار';
        return (step?.type ?? 1) == 1
            ? 'مراجعة الجزء ${unitNum(step?.dir ?? 'desc', juzFrom)} للاختبار'
            : 'مراجعة ${examTypes[step!.type]} (${step!.start}–${step!.end}) للاختبار';
      default:
        return 'في الجزء ${unitNum(step?.dir ?? 'desc', juz)}';
    }
  }

  /// لم يُحفظ شيء من الجزء الحالي بعد (يمكن اختيار سورة البداية)
  bool get juzNotStarted => mode == 'memorize' && fromG != null && step != null && fromG == memOrder(step!.dir, ord).order[memOrder(step!.dir, ord).jStart[juz]];

  bool get isReview => mode == 'review_exam' || mode == 'review_surah' || mode == 'hafiz';
}

int? _int(dynamic v) => v is num ? v.toInt() : null;

/// مستند progress فيه نقطة بداية فعلية (وليس اختيار سورة البداية فقط)
bool _hasStart(Map<String, dynamic>? p) => p != null && (p.containsKey('lastG') || p.containsKey('fresh'));

DailyStatus dailyStatus(String dir, int start, Set<String> passedKeys, List<Map<String, dynamic>> logs,
    Map<String, dynamic>? progress, double minNew, {String? fromKey}) {
  final ord = juzOrdOf(progress);
  final o = memOrder(dir, ord);
  final step = nextPathStep(dir, start, passedKeys, fromKey);
  if (step == null) return DailyStatus('hafiz', ord: ord);
  if (step.type > 1) return DailyStatus('review_exam', ord: ord, step: step, juzFrom: step.start, juzTo: step.end);
  final j = step.start;
  int? cursor;
  var hasData = false;
  if (_hasStart(progress)) {
    hasData = true;
    final lg = _int(progress!['lastG']);
    if (lg != null && lg >= 1 && lg <= nAyah) cursor = o.pos[lg];
  }
  for (final l in logs) {
    final nm = l['newMem'];
    if (nm is Map && _int(nm['toG']) != null) {
      hasData = true;
      final c = o.pos[_int(nm['toG'])!];
      if (cursor == null || c > cursor) cursor = c;
    }
  }
  if (!hasData) return DailyStatus('needs_start', ord: ord, step: step, juz: j);
  if (cursor != null && cursor >= o.jEnd[j]) {
    return DailyStatus('review_exam', ord: ord, step: step, juz: j, juzFrom: j, juzTo: j, ready: true);
  }
  if (cursor == null || cursor < o.jStart[j] - 1) cursor = o.jStart[j] - 1;
  if (cursor >= o.jStart[j]) {
    final seg = segmentOf(dir, o.order[cursor]);
    final sa = seg[0], sb = seg[1];
    if (cursor == o.pos[sb]) {
      final ps = o.pos[sa], pe = o.pos[sb];
      final touching = logs.where((l) {
        final nm = l['newMem'];
        if (nm is! Map || _int(nm['fromG']) == null || _int(nm['toG']) == null) return false;
        return o.pos[_int(nm['fromG'])!] <= pe && o.pos[_int(nm['toG'])!] >= ps;
      }).toList();
      // جزء من السورة حُفظ قبل السجل (نقطة البداية داخلها أو عند آخرها) ← تُعدّ مقطّعة
      final lg = progress == null ? null : _int(progress['lastG']);
      final pre = lg != null && lg >= 1 && lg <= nAyah && o.pos[lg] >= ps && o.pos[lg] <= pe;
      // سُمّعت على دفعات بنفس الجلسة (يحددها الشيخ)
      final split = touching.any((l) => l['newMem'] is Map && (l['newMem'] as Map)['split'] == true);
      if (touching.length >= 2 || pre || split) {
        final dates = touching.map((l) => (l['date'] ?? '').toString()).toList()..sort();
        final doneDate = dates.isEmpty ? '' : dates.last;
        // كاملة في جلسة واحدة: مراجعات نفس الجلسة مجتمعةً تغطي السورة
        final reviewed = logs.any((l) =>
            (l['date'] ?? '').toString().compareTo(doneDate) >= 0 && reviewsCoverRange(l['reviews'], sa, sb));
        if (!reviewed) return DailyStatus('review_surah', ord: ord, step: step, juz: j, segFrom: sa, segTo: sb);
      }
    }
  }
  final fromPos = cursor + 1;
  var t = 0.0;
  var toPos = fromPos;
  for (var i = fromPos; i <= o.jEnd[j]; i++) {
    t += ayahFrac(o.order[i]);
    toPos = i;
    if (t >= minNew - 1e-9) break;
  }
  return DailyStatus('memorize',
      ord: ord, step: step, juz: j, fromG: o.order[fromPos], suggestToG: o.order[toPos], juzEndG: o.order[o.jEnd[j]]);
}

/// التاريخ بصيغة yyyy-MM-dd
String dayKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// يوم الأسبوع بترقيم جافاسكربت (الأحد 0 ... السبت 6) لمطابقة إعدادات اللوحة
int jsDay(DateTime d) => d.weekday % 7;


// ===================== شرط الاختبار من السجل اليومي =====================
/// الشرط: أتمّ حفظ الجزء، ثم سمّعه كاملاً مراجعةً في جلسة واحدة (بعد آخر اختبار له).
/// للتجميعي: كل جزء من أجزائه مُسمَّع كاملاً في جلسة (يجوز في جلسات مختلفة).
class ExamReady {
  final bool ok;
  final String reason; // ok / needs_start / memorizing / review
  final List<int> missing; // أجزاء لم تُسمَّع كاملة
  const ExamReady(this.ok, this.reason, [this.missing = const []]);

  String message(PathStep step) {
    switch (reason) {
      case 'ok':
        return 'جاهز للاختبار: سمّع المطلوب كاملاً في السجل اليومي';
      case 'needs_start':
        return 'لم تُحدَّد نقطة بدايته في السجل اليومي — يحددها الشيخ ثم يُسمّعه الجزء كاملاً';
      case 'memorizing':
        return 'ما زال يحفظ الجزء ${unitNum(step.dir, step.start)} — لم يُتمّ حفظه في السجل اليومي';
      default:
        if (step.type == 1) return 'لم يُسمِّع الجزء ${unitNum(step.dir, step.start)} كاملاً في جلسة واحدة بعد إتمام حفظه';
        return 'لم يُسمِّع كاملاً بعد: ${missing.map((j) => 'الجزء ${unitNum(step.dir, j)}').join('، ')}';
    }
  }
}

bool reviewsCoverRange(dynamic reviews, int a, int b) {
  if (reviews is! List) return false;
  final iv = <List<int>>[];
  for (final r in reviews) {
    if (r is! Map) continue;
    final f = _int(r['fromG']), t = _int(r['toG']);
    if (f == null || t == null) continue;
    iv.add([min(f, t), max(f, t)]);
  }
  iv.sort((x, y) => x[0].compareTo(y[0]));
  var cur = a;
  for (final x in iv) {
    if (x[0] > cur) break;
    if (x[1] + 1 > cur) cur = x[1] + 1;
    if (cur > b) return true;
  }
  return cur > b;
}

ExamReady examReadiness(String dir, int start, Set<String> passedKeys, List<Map<String, dynamic>> logs,
    Map<String, dynamic>? progress, String lastExamDate, {String? fromKey}) {
  final step = nextPathStep(dir, start, passedKeys, fromKey);
  if (step == null) return const ExamReady(true, 'ok');
  final o = memOrder(dir, juzOrdOf(progress));
  var since = lastExamDate;
  if (step.type == 1) {
    final j = step.start;
    int? cursor;
    var hasData = _hasStart(progress);
    if (hasData) {
      final lg = _int(progress!['lastG']);
      if (lg != null && lg >= 1 && lg <= nAyah) cursor = o.pos[lg];
    }
    var doneDate = '';
    for (final l in logs) {
      final nm = l['newMem'];
      final tg = nm is Map ? _int(nm['toG']) : null;
      if (tg == null) continue;
      hasData = true;
      final c = o.pos[tg];
      if (cursor == null || c > cursor) cursor = c;
      if (c >= o.jStart[j] && c <= o.jEnd[j]) {
        final d = (l['date'] ?? '').toString();
        if (d.compareTo(doneDate) > 0) doneDate = d;
      }
    }
    if (!hasData) return const ExamReady(false, 'needs_start');
    if (cursor == null || cursor < o.jEnd[j]) return const ExamReady(false, 'memorizing');
    if (doneDate.compareTo(since) > 0) since = doneDate;
  }
  final missing = <int>[];
  for (final j in step.units) {
    final r = unitRange(dir, j);
    final a = r[0], b = r[1];
    final done = logs.any((l) =>
        (l['date'] ?? '').toString().compareTo(since) >= 0 && l['status'] == 'recited' && reviewsCoverRange(l['reviews'], a, b));
    if (!done) missing.add(j);
  }
  return missing.isEmpty ? const ExamReady(true, 'ok') : ExamReady(false, 'review', missing);
}


// ===================== مهلة المراجعة قبل الاختبار =====================
/// بداية مهلة المراجعة (yyyy-MM-dd) أو null إذا لا توجد مهلة الآن.
/// المفرد: من يوم إتمام حفظ الجزء. المجمّع: من يوم آخر اختبار نجح فيه.
String? reviewSince(String dir, DailyStatus st, List<Map<String, dynamic>> logs, String lastPassDate) {
  if (st.mode != 'review_exam' || st.step == null) return null;
  final step = st.step!;
  if (step.type > 1) return lastPassDate.isEmpty ? null : lastPassDate;
  final o = memOrder(dir, st.ord);
  final end = o.jEnd[step.start];
  final sorted = [...logs]..sort((a, b) => (a['date'] ?? '').toString().compareTo((b['date'] ?? '').toString()));
  for (final l in sorted) {
    final nm = l['newMem'];
    final tg = nm is Map ? _int(nm['toG']) : null;
    if (tg != null && o.pos[tg] >= end) return (l['date'] ?? '').toString();
  }
  return lastPassDate.isEmpty ? null : lastPassDate;
}

/// الأيام المتبقية من المهلة (سالب = متجاوز)، أو null
int? reviewDaysLeft(String dir, DailyStatus st, List<Map<String, dynamic>> logs, String lastPassDate) {
  final since = reviewSince(dir, st, logs, lastPassDate);
  if (since == null || since.isEmpty) return null;
  final d = DateTime.tryParse(since);
  if (d == null) return null;
  final n = DateTime.now();
  final days = DateTime(n.year, n.month, n.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  return st.step!.reviewDays - days;
}

String reviewDeadlineText(int left, int total) {
  if (left < 0) return 'تجاوز مهلة المراجعة بـ ${-left} ${-left == 1 ? 'يوم' : (-left == 2 ? 'يومين' : 'أيام')}';
  if (left == 0) return 'مهلة المراجعة: اليوم آخر يوم';
  final per = total == 7 ? 'أسبوع' : (total == 30 ? 'شهر' : 'شهرين');
  final l = left == 1 ? 'يوم' : (left == 2 ? 'يومين' : '$left أيام');
  return 'مهلة المراجعة: باقي $l من $per';
}


// ===================== المطلوب للجلسة القادمة =====================
class NextPlan {
  final String mem; // الحفظ
  final String review; // المراجعة ('' = لا مراجعة مطلوبة)
  final String short; // سطر مختصر للقائمة
  const NextPlan(this.mem, this.review, this.short);
}

/// المطلوب للجلسة القادمة من حالة الطالب بعد تسجيل اليوم
NextPlan? nextPlan(String dir, DailyStatus n, double minReview) {
  switch (n.mode) {
    case 'memorize':
      if (n.fromG == null || n.suggestToG == null) return null;
      final m = '${memRangeLabel(dir, n.fromG!, n.suggestToG!, n.ord)} '
          '(${fmtPages(memRangePages(dir, n.fromG!, n.suggestToG!, n.ord))} ص)';
      // مرحلة الحفظ: لا مراجعة مطلوبة حسب الخطة
      return NextPlan(m, '', 'القادم: ${memRangeLabel(dir, n.fromG!, n.suggestToG!, n.ord)}');
    case 'review_surah':
      final sur = rangeLabel(n.segFrom!, n.segTo!);
      return NextPlan('بعد مراجعة السورة كاملة', '$sur كاملة (إجباري)', 'القادم: مراجعة $sur كاملة');
    case 'review_exam':
      return NextPlan('لا حفظ جديد — مرحلة المراجعة للاختبار', n.title, 'القادم: ${n.title}');
    case 'hafiz':
      return const NextPlan('', 'مراجعة', 'حافظ — مراجعة');
    default:
      return null;
  }
}


/// هل يُسأل الشيخ «كيف سمّع السورة؟»: الحفظ يُكمل سورة كاملة (أو جزءها في الوحدة) أكبر من حد الحفظ اليومي
List<int>? splitQuestionSeg(String dir, int fromG, int toG, double minNew, [JuzOrd ord = const {}]) {
  final o = memOrder(dir, ord);
  final seg = segmentOf(dir, toG);
  final sa = seg[0], sb = seg[1];
  if (toG != sb) return null; // لا يُكمل السورة
  if (o.pos[fromG] > o.pos[sa]) return null; // جزء منها قبل اليوم (يُعالَج تلقائياً)
  if (pagesOfRange(sa, sb) <= 1 + 1e-9) return null; // سورة قصيرة (صفحة أو أقل)
  return seg;
}
