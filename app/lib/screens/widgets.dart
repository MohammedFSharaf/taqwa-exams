import 'package:flutter/material.dart';

import '../logic.dart';

const Color brandGreen = Color(0xFF1F5F46);
const Color brandGold = Color(0xFFB8913A);

/// الواجهة العلوية: اسم المركز وآية قرآنية
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: brandGold, width: 2),
            ),
            child: const Icon(Icons.menu_book_rounded, color: brandGold, size: 40),
          ),
          const SizedBox(height: 14),
          const Text(
            centerName,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.5),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: brandGold.withOpacity(0.6)),
            ),
            child: Column(
              children: const [
                Text(
                  '﴿ $ayahText ﴾',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFF3E6C4), fontSize: 19, height: 1.9),
                ),
                SizedBox(height: 4),
                Text(ayahRef, style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
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
