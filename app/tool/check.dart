import 'package:taqwa_exams/daily.dart';
import 'package:taqwa_exams/logic.dart';

void expect(bool c, String m) {
  print('${c ? 'OK ' : 'FAIL'} $m');
}

void main() {
  for (final dir in ['desc', 'asc']) {
    print('===== $dir =====');
    final us = unitsOf(dir);
    // coverage
    final seen = List<int>.filled(6237, 0);
    for (final u in us) {
      for (var g = u.a; g <= u.b; g++) seen[g]++;
    }
    expect(seen.skip(1).every((x) => x == 1), 'units cover every ayah once');
    for (final u in us) {
      print('unit ${unitNum(dir, u.n1)} [${u.a}-${u.b}] ${unitDesc(dir, u.n1)} pages=${pagesOfRange(u.a, u.b).toStringAsFixed(1)}');
    }
    final o = memOrder(dir);
    final s = o.order.toSet();
    expect(o.order.length == 6236 && s.length == 6236, 'memOrder permutation');
    for (final u in us) {
      final ps = [for (var g = u.a; g <= u.b; g++) o.pos[g]]..sort();
      expect(ps.last - ps.first == ps.length - 1, 'unit ${u.n1} contiguous in order');
    }
    final p = buildPath(dir);
    print('path length ${p.length}');
    for (var i = 0; i < p.length; i++) {
      print('${i + 1}. [L${p[i].level}] ${p[i].key}  ${p[i].label}  units=${p[i].units} days=${p[i].reviewDays}');
    }
    expect(p.map((x) => x.key).toSet().length == p.length, 'unique keys');
  }
  // grandfathering
  String? nx(String dir, int start, List<String> passed, [String? from]) =>
      nextPathStep(dir, start, passed.toSet(), from)?.key;
  expect(nx('desc', 30, []) == '1|30', 'new desc student starts 1|30');
  expect(nx('desc', 30, ['1|30', '1|29', '1|28', '3|28', '1|27', '1|26', '5|26', '1|25', '1|24', '1|23', '1|22']) == '1|21',
      'old student past 22 -> 1|21 (skips new C3 23-25)');
  expect(nx('desc', 30, ['1|30', '1|29', '1|28', '3|28', '1|27', '1|26', '5|26', '1|25', '1|24', '1|23']) == '3|23',
      'student who finished 23 -> new C3 23-25');
  expect(nx('desc', 30, ['1|30', '1|29', '1|28', '3|28', '1|27', '1|26', '5|26', '1|25', '1|24', '1|23', '1|22', '1|21']) == '5|21',
      'after 21 -> C5 21-25');
  expect(nx('desc', 30, ['10|21']) == '1|20', 'passed C10 21-30 -> 1|20');
  expect(nx('desc', 21, [], '10|21') == '10|21', 'pathFrom 10|21');
  expect(nx('desc', 12, []) == '1|11', 'start juz 12 -> double unit 1|11');
  expect(nx('desc', 13, ['1|13', '3|13']) == '1|11', 'after C3 13-15 -> 12+11');
  expect(nx('desc', 5, ['1|5', '1|4']) == '3|3', 'after آل عمران -> C3 3-5');
  expect(nx('desc', 5, ['1|5', '1|4', '3|3', '1|3', '1|1']) == '5|1', 'after البقرة -> C5 1-5');
  expect(nx('asc', 1, []) == '1|1', 'asc starts البقرة 1');
  expect(nx('asc', 1, ['1|1']) == '1|2', 'asc next البقرة 2');
  expect(nx('asc', 1, ['1|1', '1|2']) == '3|1', 'asc C3 البقرة');
  // daily: desc student in unit 27 (الحديد first)
  final st0 = dailyStatus('desc', 27, {'1|30', '1|29', '1|28', '3|28'}, [], {'lastG': null}, 1);
  print('desc 27 fresh: ${st0.mode} ${st0.title} from=${st0.fromG == null ? '' : posLabel(st0.fromG!)}');
  expect(st0.mode == 'memorize' && surahOf(st0.fromG!) == 57 && ayahNo(st0.fromG!) == 1, 'unit 27 starts at الحديد 1');
  // finished الذاريات whole (end of unit 27)
  final endG = surahEnd(51);
  final st1 = dailyStatus('desc', 27, {'1|30', '1|29', '1|28', '3|28'},
      [
        {'date': '2026-11-20', 'status': 'recited', 'newMem': {'fromG': surahFirst(51), 'toG': endG}}
      ],
      null, 1);
  print('after الذاريات: ${st1.mode} ${st1.title}');
  expect(st1.mode == 'review_exam', 'finishing الذاريات -> review for exam');
  final left = reviewDaysLeft('desc', st1, [
    {'date': '2026-11-20', 'status': 'recited', 'newMem': {'fromG': surahFirst(51), 'toG': endG}}
  ], '');
  print('days left: $left -> ${left == null ? '' : reviewDeadlineText(left, 7)}');
  // old-style mid الذاريات 31-45 (old juz 27 start) -> next?
  final st2 = dailyStatus('desc', 27, {'1|30', '1|29', '1|28', '3|28'},
      [
        {'date': '2026-11-20', 'status': 'recited', 'newMem': {'fromG': gidOf(57, 1), 'toG': gidOf(57, 29)}}
      ],
      null, 1);
  print('after الحديد: ${st2.mode} ${st2.title} from=${posLabel(st2.fromG!)}');
  // readiness of C3 3|3 desc
  final c33 = buildPath('desc').firstWhere((x) => x.key == '3|3');
  print('C3 3|3 range ${posLabel(c33.a)} .. ${posLabel(c33.b)} units ${c33.units}');
  final r = examReadiness('desc', 5, {'1|5', '1|4'}, [
    {'date': '2026-11-20', 'status': 'recited', 'reviews': [ {'fromG': surahFirst(3), 'toG': surahEnd(4)} ]}
  ], {'lastG': surahEnd(3)}, '');
  expect(r.ok, 'C3 آل عمران–النساء ready when reviewed both (${r.reason} ${r.missing})');
  print(juzLabel(1, 2, type: 1, dir: 'desc'));
  print(juzLabel(3, 5, type: 3, dir: 'desc'));
  print(juzLabel(27, 27));
  print(juzLabel(11, 12, type: 1));

  // ===== الجلسة القادمة =====
  final k29 = juzOrdKey('desc', 29);
  final sA = dailyStatus('desc', 30, {'1|30'}, [], {'lastG': null, 'fresh': true, 'juzOrder': {'$k29': 'first'}}, 1);
  final sC = dailyStatus('desc', 30, {'1|30'}, [
    {'date': '2026-11-21', 'status': 'recited', 'newMem': {'fromG': gidOf(67, 1), 'toG': gidOf(67, 30)}}
  ], {'lastG': null, 'fresh': true, 'juzOrder': {'$k29': 'first'}}, 1);
  expect(posLabel(sA.fromG!) == 'الملك 1' && posLabel(sC.fromG!) == 'القلم 1', 'start surah الملك works');
  final np = nextPlan('desc', sA, 7);
  print('next: ${np?.mem} | ${np?.review} | ${np?.short}');
  final np2 = nextPlan('desc', sC, 3);
  print('next2: ${np2?.mem} | ${np2?.review}');

  // ===== على دفعات =====
  final mur = [gidOf(77, 1), gidOf(77, 50)];
  final q = splitQuestionSeg('desc', mur[0], mur[1], 1);
  expect(q != null, 'split question for المرسلات');
  final sp1 = dailyStatus('desc', 30, {'1|30'}, [
    {'date': '2026-11-22', 'status': 'recited', 'newMem': {'fromG': mur[0], 'toG': mur[1], 'split': true}}
  ], {'lastG': null, 'fresh': true}, 1);
  expect(sp1.mode == 'review_surah', 'split -> review_surah (${sp1.mode})');
  final sp0 = dailyStatus('desc', 30, {'1|30'}, [
    {'date': '2026-11-22', 'status': 'recited', 'newMem': {'fromG': mur[0], 'toG': mur[1], 'split': false}}
  ], {'lastG': null, 'fresh': true}, 1);
  expect(sp0.mode == 'memorize' && posLabel(sp0.fromG!) == 'الإنسان 1', 'continuous -> next surah');
  expect(splitQuestionSeg('desc', gidOf(78, 1), gidOf(78, 40), 5) == null, 'no question when surah <= daily min');
}
