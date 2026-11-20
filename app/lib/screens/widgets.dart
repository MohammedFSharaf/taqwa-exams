import 'package:flutter/material.dart';

import '../logic.dart';
import '../env.dart';
import '../slogan.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dedication.dart';

const Color brandGreen = Color(0xFF1F5F46);
const Color brandGold = Color(0xFFB8913A);

/// الواجهة العلوية: شعار المركز واسمه وشعار «نحو مدرسة قرآنية»
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF174A36), brandGreen],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onLongPress: () => showAboutApp(context),
            child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: brandGold, width: 2),
            ),
            child: ClipOval(
              child: Image.asset('assets/logo.png', width: 96, height: 96, fit: BoxFit.contain),
            ),
          ),
          ),
          const SizedBox(height: 12),
          const Text(
            centerName,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.5),
          ),
          const SizedBox(height: 6),
          Image.memory(sloganPng, height: 44, fit: BoxFit.contain, gaplessPlayback: true),
          if (kBeta)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(color: brandGold, borderRadius: BorderRadius.circular(8)),
              child: const Text('نسخة تجريبية', style: TextStyle(color: Color(0xFF174A36), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

/// سطر الآية الكريمة بأسفل الشاشة
class AyahLine extends StatelessWidget {
  const AyahLine({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Text(
        '﴿ $ayahText ﴾',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF8A7A4A), fontSize: 15, height: 1.6),
      ),
    );
  }
}

/// زر اختيار بقسمين (بدون أيقونات)
class TwoWaySwitch extends StatelessWidget {
  final String first, second;
  final bool firstSelected;
  final ValueChanged<bool> onChanged;
  const TwoWaySwitch(
      {super.key, required this.first, required this.second, required this.firstSelected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget part(String t, bool on, bool isFirst) => Expanded(
          child: InkWell(
            onTap: () => onChanged(isFirst),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              color: on ? brandGreen : Colors.white,
              alignment: Alignment.center,
              child: Text(t,
                  style: TextStyle(
                      color: on ? Colors.white : Colors.black54, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFCFD6D2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [part(first, firstSelected, true), part(second, !firstSelected, false)]),
      ),
    );
  }
}

/// زر كبير للشاشة الرئيسية
class BigButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onPressed;
  final bool filled;
  const BigButton({super.key, required this.icon, required this.text, required this.onPressed, this.filled = true});

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size.fromHeight(60)),
      textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    );
    return filled
        ? FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(text), style: style)
        : OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(text), style: style);
  }
}

/// عنوان الشريط العلوي مع شعار المركز الصغير
class BrandTitle extends StatelessWidget {
  final String title;
  const BrandTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: ClipOval(child: Image.asset('assets/logo.png', width: 28, height: 28, fit: BoxFit.contain)),
        ),
        const SizedBox(width: 8),
        Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

/// صف اختيارات متساوية (بدون أيقونات)
class SegmentedRow extends StatelessWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onChanged;
  const SegmentedRow({super.key, required this.items, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFCFD6D2)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? brandGreen : Colors.white,
                    border: i < items.length - 1
                        ? const BorderDirectional(end: BorderSide(color: Color(0xFFE3E6E4)))
                        : null,
                  ),
                  child: Text(items[i],
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: i == selected ? Colors.white : Colors.black54)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// اسم المطوّر
const devCredit = 'Eng. Mohammed F Sharaf';

Future<String> appVersionText() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final v = info.version.endsWith('.0') ? info.version.substring(0, info.version.length - 2) : info.version;
    final first = info.version == '1.0.0' ? 'الإصدار الأول ' : 'الإصدار ';
    return '$first$v (${info.buildNumber})${kBeta ? ' — تجريبي' : ''}';
  } catch (_) {
    return '';
  }
}

/// «حول التطبيق»: رقم الإصدار واسم المطوّر (بشكل خفيف)
class DevCredit extends StatelessWidget {
  const DevCredit({super.key});

  @override
  Widget build(BuildContext context) {
    const st = TextStyle(color: Colors.black38, fontSize: 11.5, height: 1.7);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FutureBuilder<String>(
        future: appVersionText(),
        builder: (context, snap) => Column(
          children: [
            const Divider(),
            const Text('حول التطبيق', style: TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.bold)),
            if ((snap.data ?? '').isNotEmpty)
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: ''),
                  TextSpan(text: snap.data!, style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                textAlign: TextAlign.center,
                style: st,
              ),
            const Text.rich(
              TextSpan(children: [
                TextSpan(text: 'تصميم وتطوير: '),
                TextSpan(text: devCredit, style: TextStyle(fontWeight: FontWeight.bold)),
              ]),
              textAlign: TextAlign.center,
              style: st,
            ),
          ],
        ),
      ),
    );
  }
}

/// نافذة «حول التطبيق» (تفتح بضغطة طويلة على الشعار)
void showAboutApp(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      content: const SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [DedicationLine(), SizedBox(height: 6), DevCredit()])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
    ),
  );
}

// ===================== صدقة جارية =====================
const dedicationShort = 'صدقة جارية عن أرواح مؤسسي مركز التقوى — رحمهم الله';
const dedicationIntro =
    'أُنجز هذا العمل صدقةً جاريةً عن أرواح من وضعوا اللبنات الأولى لمركز التقوى لتعليم وتحفيظ القرآن الكريم، '
    'ليبقى أجره موصولاً لهم ما دام في المركز حافظٌ يحفظ، ومُسمِّعٌ يُسمِّع، ومختبِرٌ يختبر:';
const dedicationNames = [
  'الشيخ ياسر العفيفي (أبو حمزة)',
  'الشيخ محمد صيام (أبو أنس)',
  'الشيخ أمجد هتهت (أبو الأدهم)',
  'الشيخ مصطفى المدهون (أبو جعفر)',
  'الشيخ وسام أبو كويك (أبو حازم)',
  'الشيخ عبد الرحمن العفيفي (أبو صلاح)',
  'الشيخ يوسف العفيفي (أبو الحسن)',
  'الشيخ عبد الرحيم شرف (أبو خالد)',
];
const dedicationOutro =
    'رحمهم الله رحمةً واسعة، وأسكنهم الفردوس الأعلى، ونسأل الله أن يتقبّل هذا العمل ويجعله في ميزان حسناتهم.';

void showDedication(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DedicationScreen()));
}

/// سطر قصير قابل للضغط يفتح النص الكامل
class DedicationLine extends StatelessWidget {
  const DedicationLine({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showDedication(context),
      borderRadius: BorderRadius.circular(8),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(16, 2, 16, 10),
        child: Text(dedicationShort,
            textAlign: TextAlign.center,
            style: TextStyle(color: brandGold, fontSize: 12.5, fontWeight: FontWeight.bold, height: 1.6)),
      ),
    );
  }
}
