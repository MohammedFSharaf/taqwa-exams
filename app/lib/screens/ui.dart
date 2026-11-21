import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../repo.dart';
import '../update_check.dart';
import 'widgets.dart';

// ===================== إعدادات العرض (حجم الخط، المظهر، الاهتزاز) =====================
class UiPrefs extends ChangeNotifier {
  static final UiPrefs I = UiPrefs._();
  UiPrefs._();

  double get scale => Repo.I.prefs.getDouble('ui_scale') ?? 1.0;
  ThemeMode get mode => switch (Repo.I.prefs.getString('ui_theme')) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };
  bool get haptics => Repo.I.prefs.getBool('ui_haptic') ?? true;

  Future<void> setScale(double v) async {
    await Repo.I.prefs.setDouble('ui_scale', v);
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) async {
    await Repo.I.prefs.setString('ui_theme', switch (m) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      _ => 'light',
    });
    notifyListeners();
  }

  Future<void> setHaptics(bool v) async {
    await Repo.I.prefs.setBool('ui_haptic', v);
    notifyListeners();
  }
}

/// اهتزاز خفيف عند الضغط (حسب الإعداد)
void haptic([bool strong = false]) {
  if (!UiPrefs.I.haptics) return;
  if (strong) {
    HapticFeedback.mediumImpact();
  } else {
    HapticFeedback.selectionClick();
  }
}

// ===================== ألوان حسب المظهر (فاتح/ليلي) =====================
extension Pal on BuildContext {
  bool get dark => Theme.of(this).brightness == Brightness.dark;
  Color get surface => dark ? const Color(0xFF16222D) : Colors.white;
  Color get bg => dark ? const Color(0xFF0D161E) : pageBg;
  Color get soft => dark ? const Color(0xFF1B2D3C) : skyLight;
  Color get field => dark ? const Color(0xFF1A2733) : const Color(0xFFF1F6FA);
  Color get line => dark ? const Color(0xFF263644) : const Color(0xFFE3ECF2);
  Color get ink => dark ? const Color(0xFFE8F1F7) : brandNavy;
  Color get txt => dark ? const Color(0xFFDCE6EE) : const Color(0xFF1E2A33);
  Color get sub => dark ? const Color(0xFF8FA3B3) : const Color(0xFF6B7D8A);
  Color get accent => dark ? const Color(0xFF4FB3E8) : brandBlue;
  Color get goldBg => dark ? const Color(0xFF3A3115) : const Color(0xFFFFF4DE);
  Color get goldFg => dark ? const Color(0xFFF0C64A) : const Color(0xFF8A5A00);
  Color get okBg => dark ? const Color(0xFF143022) : const Color(0xFFE2F3E9);
  Color get okFg => dark ? const Color(0xFF5FD08F) : okGreen;
  Color get badBg => dark ? const Color(0xFF3A1A1A) : const Color(0xFFFDECEC);
  Color get badFg => dark ? const Color(0xFFFF8A80) : const Color(0xFFC0392B);
  Color get chosen => dark ? const Color(0xFF2B79A8) : brandNavy;
}

// ===================== عناصر مشتركة =====================

/// بطاقة بيضاء بزوايا ناعمة
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap, onLongPress;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 10),
    this.color,
    this.borderColor,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(18);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? context.surface,
        borderRadius: r,
        border: borderColor != null ? Border.all(color: borderColor!, width: 1.4) : null,
        boxShadow: context.dark
            ? null
            : const [BoxShadow(color: Color(0x0F0A3C64), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// دائرة بأول حرف من الاسم
class NameAvatar extends StatelessWidget {
  final String name;
  final Color? color;
  final double size;
  final String? text;
  const NameAvatar(this.name, {super.key, this.color, this.size = 44, this.text});

  static String initial(String n) {
    final t = n.trim();
    if (t.isEmpty) return '؟';
    return t.characters.first;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color ?? const Color(0xFF9AAAB6), shape: BoxShape.circle),
      child: Text(text ?? initial(name),
          style: TextStyle(color: Colors.white, fontSize: size * 0.4, fontWeight: FontWeight.w800, height: 1.2)),
    );
  }
}

/// شارة صغيرة ملوّنة
class Tag extends StatelessWidget {
  final String text;
  final Color fg, bg;
  const Tag(this.text, {super.key, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w700)),
      );
}

/// زر ذهبي للأفعال المهمة
class GoldButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  const GoldButton({super.key, required this.text, required this.onPressed, this.icon, this.height = 56});

  @override
  Widget build(BuildContext context) {
    final on = onPressed != null;
    return Opacity(
      opacity: on ? 1 : 0.45,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF2C94C), Color(0xFFDDA915)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: on ? const [BoxShadow(color: Color(0x40C99A10), blurRadius: 14, offset: Offset(0, 5))] : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: on
                ? () {
                    haptic();
                    onPressed!();
                  }
                : null,
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, color: const Color(0xFF3B2C00)), const SizedBox(width: 8)],
                Flexible(
                  child: Text(text,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF3B2C00), fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// زر كحلي ممتلئ
class NavyButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  const NavyButton({super.key, required this.text, required this.onPressed, this.icon, this.height = 54});

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: context.chosen,
      foregroundColor: Colors.white,
      minimumSize: Size.fromHeight(height),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w800),
    );
    void tap() {
      haptic();
      onPressed!();
    }

    return icon == null
        ? FilledButton(style: style, onPressed: onPressed == null ? null : tap, child: Text(text))
        : FilledButton.icon(style: style, onPressed: onPressed == null ? null : tap, icon: Icon(icon), label: Text(text));
  }
}

/// اختيارات منفصلة (حبوب) والمختار كحلي
class PillChoice extends StatelessWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onChanged;
  final double height;
  final double fontSize;
  const PillChoice(
      {super.key, required this.items, required this.selected, required this.onChanged, this.height = 46, this.fontSize = 14.5});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < items.length; i++)
        Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: i < items.length - 1 ? 7 : 0),
            child: Material(
              color: i == selected ? context.chosen : context.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: i == selected ? context.chosen : context.line),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  haptic();
                  onChanged(i);
                },
                child: SizedBox(
                  height: height,
                  child: Center(
                    child: Text(
                      items[i],
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        color: i == selected ? Colors.white : context.sub,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// عنوان قسم صغير
class SectionLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.color, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
        child: Row(children: [
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: color ?? context.sub)),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

/// شريط تقدّم رفيع
class MiniBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const MiniBar(this.value, {super.key, this.color = goldButton, this.height = 5});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: height,
          color: color,
          backgroundColor: context.dark ? const Color(0xFF263644) : const Color(0xFFE6EDF2),
        ),
      );
}

/// صفحة فاضية بشكل لطيف
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(color: context.soft, shape: BoxShape.circle),
            child: Icon(icon, size: 56, color: context.accent),
          ),
          const SizedBox(height: 20),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: context.ink)),
          if (text != null) ...[
            const SizedBox(height: 8),
            Text(text!, textAlign: TextAlign.center, style: TextStyle(color: context.sub, fontSize: 14, height: 1.7)),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// نافذة من تحت بمقبض وعنوان
Future<T?> showAppSheet<T>(BuildContext context,
    {String? title, String? subtitle, required Widget Function(BuildContext ctx, StateSetter setS) builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(color: ctx.line, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ctx.ink)),
                ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle, style: TextStyle(fontSize: 13, color: ctx.sub)),
                ),
              const SizedBox(height: 14),
              builder(ctx, setS),
            ],
          ),
        ),
      ),
    ),
  );
}

/// علامة ✓ «تم الحفظ» تظهر لحظة وتختفي
void showSavedTick(BuildContext context, {String title = 'تم الحفظ', String? sub}) {
  final overlay = appNavigatorKey.currentState?.overlay ?? Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  haptic(true);
  late OverlayEntry e;
  e = OverlayEntry(builder: (ctx) => _SavedTick(title: title, sub: sub, onDone: () => e.remove()));
  overlay.insert(e);
}

class _SavedTick extends StatefulWidget {
  final String title;
  final String? sub;
  final VoidCallback onDone;
  const _SavedTick({required this.title, this.sub, required this.onDone});

  @override
  State<_SavedTick> createState() => _SavedTickState();
}

class _SavedTickState extends State<_SavedTick> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final opacity = t < 0.15 ? t / 0.15 : (t > 0.8 ? (1 - t) / 0.2 : 1.0);
          final scale = t < 0.2 ? 0.7 + 0.3 * Curves.easeOutBack.transform(t / 0.2) : 1.0;
          return Center(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Material(
                  color: context.surface,
                  elevation: 12,
                  shadowColor: const Color(0x330A3C64),
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(34, 24, 34, 20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(color: okGreen, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 46),
                      ),
                      const SizedBox(height: 12),
                      Text(widget.title,
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: context.ink)),
                      if (widget.sub != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(widget.sub!, style: TextStyle(fontSize: 13.5, color: context.sub)),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ===================== حالة الإنترنت =====================
class NetWatcher extends ChangeNotifier {
  static final NetWatcher I = NetWatcher._();
  NetWatcher._();

  bool online = true;
  Timer? _t;

  void start() {
    if (_t != null) return;
    _check();
    _t = Timer.periodic(const Duration(seconds: 15), (_) => _check());
  }

  Future<void> _check() async {
    var ok = false;
    try {
      final r = await InternetAddress.lookup('firestore.googleapis.com').timeout(const Duration(seconds: 6));
      ok = r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      ok = false;
    }
    if (ok != online) {
      online = ok;
      notifyListeners();
    }
  }
}

/// شريط «بدون إنترنت» (يظهر فقط عند انقطاع الاتصال)
class OfflineBanner extends StatelessWidget {
  final String text;
  const OfflineBanner({super.key, this.text = 'بدون إنترنت — التسجيلات محفوظة وبتترفع لحالها'});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NetWatcher.I,
      builder: (context, _) => AnimatedSize(
        duration: const Duration(milliseconds: 250),
        child: NetWatcher.I.online
            ? const SizedBox(width: double.infinity)
            : Container(
                width: double.infinity,
                color: context.goldBg,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(children: [
                  Icon(Icons.wifi_off_rounded, size: 18, color: context.goldFg),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(text,
                        style: TextStyle(color: context.goldFg, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
      ),
    );
  }
}

// ===================== الإعدادات =====================
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) =>
      IconButton(tooltip: 'الإعدادات', icon: const Icon(Icons.tune_rounded), onPressed: () => showSettingsSheet(context));
}

void showSettingsSheet(BuildContext context) {
  showAppSheet<void>(
    context,
    title: 'الإعدادات',
    builder: (ctx, setS) => AnimatedBuilder(
      animation: UiPrefs.I,
      builder: (ctx, _) {
        final p = UiPrefs.I;
        const scales = [1.0, 1.15, 1.3];
        var si = scales.indexWhere((s) => (s - p.scale).abs() < 0.01);
        if (si < 0) si = 0;
        final mi = switch (p.mode) { ThemeMode.dark => 1, ThemeMode.system => 2, _ => 0 };
        Widget label(String t) => Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text(t, style: TextStyle(color: ctx.sub, fontWeight: FontWeight.w700)),
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            label('حجم الخط'),
            PillChoice(
              items: const ['عادي', 'كبير', 'أكبر'],
              selected: si,
              height: 54,
              fontSize: 16,
              onChanged: (i) => p.setScale(scales[i]),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: ctx.field, borderRadius: BorderRadius.circular(14)),
              child: Text('مثال: في الجزء 6 · التالي: المائدة 71–76',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ctx.ink, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            const SizedBox(height: 14),
            label('المظهر'),
            PillChoice(
              items: const ['☀ فاتح', '☾ ليلي', 'حسب الجوال'],
              selected: mi,
              onChanged: (i) => p.setMode(const [ThemeMode.light, ThemeMode.dark, ThemeMode.system][i]),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: p.haptics,
              onChanged: (v) {
                p.setHaptics(v);
                if (v) HapticFeedback.selectionClick();
              },
              title: Text('اهتزاز خفيف عند الضغط', style: TextStyle(fontWeight: FontWeight.w800, color: ctx.ink)),
            ),
            const SizedBox(height: 6),
            const DevCredit(),
          ],
        );
      },
    ),
  );
}
