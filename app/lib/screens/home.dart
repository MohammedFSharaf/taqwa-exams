import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../logic.dart';
import '../repo.dart';
import '../update_check.dart';
import 'examiner.dart';
import 'gate.dart';
import 'guide.dart';
import 'my_exams.dart';
import 'pick_student.dart';
import 'ready.dart';
import 'ui.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _mine = Repo.I.myExams();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _all = Repo.I.allExams();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkForUpdate(context));
    ReadyWatcher.I.start();
  }

  void _go(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  static bool _isToday(dynamic t) {
    if (t is! Timestamp) return false;
    final d = t.toDate(), n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  /// طلاب آخر اختبار لهم راسب (بانتظار الإعادة)
  static int _awaitingRetest(List<Map<String, dynamic>> all) {
    final last = <String, Map<String, dynamic>>{};
    for (final e in all) {
      final id = (e['studentId'] ?? '').toString();
      final t = e['createdAt'];
      final cur = last[id];
      if (cur == null) {
        last[id] = e;
      } else {
        final ct = cur['createdAt'];
        if (t is Timestamp && (ct is! Timestamp || t.compareTo(ct) > 0)) last[id] = e;
      }
    }
    return last.values.where((e) => e['passed'] != true).length;
  }

  Widget _stat(String n, String label, {bool hero = false, Color? numColor, VoidCallback? onTap}) {
    final dark = context.dark;
    return Expanded(
      child: Container(
        height: 104,
        decoration: BoxDecoration(
          gradient: hero
              ? const LinearGradient(
                  colors: [Color(0xFF1593D6), Color(0xFF0A6FA6)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                )
              : null,
          color: hero ? null : context.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: hero
              ? const [BoxShadow(color: Color(0x330A86C4), blurRadius: 14, offset: Offset(0, 6))]
              : (dark ? null : const [BoxShadow(color: Color(0x0F0A3C64), blurRadius: 14, offset: Offset(0, 4))]),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(n,
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: hero ? Colors.white : (numColor ?? context.ink))),
                  ),
                  Text(label,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: hero ? const Color(0xFFE3F2FB) : context.sub)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navRow(String t, IconData ic, VoidCallback f, {String? trailing}) => InkWell(
        onTap: () {
          haptic();
          f();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(children: [
            Icon(ic, color: context.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.ink))),
            if (trailing != null) Text(trailing, style: TextStyle(color: context.sub, fontSize: 13)),
            const SizedBox(width: 6),
            Icon(Icons.chevron_left_rounded, color: context.sub),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const BrandTitle('مركز التقوى'),
        actions: [
          const SettingsButton(),
          TextButton(
            onPressed: () => Navigator.of(context)
                .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const GateScreen()), (r) => false),
            child: Text('خروج', style: TextStyle(color: context.sub)),
          ),
        ],
      ),
      body: Column(children: [
        const OfflineBanner(text: 'بدون إنترنت — الاختبارات محفوظة وبتترفع لحالها'),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _mine,
            builder: (context, mineSnap) {
              final mine = mineSnap.data?.docs ?? const [];
              final todayMine = mine.where((d) => _isToday(d.data()['createdAt'])).toList();
              final passedToday = todayMine.where((d) => d.data()['passed'] == true).length;
              final pending = mine.where((d) => d.metadata.hasPendingWrites).length;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${dayName(now)} ${now.day}/${now.month}/${now.year}',
                            style: TextStyle(color: context.sub, fontSize: 13)),
                        InkWell(
                          onTap: () async {
                            await Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => const ExaminerScreen()));
                            if (mounted) setState(() {});
                          },
                          child: Text('أهلاً ${Repo.I.examinerName ?? ''}',
                              style: TextStyle(color: context.ink, fontSize: 22, fontWeight: FontWeight.w800)),
                        ),
                      ]),
                    ),
                    if (mineSnap.hasData)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Tag(
                          pending == 0 ? '✓ كل البيانات مرفوعة' : 'بانتظار الرفع: $pending',
                          fg: pending == 0 ? context.okFg : context.goldFg,
                          bg: pending == 0 ? context.okBg : context.goldBg,
                        ),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: ReadyWatcher.I,
                    builder: (context, _) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _all,
                      builder: (context, allSnap) {
                        final all = allSnap.data?.docs.map((d) => d.data()).toList() ?? const <Map<String, dynamic>>[];
                        final w = ReadyWatcher.I;
                        return Column(children: [
                          Row(children: [
                            _stat(w.loaded ? '${w.entries.length}' : '…', 'جاهزون للاختبار',
                                hero: true, onTap: () => _go(const ReadyScreen())),
                            const SizedBox(width: 12),
                            _stat('${todayMine.length}', 'اختباراتي اليوم', onTap: () => _go(const MyExamsScreen())),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            _stat('$passedToday', 'ناجح اليوم',
                                numColor: context.okFg, onTap: () => _go(const MyExamsScreen())),
                            const SizedBox(width: 12),
                            _stat(allSnap.hasData ? '${_awaitingRetest(all)}' : '…', 'بانتظار الإعادة',
                                numColor: const Color(0xFFE57373)),
                          ]),
                        ]);
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  GoldButton(
                    text: 'اختبار جديد',
                    icon: Icons.add_rounded,
                    height: 62,
                    onPressed: () => _go(const PickStudentScreen()),
                  ),
                  const SizedBox(height: 16),
                  Panel(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      _navRow('جاهزون للاختبار', Icons.verified_rounded, () => _go(const ReadyScreen())),
                      Divider(height: 1, color: context.line),
                      _navRow('الاختبارات', Icons.list_alt_rounded, () => _go(const MyExamsScreen())),
                      Divider(height: 1, color: context.line),
                      _navRow('نظام الاختبارات ومسار الحفظ', Icons.route_rounded, () => _go(const GuideScreen())),
                      Divider(height: 1, color: context.line),
                      _navRow('اسم المختبر', Icons.person_rounded, () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExaminerScreen()));
                        if (mounted) setState(() {});
                      }, trailing: Repo.I.examinerName ?? ''),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  const AyahLine(),
                ],
              );
            },
          ),
        ),
      ]),
    );
  }
}
