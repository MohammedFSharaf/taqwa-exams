import 'package:flutter/material.dart';

import '../repo.dart';
import 'new_exam.dart';
import 'ready.dart';
import 'ui.dart';
import 'widgets.dart';

/// اختبار جديد: بحث + الحلقات + الجاهزون أولاً
class PickStudentScreen extends StatefulWidget {
  const PickStudentScreen({super.key});

  @override
  State<PickStudentScreen> createState() => _PickStudentScreenState();
}

class _PickStudentScreenState extends State<PickStudentScreen> {
  String _q = '';
  String? _halaqaId; // null = الكل

  @override
  void initState() {
    super.initState();
    ReadyWatcher.I.start();
  }

  void _open(Student s, Halaqa? h) {
    final halaqa = h ?? ReadyWatcher.I.halaqat.where((x) => x.id == s.halaqaId).firstOrNull ?? Halaqa(s.halaqaId, '');
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => NewExamScreen(initialHalaqa: halaqa, initialStudent: s)));
  }

  Future<void> _addNew(List<Halaqa> hs) async {
    var h = hs.where((x) => x.id == _halaqaId).firstOrNull;
    if (h == null) {
      h = await showAppSheet<Halaqa>(
        context,
        title: 'طالب جديد — اختر الحلقة',
        builder: (ctx, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final x in hs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: () => Navigator.pop(ctx, x),
                child: Text(x.name, style: TextStyle(color: ctx.ink, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
        ]),
      );
    }
    if (h == null || !mounted) return;
    final s = await showModalBottomSheet<Student>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StudentPicker(halaqa: h!),
    );
    if (s != null) _open(s, h);
  }

  Widget _chip(String t, bool on, VoidCallback f) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: Material(
          color: on ? context.chosen : context.surface,
          shape: StadiumBorder(side: BorderSide(color: on ? context.chosen : context.line)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () {
              haptic();
              f();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              child: Text(t,
                  style: TextStyle(
                      color: on ? Colors.white : context.ink, fontWeight: FontWeight.w700, fontSize: 14.5)),
            ),
          ),
        ),
      );

  Widget _row(Student s, String sub, Widget trailing, {Color? avatar, bool ready = false, Halaqa? h}) => Panel(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        borderColor: ready ? (context.dark ? const Color(0xFF2E6B48) : const Color(0xFFA8DDBF)) : null,
        onTap: () => _open(s, h),
        child: Row(children: [
          NameAvatar(s.name, color: avatar),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.ink)),
              Text(sub, style: TextStyle(fontSize: 12.5, color: context.sub, height: 1.5)),
            ]),
          ),
          const SizedBox(width: 8),
          trailing,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const BrandTitle('اختبار جديد')),
      body: AnimatedBuilder(
        animation: ReadyWatcher.I,
        builder: (context, _) {
          final w = ReadyWatcher.I;
          final hs = w.halaqat;
          final hName = {for (final h in hs) h.id: h};
          bool match(Student s) =>
              (_halaqaId == null || s.halaqaId == _halaqaId) && (_q.isEmpty || s.name.contains(_q));
          final ready = w.entries.where((e) => match(e.student)).toList();
          final readyIds = {for (final e in w.entries) e.student.id};
          final others = w.students.where((s) => match(s) && !readyIds.contains(s.id)).toList();
          final showOthers = _q.isNotEmpty || _halaqaId != null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              TextField(
                decoration: const InputDecoration(hintText: 'ابحث باسم الطالب…', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _q = v.trim()),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  _chip('الكل', _halaqaId == null, () => setState(() => _halaqaId = null)),
                  for (final h in hs) _chip(h.name, _halaqaId == h.id, () => setState(() => _halaqaId = h.id)),
                ]),
              ),
              if (!w.loaded)
                const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
              else ...[
                SectionLabel('✓ جاهزون للاختبار (${ready.length})', color: context.okFg),
                if (ready.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Text('لا يوجد جاهزون${_halaqaId != null || _q.isNotEmpty ? ' هنا' : ' الآن'}',
                        style: TextStyle(color: context.sub)),
                  ),
                for (final e in ready)
                  _row(
                    e.student,
                    '${e.step.label} · ${e.halaqa?.name ?? ''}${e.byPermit ? ' · بتصريح' : ''}',
                    IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFF2C94C), Color(0xFFDDA915)]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text('اختبار',
                            style: TextStyle(color: Color(0xFF3B2C00), fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                    ),
                    avatar: okGreen,
                    ready: true,
                    h: e.halaqa,
                  ),
                if (showOthers) ...[
                  SectionLabel('باقي الطلاب (${others.length})'),
                  for (final s in others.take(80))
                    () {
                      final inf = w.info[s.id];
                      final h = hName[s.halaqaId];
                      final retest = inf?.retest ?? false;
                      return _row(
                        s,
                        [
                          if (inf != null) inf.label,
                          if (_halaqaId == null && h != null) h.name,
                          if (s.pending) 'جديد',
                        ].join(' · '),
                        retest
                            ? Tag('إعادة', fg: context.badFg, bg: context.badBg)
                            : Tag('ليس جاهزاً', fg: context.goldFg, bg: context.goldBg),
                        h: h,
                      );
                    }(),
                ] else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                    child: Text('لاختبار طالب غير جاهز: ابحث باسمه أو اختر حلقته.',
                        style: TextStyle(color: context.sub, fontSize: 13)),
                  ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => _addNew(hs),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('طالب جديد غير موجود بالقائمة'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
