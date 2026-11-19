import 'package:flutter/material.dart';

import '../logic.dart';
import 'widgets.dart';

/// شرح نظام الاختبارات والمسار للمختبرين
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  Widget _h(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brandGreen)),
      );

  Widget _p(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 15, height: 1.7)),
      );

  Widget _pathTable(String dir) {
    final steps = buildPath(dir);
    Widget cell(String t, {bool bold = false, Color? bg}) => Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Text(t, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
        );
    final rows = <TableRow>[
      TableRow(children: [
        cell('#', bold: true, bg: const Color(0xFFEFF2F1)),
        cell('الاختبار', bold: true, bg: const Color(0xFFEFF2F1)),
      ]),
    ];
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      final cumulative = s.type > 1;
      final bg = cumulative ? const Color(0xFFFFF4DE) : null;
      rows.add(TableRow(children: [cell('${i + 1}', bg: bg), cell(s.label, bold: cumulative, bg: bg)]));
    }
    return Table(
      columnWidths: const {0: FixedColumnWidth(44), 1: FlexColumnWidth()},
      border: TableBorder.all(color: const Color(0xFFD9DDE1)),
      children: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const BrandTitle('نظام الاختبارات'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [Tab(text: 'القواعد'), Tab(text: 'من الناس'), Tab(text: 'من البقرة')],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _h('مسار الحفظ'),
                _p('كل طالب يمشي في مسار ثابت من 40 اختباراً، ويحدد التطبيق الاختبار التالي له تلقائياً عند اختياره.'),
                _p('كل عشرة أجزاء لها نفس الترتيب:'),
                _p('• 3 أجزاء مفردة ← اختبار مجمّع 3 أجزاء\n'
                    '• جزءان مفردان ← اختبار مجمّع 5 أجزاء\n'
                    '• 5 أجزاء مفردة ← اختبار مجمّع 10 أجزاء'),
                _p('وبعد العشرات الثلاث: اختبار المصحف كاملاً، وبعده يصبح الطالب حافظاً للقرآن الكريم.'),
                _p('الاتجاه حسب الطالب: من الناس (من الجزء 30 نزولاً) أو من البقرة (من الجزء 1 صعوداً)، ويبدأ من الجزء الذي حددته الإدارة له.'),
                _h('الانتقال بين الاختبارات'),
                _p('• إذا نجح الطالب ينتقل للاختبار التالي في المسار.\n'
                    '• إذا رسب يعيد نفس الاختبار، ويُعلَّم "إعادة" تلقائياً، ولا يوجد حد لعدد مرات الإعادة.\n'
                    '• لا يمكن تجاوز الاختبار المجمّع؛ المجمّع يشمل كل أجزائه.\n'
                    '• الترتيب ثابت: لا يمكن اختيار جزء أو اختبار خارج ترتيب المسار.\n'
                    '• إذا كانت نقطة بداية الطالب أو اتجاهه غير صحيحة تُصحَّح من الإدارة.\n'
                    '• لا يمكن إعادة اختبار نجح فيه الطالب إلا بإذن من الإدارة، والإذن لمرة واحدة.'),
                _h('العلامات'),
                _p('• 5 أسئلة، لكل سؤال 15 علامة.\n'
                    '• الخطأ يخصم علامة، والتنبيه يخصم نصف علامة.\n'
                    '• أحكام التجويد من 20، والأداء من 5.\n'
                    '• المجموع من 100، والنجاح من 85.\n'
                    '• إذا وصل الخصم في سؤال واحد إلى 9 علامات يُغلق الاختبار ويُسجَّل الطالب راسباً.'),
                const SizedBox(height: 24),
                const DevCredit(),
              ],
            ),
            ListView(padding: const EdgeInsets.all(12), children: [_pathTable('desc')]),
            ListView(padding: const EdgeInsets.all(12), children: [_pathTable('asc')]),
          ],
        ),
      ),
    );
  }
}
