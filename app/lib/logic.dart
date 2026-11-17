import 'dart:math';

const centerName = 'مركز التقوى لتعليم وتحفيظ القرآن الكريم';
const ayahText = 'وَلَقَدْ يَسَّرْنَا الْقُرْآنَ لِلذِّكْرِ فَهَلْ مِن مُّدَّكِرٍ';
const ayahRef = '[القمر: 17]';

const juzNames = <String>[
  '', 'الم', 'سيقول', 'تلك الرسل', 'لن تنالوا', 'والمحصنات', 'لا يحب الله', 'وإذا سمعوا',
  'ولو أننا', 'قال الملأ', 'واعلموا', 'يعتذرون', 'وما من دابة', 'وما أبرئ', 'ربما', 'سبحان الذي',
  'قال ألم', 'اقترب للناس', 'قد أفلح', 'وقال الذين', 'أمّن خلق', 'اتل ما أوحي', 'ومن يقنت', 'وما لي',
  'فمن أظلم', 'إليه يرد', 'حم', 'قال فما خطبكم', 'قد سمع الله', 'تبارك', 'عمّ',
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
  if (start == end) return 'الجزء $start (${juzNames[start]})';
  return 'من الجزء $start (${juzNames[start]}) إلى الجزء $end (${juzNames[end]})';
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
