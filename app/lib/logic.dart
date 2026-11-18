import 'dart:math';

const centerName = 'مركز التقوى لتعليم وتحفيظ القرآن الكريم';
const ayahText = 'وَلَقَدْ يَسَّرْنَا الْقُرْآنَ لِلذِّكْرِ فَهَلْ مِن مُّدَّكِرٍ';
const ayahRef = '[القمر: 17]';

/// اسم كل جزء: من أي سورة لأي سورة (السورة المقسومة تُحسب للجزء الذي تنتهي فيه، وأرقام الآيات في السور الطويلة)
const juzNames = <String>[
  '', 'الفاتحة ← البقرة 141', 'البقرة 142–252', 'البقرة 253 ← آل عمران 92', 'آل عمران 93 ← النساء 23', 'النساء 24–147', 'النساء 148 ← المائدة 81', 'المائدة 82 ← الأنعام 110', 'الأنعام 111 ← الأعراف 87', 'الأعراف 88 ← الأنفال 40', 'الأنفال 41 ← التوبة 92', 'التوبة 93 ← هود 5', 'هود 6 ← يوسف 52', 'يوسف 53 ← إبراهيم', 'الحجر ← النحل', 'الإسراء ← الكهف 74', 'الكهف 75 ← طه', 'الأنبياء ← الحج', 'المؤمنون ← النور', 'الفرقان ← الشعراء', 'النمل ← القصص', 'العنكبوت ← السجدة', 'الأحزاب ← فاطر', 'يس ← ص', 'الزمر ← غافر', 'فصلت ← الجاثية', 'الأحقاف ← ق', 'الذاريات ← الحديد', 'المجادلة ← التحريم', 'الملك ← المرسلات', 'النبأ ← الناس',
];
const juzFrom = <String>[
  '', 'الفاتحة', 'البقرة 142', 'البقرة 253', 'آل عمران 93', 'النساء 24', 'النساء 148', 'المائدة 82', 'الأنعام 111', 'الأعراف 88', 'الأنفال 41', 'التوبة 93', 'هود 6', 'يوسف 53', 'الحجر', 'الإسراء', 'الكهف 75', 'الأنبياء', 'المؤمنون', 'الفرقان', 'النمل', 'العنكبوت', 'الأحزاب', 'يس', 'الزمر', 'فصلت', 'الأحقاف', 'الذاريات', 'المجادلة', 'الملك', 'النبأ',
];
const juzTo = <String>[
  '', 'البقرة 141', 'البقرة 252', 'آل عمران 92', 'النساء 23', 'النساء 147', 'المائدة 81', 'الأنعام 110', 'الأعراف 87', 'الأنفال 40', 'التوبة 92', 'هود 5', 'يوسف 52', 'إبراهيم', 'النحل', 'الكهف 74', 'طه', 'الحج', 'النور', 'الشعراء', 'القصص', 'السجدة', 'فاطر', 'ص', 'غافر', 'الجاثية', 'ق', 'الحديد', 'التحريم', 'المرسلات', 'الناس',
];

/// عدد الأجزاء => اسم نوع الاختبار
const examTypes = <int, String>{
  1: 'اختبار جزء',
  3: 'اختبار 3 أجزاء',
  5: 'اختبار 5 أجزاء',
  10: 'اختبار 10 أجزاء',
  30: 'اختبار 30 جزءاً',
};

const int qCount = 5;
const double qMax = 15;
const double tajweedMax = 20;
const double perfMax = 5;
const double passMark = 85;
const double closeAt = 9; // خصم 9 علامات في سؤال واحد يغلق الاختبار
const double errVal = 1;
const double alertVal = 0.5;

String juzLabel(int start, int end) {
  if (start == end) return 'الجزء $start: ${juzNames[start]}';
  return 'الأجزاء $start–$end: ${juzFrom[start]} ← ${juzTo[end]}';
}

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
  ExamSetup({
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

// ===== مسار الحفظ =====
const pathDirs = <String, String>{'desc': 'من الناس (30 ← 1)', 'asc': 'من البقرة (1 ← 30)'};

class PathStep {
  final int type, start;
  const PathStep(this.type, this.start);
  int get end => start + type - 1;
  String get key => '$type|$start';
  String get label {
    if (type == 1) return 'الجزء $start: ${juzNames[start]}';
    if (type == 30) return 'المصحف كاملاً (30 جزءاً)';
    return '${examTypes[type]} ($start–$end): ${juzFrom[start]} ← ${juzTo[end]}';
  }
}

List<PathStep> buildPath(String dir) {
  final s = <PathStep>[];
  if (dir == 'asc') {
    for (final b in [1, 11, 21]) {
      s.addAll([PathStep(1, b), PathStep(1, b + 1), PathStep(1, b + 2), PathStep(3, b),
        PathStep(1, b + 3), PathStep(1, b + 4), PathStep(5, b)]);
      for (var j = b + 5; j <= b + 9; j++) {
        s.add(PathStep(1, j));
      }
      s.add(PathStep(10, b));
    }
  } else {
    for (final t in [30, 20, 10]) {
      s.addAll([PathStep(1, t), PathStep(1, t - 1), PathStep(1, t - 2), PathStep(3, t - 2),
        PathStep(1, t - 3), PathStep(1, t - 4), PathStep(5, t - 4)]);
      for (var j = t - 5; j >= t - 9; j--) {
        s.add(PathStep(1, j));
      }
      s.add(PathStep(10, t - 9));
    }
  }
  s.add(const PathStep(30, 1));
  return s;
}

/// الاختبار التالي للطالب، أو null إذا أتمّ المسار (حافظ)
PathStep? nextPathStep(String dir, int start, Set<String> passedKeys) {
  final steps = buildPath(dir);
  var first = steps.indexWhere((x) => x.type == 1 && x.start == start);
  if (first < 0) first = 0;
  for (var i = first; i < steps.length; i++) {
    if (!passedKeys.contains(steps[i].key)) return steps[i];
  }
  return null;
}
