import 'package:flutter/material.dart';

import '../logic.dart';
import 'ui.dart';
import 'widgets.dart';

/// شرح نظام الاختبارات والمسار للمختبرين
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  int _tab = 0;

  Widget _h(String t) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(t, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.ink)),
      );

  Widget _p(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: TextStyle(fontSize: 15, height: 1.75, color: context.txt)),
      );

  Widget _rules() => ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
        children: [
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _h('مسار الحفظ'),
              _p('حسب خطة المركز: كل طالب يمشي في مسار ثابت، ويحدد التطبيق الاختبار التالي له تلقائيًا.'),
              _p('الأجزاء محسوبة بالسور الكاملة (بداية الجزء ونهايته كما في خطة المركز).'),
              _p('كل مستوى (10 أجزاء) له نفس الترتيب:'),
              _p('• 3 أجزاء مفردة ← مجمّع 3 أجزاء\n'
                  '• جزءان ← مجمّع 5 أجزاء\n'
                  '• 3 أجزاء مفردة ← مجمّع 3 أجزاء\n'
                  '• جزءان ← مجمّع 5 أجزاء\n'
                  '• ثم الاختبار النهائي للمستوى: 10 أجزاء'),
              _p('وبعد المستويات الثلاثة: اختبار المصحف كاملًا، وبعده يصبح الطالب حافظًا للقرآن الكريم.'),
              _p('مهلة المراجعة قبل الاختبار: أسبوع للجزء، شهر للمجمّع، شهران للمستوى (10 أجزاء)، ولا يحفظ الطالب جديدًا خلالها.'),
              _p('الاتجاه حسب الطالب: من الناس (من الجزء 30 نزولًا) أو من البقرة (من الجزء 1 صعودًا)، ويبدأ من الجزء الذي حددته الإدارة له.'),
            ]),
          ),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _h('الانتقال بين الاختبارات'),
              _p('• إذا نجح الطالب ينتقل للاختبار التالي في خطة المركز.\n'
                  '• إذا رسب يعيد نفس الاختبار، ويُعلَّم "إعادة" تلقائيًا، ولا يوجد حد لعدد مرات الإعادة.\n'
                  '• لا يمكن تجاوز الاختبار المجمّع؛ المجمّع يشمل كل أجزائه.\n'
                  '• الترتيب ثابت: لا يمكن اختيار جزء أو اختبار خارج ترتيب خطة المركز.\n'
                  '• إذا كانت نقطة بداية الطالب أو اتجاهه غير صحيحة تُصحَّح من الإدارة.\n'
                  '• لا يمكن إعادة اختبار نجح فيه الطالب إلا بإذن من الإدارة، والإذن لمرة واحدة.'),
            ]),
          ),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _h('العلامات'),
              _p('• 5 أسئلة، لكل سؤال 15 علامة.\n'
                  '• الخطأ يخصم علامة، والتنبيه يخصم نصف علامة.\n'
                  '• أحكام التجويد من 20، والأداء من 5.\n'
                  '• المجموع من 100، والنجاح من 85.\n'
                  '• إذا وصل الخصم في سؤال واحد إلى 9 علامات يُغلق الاختبار ويُسجَّل أن الطالب لم يجتزه.'),
            ]),
          ),
          const SizedBox(height: 8),
          const DedicationLine(),
          const DevCredit(),
        ],
      );

  Widget _timeline(String dir) {
    final steps = buildPath(dir);
    final items = <Widget>[];
    var lastLevel = 0;
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      if (s.level != lastLevel) {
        lastLevel = s.level;
        final inLevel = steps.where((x) => x.level == s.level && x.type == 1).toList();
        String range = '';
        if (s.level < 4 && inLevel.isNotEmpty) {
          final lo = inLevel.map((x) => x.start).reduce((a, b) => a < b ? a : b);
          final hi = inLevel.map((x) => x.end).reduce((a, b) => a > b ? a : b);
          range = dir == 'asc' ? ': الأجزاء $lo ← $hi' : ': الأجزاء $hi ← $lo';
        }
        items.add(Padding(
          padding: EdgeInsets.fromLTRB(4, i == 0 ? 4 : 16, 4, 8),
          child: Text('${levelNames[s.level]}$range',
              style: TextStyle(color: context.accent, fontWeight: FontWeight.w800, fontSize: 15)),
        ));
      }
      final cumulative = s.type > 1;
      final big = s.type >= 10;
      final isLast = i == steps.length - 1;
      final title = s.type == 1
          ? 'الجزء ${unitNum(dir, s.start)}'
          : s.type == 30
              ? 'الختام: المصحف كاملًا'
              : 'مجمّع ${s.type} أجزاء (${s.start}–${s.end})';
      final sub = s.type == 1 ? unitDesc(dir, s.start) : (s.type == 30 ? 'بعده يصبح الطالب حافظًا' : rangeSurahs(s.a, s.b));
      final per = s.type == 30 ? '' : (s.reviewDays == 7 ? 'أسبوع' : (s.reviewDays == 30 ? 'شهر' : 'شهرين'));
      final Color bg = big ? context.chosen : (cumulative ? context.goldBg : context.surface);
      final Color fg = big ? const Color(0xFFF2D27A) : (cumulative ? context.goldFg : context.ink);
      final Color subC = big ? const Color(0xFFCFE3F1) : context.sub;
      items.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 40,
            child: Column(children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cumulative ? goldButton : context.soft,
                  shape: BoxShape.circle,
                ),
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: cumulative ? const Color(0xFF3B2C00) : context.accent)),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: context.line)),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: fg, fontSize: 14.5)),
                    Text(sub, style: TextStyle(color: subC, fontSize: 12.5)),
                  ]),
                ),
                if (per.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(
                      color: big ? const Color(0x26FFFFFF) : context.field,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(per, style: TextStyle(fontSize: 11, color: big ? Colors.white : context.sub)),
                  ),
              ]),
            ),
          ),
        ]),
      ));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 24), children: items);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const BrandTitle('نظام الاختبارات ومسار الحفظ')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: PillChoice(
            items: const ['القواعد', 'من الناس', 'من البقرة'],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
        ),
        Expanded(
          child: switch (_tab) {
            1 => _timeline('desc'),
            2 => _timeline('asc'),
            _ => _rules(),
          },
        ),
      ]),
    );
  }
}
