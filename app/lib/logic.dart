import 'dart:math';

import 'quran_data.dart';

const centerName = 'مركز التقوى لتعليم وتحفيظ القرآن الكريم';
const ayahText = 'وَلَقَدْ يَسَّرْنَا الْقُرْآنَ لِلذِّكْرِ فَهَلْ مِن مُّدَّكِرٍ';

/// اسم كل جزء حسب خطة المركز (من الناس): من أي سورة لأي سورة
final List<String> juzNames = [for (var n = 0; n <= 30; n++) n == 0 ? '' : unitDesc('desc', n)];

/// عدد الأجزاء => اسم نوع الاختبار
const examTypes = <int, String>{
  1: 'اختبار جزء',
  3: 'اختبار 3 أجزاء',
  5: 'اختبار 5 أجزاء',
  10: 'اختبار 10 أجزاء',
  30: 'اختبار 30 جزءًا',
};

const int qCount = 5;
const double qMax = 15;
const double tajweedMax = 20;
const double perfMax = 5;
const double passMark = 85;
const double closeAt = 9; // خصم 9 علامات في سؤال واحد يغلق الاختبار
const double errVal = 1;
const double alertVal = 0.5;


class QuestionMark {
  int errors = 0;
  int alerts = 0;
  double get deduction => errors * errVal + alerts * alertVal;
  double get score => max(0.0, qMax - deduction);
  Map<String, dynamic> toMap() =>
      {'errors': errors, 'alerts': alerts, 'deduction': deduction, 'score': score};
}

class ExamSetup {
  final String halaqaId, halaqaName, studentId, studentName;
  final int type, startJuz, endJuz;
  final bool isRetest;
  final DateTime createdAt;
  final String dir;
  ExamSetup({
    this.dir = 'desc',
    required this.halaqaId,
    required this.halaqaName,
    required this.studentId,
    required this.studentName,
    required this.type,
    required this.startJuz,
    required this.endJuz,
    required this.isRetest,
    required this.createdAt,
  });
}

/// يقبل الأرقام العربية والإنجليزية والفاصلة العشرية
double? parseNum(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  var t = s.trim();
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(ar[i], '$i');
  }
  t = t.replaceAll('٫', '.').replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

String fmt(num? n) {
  if (n == null) return '';
  if (n == n.roundToDouble()) return n.toInt().toString();
  return n.toStringAsFixed(1);
}

const _days = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
String dayName(DateTime d) => _days[d.weekday - 1];
String two(int n) => n.toString().padLeft(2, '0');
String dateText(DateTime d) =>
    '${dayName(d)} ${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';

String fmtDuration(int seconds) {
  final m = seconds ~/ 60, sec = seconds % 60;
  if (m >= 60) return '${m ~/ 60}:${two(m % 60)}:${two(sec)}';
  return '${two(m)}:${two(sec)}';
}

// ===== مسار الحفظ (خطة المركز) =====
const pathDirs = <String, String>{'desc': 'من الناس (30 ← 1)', 'asc': 'من البقرة (1 ← 30)'};

// ----- وحدات الحفظ: كل "جزء" في خطة المركز سور كاملة -----
final List<int> _sStart = () {
  final s = <int>[0];
  var g = 1;
  for (final c in qCounts) {
    s.add(g);
    g += c;
  }
  return s;
}();
int _sFirst(int s) => _sStart[s];
int _sLast(int s) => _sStart[s] + qCounts[s - 1] - 1;
int _surahAt(int g) {
  var lo = 1, hi = 114;
  while (lo < hi) {
    final m = (lo + hi + 1) >> 1;
    if (_sStart[m] <= g) {
      lo = m;
    } else {
      hi = m - 1;
    }
  }
  return lo;
}

/// وحدة حفظ: أرقامها (n1..n2، الوحدة المزدوجة رقمان) ومداها [a..b] بالترقيم العام للآيات
class QUnit {
  final int n1, n2, a, b;
  const QUnit(this.n1, this.n2, this.a, this.b);
  bool has(int n) => n >= n1 && n <= n2;
}

List<QUnit> _buildUnits(String dir) {
  QUnit su(int n1, int n2, int s1, int s2) => QUnit(n1, n2, _sFirst(s1), _sLast(s2));
  final baq141 = _sFirst(2) + 140; // البقرة 141
  final u = <QUnit>[
    su(30, 30, 78, 114), su(29, 29, 67, 77), su(28, 28, 58, 66), su(27, 27, 51, 57), su(26, 26, 46, 50),
    su(25, 25, 42, 45), su(24, 24, 39, 41), su(23, 23, 36, 38), su(22, 22, 33, 35), su(21, 21, 29, 32),
    su(20, 20, 27, 28), su(19, 19, 25, 26), su(18, 18, 23, 24), su(17, 17, 21, 22), su(16, 16, 19, 20),
    su(15, 15, 17, 18), su(14, 14, 15, 16), su(13, 13, 12, 14), su(11, 12, 10, 11), su(9, 10, 8, 9),
    su(8, 8, 7, 7), su(7, 7, 6, 6), su(6, 6, 5, 5), su(5, 5, 4, 4), su(4, 4, 3, 3),
    // البقرة على قسمين (الفاتحة مع القسم الأول)
    if (dir == 'asc') QUnit(1, 1, 1, baq141) else QUnit(3, 3, 1, baq141),
    if (dir == 'asc') QUnit(2, 3, baq141 + 1, _sLast(2)) else QUnit(1, 2, baq141 + 1, _sLast(2)),
  ];
  u.sort((x, y) => x.n1.compareTo(y.n1));
  return u;
}

final Map<String, List<QUnit>> _units = {};
List<QUnit> unitsOf(String dir) => _units[dir == 'asc' ? 'asc' : 'desc'] ??= _buildUnits(dir == 'asc' ? 'asc' : 'desc');

/// الوحدة التي تحمل الرقم n
QUnit unitOf(String dir, int n) => unitsOf(dir).firstWhere((u) => u.has(n), orElse: () => unitsOf(dir).last);

/// الوحدة التي فيها الآية g
QUnit unitAt(String dir, int g) => unitsOf(dir).firstWhere((u) => g >= u.a && g <= u.b, orElse: () => unitsOf(dir).last);

/// رقم الوحدة كما يُكتب: 27 أو 12+11
String unitNum(String dir, int n) {
  final u = unitOf(dir, n);
  if (u.n1 == u.n2) return '${u.n1}';
  return dir == 'asc' ? '${u.n1}+${u.n2}' : '${u.n2}+${u.n1}';
}

String _nm(int s) => qNames[s - 1];
String _pt(int g) {
  final s = _surahAt(g);
  if (g == _sFirst(s) && s != 2) return _nm(s);
  return '${_nm(s)} ${g - _sFirst(s) + 1}';
}

/// وصف الوحدة بترتيب الحفظ: «الناس ← النبأ»، «سورة الأعراف»، «البقرة 1–141»
String unitDesc(String dir, int n) {
  final u = unitOf(dir, n);
  final sa = _surahAt(u.a), sb = _surahAt(u.b);
  if (u.b <= _sLast(2)) {
    // قسما البقرة
    final from = u.a == 1 ? 1 : u.a - _sFirst(2) + 1;
    return 'البقرة $from–${u.b - _sFirst(2) + 1}';
  }
  if (sa == sb) return 'سورة ${_nm(sa)}';
  return dir == 'asc' ? '${_nm(sa)} ← ${_nm(sb)}' : '${_nm(sb)} ← ${_nm(sa)}';
}

/// وصف مدى بالسور بترتيب المصحف: «المجادلة – الناس»
String rangeSurahs(int a, int b) {
  var sa = _surahAt(a);
  if (sa == 1) sa = 2;
  final sb = _surahAt(b);
  final left = (a > _sFirst(sa) && sa == 2) ? _pt(a) : _nm(sa);
  final right = (b < _sLast(sb)) ? _pt(b) : _nm(sb);
  return sa == sb && left == right ? left : '$left – $right';
}

String juzLabel(int start, int end, {int type = 0, String dir = 'desc'}) {
  if (type == 30) return 'المصحف كاملًا';
  final u = unitOf(dir, start);
  if (start == end || (type == 1) || (u.n1 == start && u.n2 == end)) {
    return 'الجزء ${unitNum(dir, start)}: ${unitDesc(dir, start)}';
  }
  final st = buildPath(dir).where((x) => x.type == type && x.start == start).firstOrNull;
  if (st != null) return st.rangeText;
  return 'من الجزء $start إلى الجزء $end';
}

class PathStep {
  final int type, start, end, level;
  final String dir;
  /// أرقام الوحدات (أول رقم في كل وحدة) التي يشملها الاختبار
  final List<int> units;
  const PathStep(this.type, this.start, this.end, this.units, this.dir, this.level);
  String get key => '$type|$start';
  int get a => units.map((n) => unitOf(dir, n).a).reduce(min);
  int get b => units.map((n) => unitOf(dir, n).b).reduce(max);
  bool get isUnit => type == 1;
  String get rangeText => type == 30 ? 'المصحف كاملًا' : '($start–$end) ${rangeSurahs(a, b)}';
  String get label {
    if (type == 1) return 'الجزء ${unitNum(dir, start)}: ${unitDesc(dir, start)}';
    if (type == 30) return 'المصحف كاملًا (الختام)';
    return '${examTypes[type]} ($start–$end): ${rangeSurahs(a, b)}';
  }

  /// مهلة المراجعة بالأيام قبل الاختبار
  int get reviewDays => type == 1 ? 7 : (type >= 10 ? 60 : 30);
}

const levelNames = ['', 'المستوى الأول', 'المستوى الثاني', 'المستوى الثالث', 'الختام'];

final Map<String, List<PathStep>> _paths = {};

List<PathStep> buildPath(String dir) {
  final d = dir == 'asc' ? 'asc' : 'desc';
  return _paths[d] ??= _makePath(d);
}

List<PathStep> _makePath(String d) {
  final s = <PathStep>[];
  var level = 1;
  // وحدة مفردة
  void u(int n) {
    final x = unitOf(d, n);
    s.add(PathStep(1, x.n1, x.n2, [x.n1], d, level));
  }

  // اختبار مجمّع: كل الوحدات داخل [from..to] (أو قائمة محددة)
  void c(int type, int from, int to, [List<int>? only]) {
    final ns = only ?? [for (final x in unitsOf(d)) if (x.n1 >= from && x.n2 <= to) x.n1];
    s.add(PathStep(type, from, to, ns, d, level));
  }

  if (d == 'desc') {
    level = 1;
    u(30); u(29); u(28); c(3, 28, 30);
    u(27); u(26); c(5, 26, 30);
    u(25); u(24); u(23); c(3, 23, 25);
    u(22); u(21); c(5, 21, 25);
    c(10, 21, 30);
    level = 2;
    u(20); u(19); u(18); c(3, 18, 20);
    u(17); u(16); c(5, 16, 20);
    u(15); u(14); u(13); c(3, 13, 15);
    u(11); c(5, 11, 15);
    c(10, 11, 20);
    level = 3;
    u(9); u(8); c(3, 8, 10);
    u(7); u(6); c(5, 6, 10);
    u(5); u(4); c(3, 3, 5, [4, 5]); // آل عمران – النساء
    u(3); u(1); c(5, 1, 5);
    c(10, 1, 10);
  } else {
    level = 1;
    u(1); u(2); c(3, 1, 3);
    u(4); u(5); c(5, 1, 5);
    u(6); u(7); u(8); c(3, 6, 8);
    u(9); c(5, 6, 10);
    c(10, 1, 10);
    level = 2;
    u(11); u(13); c(3, 11, 13);
    u(14); u(15); c(5, 11, 15);
    u(16); u(17); u(18); c(3, 16, 18);
    u(19); u(20); c(5, 16, 20);
    c(10, 11, 20);
    level = 3;
    u(21); u(22); u(23); c(3, 21, 23);
    u(24); u(25); c(5, 21, 25);
    u(26); u(27); u(28); c(3, 26, 28);
    u(29); u(30); c(5, 26, 30);
    c(10, 21, 30);
  }
  level = 4;
  s.add(PathStep(30, 1, 30, [for (final x in unitsOf(d)) x.n1], d, level));
  return s;
}

/// الاختبار التالي للطالب، أو null إذا أتمّ المسار (حافظ)
/// [fromKey] مرحلة البداية (مثل "10|21") إن حدّدتها الإدارة، وإلا يبدأ من الوحدة التي فيها جزء البداية.
/// ما قبل آخر اختبار نجح فيه الطالب يُعدّ منتهيًا (لا يرجع الطلاب القدامى لمجمّعات أُضيفت للخطة).
PathStep? nextPathStep(String dir, int start, Set<String> passedKeys, [String? fromKey]) {
  final steps = buildPath(dir);
  var first = fromKey == null || fromKey.isEmpty ? -1 : steps.indexWhere((x) => x.key == fromKey);
  if (first < 0) first = steps.indexWhere((x) => x.type == 1 && start >= x.start && start <= x.end);
  if (first < 0) first = 0;
  var last = first - 1;
  for (var i = first; i < steps.length; i++) {
    if (passedKeys.contains(steps[i].key)) last = i;
  }
  return last + 1 < steps.length ? steps[last + 1] : null;
}
