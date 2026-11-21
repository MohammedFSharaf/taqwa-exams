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
              _p('كل طالب يمشي في مسار ثابت من 40 اختباراً، ويحدد التطبيق الاختبار التالي له تلقائياً عند اختياره.'),
              _p('كل عشرة أجزاء لها نفس الترتيب:'),
              _p('• 3 أجزاء مفردة ← اختبار مجمّع 3 أجزاء\n'
                  '• جزءان مفردان ← اختبار مجمّع 5 أجزاء\n'
                  '• 5 أجزاء مفردة ← اختبار مجمّع 10 أجزاء'),
              _p('وبعد العشرات الثلاث: اختبار المصحف كاملاً، وبعده يصبح الطالب حافظاً للقرآن الكريم.'),
              _p('الاتجاه حسب الطالب: من الناس (من الجزء 30 نزولاً) أو من البقرة (من الجزء 1 صعوداً)، ويبدأ من الجزء الذي حددته الإدارة له.'),
            ]),
          ),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _h('الانتقال بين الاختبارات'),
              _p('• إذا نجح الطالب ينتقل للاختبار التالي في المسار.\n'
                  '• إذا رسب يعيد نفس الاختبار، ويُعلَّم "إعادة" تلقائياً، ولا يوجد حد لعدد مرات الإعادة.\n'
                  '• لا يمكن تجاوز الاختبار المجمّع؛ المجمّع يشمل كل أجزائه.\n'
                  '• الترتيب ثابت: لا يمكن اختيار جزء أو اختبار خارج ترتيب المسار.\n'
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
                  '• إذا وصل الخصم في سؤال واحد إلى 9 علامات يُغلق الاختبار ويُسجَّل الطالب راسباً.'),
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
    const names = ['العشر الأولى', 'العشر الثانية', 'العشر الثالثة'];
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      if (i % 13 == 0 && i < 39) {
        final a = steps[i].start;
        final b = steps[i + 12].start + steps[i + 12].type - 1;
        final first = dir == 'asc' ? a : steps[i].start;
        final last = dir == 'asc' ? b : steps[i + 12].start;
        items.add(Padding(
          padding: EdgeInsets.fromLTRB(4, i == 0 ? 4 : 16, 4, 8),
          child: Text('${names[i ~/ 13]}: الأجزاء $first ← $last',
              style: TextStyle(color: context.accent, fontWeight: FontWeight.w800, fontSize: 15)),
        ));
      }
      if (i == 39) {
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text('الختام', style: TextStyle(color: context.accent, fontWeight: FontWeight.w800, fontSize: 15)),
        ));
      }
      final cumulative = s.type > 1;
      final isLast = i == steps.length - 1;
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cumulative ? context.goldBg : context.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(s.label,
                  style: TextStyle(
                      fontWeight: cumulative ? FontWeight.w800 : FontWeight.w600,
                      color: cumulative ? context.goldFg : context.ink,
                      fontSize: 14.5)),
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
