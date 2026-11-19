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

int juzOfG(int g) {
  for (var j = 1; j <= 30; j++) {
    if (g >= qJuz[j - 1][0] && g <= qJuz[j - 1][1]) return j;
  }
  return 30;
}

/// جزء السورة داخل الجزء الواحد [من، إلى]
List<int> segmentOf(int g) {
  final j = juzOfG(g), s = surahOf(g);
  final a = qJuz[j - 1][0], b = qJuz[j - 1][1];
  return [a > surahFirst(s) ? a : surahFirst(s), b < surahEnd(s) ? b : surahEnd(s)];
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

/// ترتيب الحفظ: من البقرة = ترتيب المصحف، من الناس = السور تنازلياً وكل سورة من أولها
MemOrder memOrder(String dir) {
  final cached = _orders[dir];
  if (cached != null) return cached;
  final order = <int>[];
  if (dir == 'asc') {
    for (var g = 1; g <= nAyah; g++) {
      order.add(g);
    }
  } else {
    for (var j = 30; j >= 1; j--) {
      final a = qJuz[j - 1][0], b = qJuz[j - 1][1];
      final sa = surahOf(a), sb = surahOf(b);
      for (var s = sb; s >= sa; s--) {
        final lo = a > surahFirst(s) ? a : surahFirst(s);
        final hi = b < surahEnd(s) ? b : surahEnd(s);
        for (var g = lo; g <= hi; g++) {
          order.add(g);
        }
      }
    }
  }
  final pos = List<int>.filled(nAyah + 1, 0);
  for (var i = 0; i < order.length; i++) {
    pos[order[i]] = i;
  }
  final jStart = List<int>.filled(31, 0), jEnd = List<int>.filled(31, 0);
  for (var j = 1; j <= 30; j++) {
    var mn = 1 << 30, mx = -1;
    for (var g = qJuz[j - 1][0]; g <= qJuz[j - 1][1]; g++) {
      if (pos[g] < mn) mn = pos[g];
      if (pos[g] > mx) mx = pos[g];
    }
    jStart[j] = mn;
    jEnd[j] = mx;
  }
  final o = MemOrder(order, pos, jStart, jEnd);
  _orders[dir] = o;
  return o;
}

double memRangePages(String dir, int fromG, int toG) {
  final o = memOrder(dir);
  var t = 0.0;
  for (var i = o.pos[fromG]; i <= o.pos[toG]; i++) {
    t += ayahFrac(o.order[i]);
  }
  return t;
}

String memRangeLabel(String dir, int fromG, int toG) {
  if (dir == 'asc') return rangeLabel(fromG, toG);
  final o = memOrder(dir);
  final a = o.pos[fromG], b = o.pos[toG];
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

/// السور الموجودة في الجزء بترتيب الحفظ
List<int> surahsOfJuz(String dir, int j) {
  final a = qJuz[j - 1][0], b = qJuz[j - 1][1];
  final list = <int>[for (var s = surahOf(a); s <= surahOf(b); s++) s];
  return dir == 'asc' ? list : list.reversed.toList();
}

class DailyStatus {
  /// memorize | review_exam | review_surah | needs_start | hafiz
  final String mode;
  final PathStep? step;
  final int juz, juzFrom, juzTo;
  final int? fromG, suggestToG, juzEndG, segFrom, segTo;
  final bool ready;
  DailyStatus(this.mode,
      {this.step,
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
        return juzFrom == juzTo ? 'مراجعة: الجزء $juzFrom (للاختبار)' : 'مراجعة: الأجزاء $juzFrom–$juzTo (للاختبار)';
      default:
        return 'حفظ: الجزء $juz';
    }
  }

  bool get isReview => mode == 'review_exam' || mode == 'review_surah' || mode == 'hafiz';
}

int? _int(dynamic v) => v is num ? v.toInt() : null;

DailyStatus dailyStatus(String dir, int start, Set<String> passedKeys, List<Map<String, dynamic>> logs,
    Map<String, dynamic>? progress, double minNew) {
  final o = memOrder(dir);
  final step = nextPathStep(dir, start, passedKeys);
  if (step == null) return DailyStatus('hafiz');
  if (step.type > 1) return DailyStatus('review_exam', step: step, juzFrom: step.start, juzTo: step.end);
  final j = step.start;
  int? cursor;
  var hasData = false;
  if (progress != null) {
    hasData = true;
    final lg = _int(progress['lastG']);
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
  if (!hasData) return DailyStatus('needs_start', step: step, juz: j);
  if (cursor != null && cursor >= o.jEnd[j]) {
    return DailyStatus('review_exam', step: step, juz: j, juzFrom: j, juzTo: j, ready: true);
  }
  if (cursor == null || cursor < o.jStart[j] - 1) cursor = o.jStart[j] - 1;
  if (cursor >= o.jStart[j]) {
    final seg = segmentOf(o.order[cursor]);
    final sa = seg[0], sb = seg[1];
    if (cursor == o.pos[sb]) {
      final ps = o.pos[sa], pe = o.pos[sb];
      final touching = logs.where((l) {
        final nm = l['newMem'];
        if (nm is! Map || _int(nm['fromG']) == null || _int(nm['toG']) == null) return false;
        return o.pos[_int(nm['fromG'])!] <= pe && o.pos[_int(nm['toG'])!] >= ps;
      }).toList();
      if (touching.length >= 2) {
        final dates = touching.map((l) => (l['date'] ?? '').toString()).toList()..sort();
        final doneDate = dates.last;
        final reviewed = logs.any((l) =>
            (l['date'] ?? '').toString().compareTo(doneDate) >= 0 &&
            ((l['reviews'] as List?) ?? []).any((r) =>
                r is Map && (_int(r['fromG']) ?? 1 << 30) <= sa && (_int(r['toG']) ?? -1) >= sb));
        if (!reviewed) return DailyStatus('review_surah', step: step, juz: j, segFrom: sa, segTo: sb);
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
      step: step, juz: j, fromG: o.order[fromPos], suggestToG: o.order[toPos], juzEndG: o.order[o.jEnd[j]]);
}

/// التاريخ بصيغة yyyy-MM-dd
String dayKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// يوم الأسبوع بترقيم جافاسكربت (الأحد 0 ... السبت 6) لمطابقة إعدادات اللوحة
int jsDay(DateTime d) => d.weekday % 7;
