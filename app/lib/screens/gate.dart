import 'package:flutter/material.dart';

import '../bio.dart';
import '../repo.dart';
import 'examiner.dart';
import 'home.dart';
import 'sheikh.dart';
import 'widgets.dart';
import 'ui.dart';

/// شاشة البداية: تسجيل دخول الجهاز ثم كلمة السر الموحدة
class GateScreen extends StatefulWidget {
  const GateScreen({super.key});

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  final _pass = TextEditingController();
  bool _loading = true;
  bool _noNet = false;
  String? _error;
  String _role = Repo.I.lastRole ?? 'examiner';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _noNet = false;
      _error = null;
    });
    final ok = await Repo.I.ensureSignedIn();
    if (!ok) {
      setState(() {
        _loading = false;
        _noNet = true;
      });
      return;
    }
    Repo.I.startSync();
    if (Repo.I.appPassword == null) await Repo.I.fetchPasswordOnce();
    if (mounted) setState(() => _loading = false);
    if (_role != 'sheikh' && Bio.examinerPass != null) _bioLogin();
  }

  /// الدخول بالبصمة للمختبِر
  Future<void> _bioLogin() async {
    if (!await Bio.auth() || !mounted) return;
    var p = Repo.I.appPassword;
    if (p == null) {
      await Repo.I.fetchPasswordOnce();
      p = Repo.I.appPassword;
    }
    if (p == null || p != Bio.examinerPass) {
      await Bio.setExaminer(null);
      setState(() => _error = 'تغيّرت كلمة السر — أدخلها مرة واحدة لإعادة تفعيل البصمة');
      return;
    }
    _enter();
  }

  void _enter() {
    Repo.I.setLastRole('examiner');
    final next = Repo.I.examinerName == null ? const ExaminerScreen(first: true) : const HomeScreen();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  Future<void> _check() async {
    var p = Repo.I.appPassword;
    if (p == null) {
      await Repo.I.fetchPasswordOnce();
      p = Repo.I.appPassword;
    }
    if (p == null) {
      setState(() => _error = 'لم تُحدَّد كلمة سر التطبيق من الإدارة بعد، أو الجهاز غير متصل. اتصل بالإنترنت وحاول مرة أخرى.');
      return;
    }
    if (_pass.text.trim() != p) {
      setState(() => _error = 'كلمة السر غير صحيحة');
      return;
    }
    if (!mounted) return;
    if (Bio.examinerPass != null) {
      await Bio.setExaminer(p);
    } else if (await offerBio(context)) {
      await Bio.setExaminer(p);
    }
    if (!mounted) return;
    _enter();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_noNet) {
      body = Column(
        children: [
          const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'أول تشغيل للتطبيق يحتاج اتصالاً بالإنترنت لتحميل القوائم.\nبعدها يعمل التطبيق بدون إنترنت.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.7),
          ),
          const SizedBox(height: 20),
          BigButton(icon: Icons.refresh, text: 'إعادة المحاولة', onPressed: _start),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TwoWaySwitch(
            first: 'الاختبارات',
            second: 'التسميع اليومي',
            firstSelected: _role != 'sheikh',
            onChanged: (f) => setState(() {
              _role = f ? 'examiner' : 'sheikh';
              _error = null;
            }),
          ),
          const SizedBox(height: 22),
          if (_role == 'sheikh')
            const SheikhLoginForm()
          else ...[
            if (Bio.examinerPass != null) ...[
              BioButton(onPressed: _bioLogin),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('أو', textAlign: TextAlign.center, style: TextStyle(color: context.sub)),
              ),
            ],
            TextField(
              controller: _pass,
              obscureText: true,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'كلمة السر', prefixIcon: Icon(Icons.lock_outline)),
              onSubmitted: (_) => _check(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: context.badFg, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 18),
            BigButton(icon: Icons.login, text: 'دخول', onPressed: _check, gold: true),
          ],
        ],
      );
    }
    return Scaffold(
      backgroundColor: context.dark ? null : const Color(0xFFFFFDF8),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Stack(children: [
                ListView(
                  children: [
                    const AppHeader(),
                    Padding(padding: const EdgeInsets.fromLTRB(22, 14, 22, 16), child: body),
                  ],
                ),
                PositionedDirectional(
                  top: MediaQuery.of(context).padding.top + 2,
                  end: 4,
                  child: IconTheme(data: IconThemeData(color: context.sub), child: const SettingsButton()),
                ),
              ]),
            ),
            const AyahLine(),
            const DedicationLine(),
          ],
        ),
      ),
    );
  }
}


/// زر الدخول بالبصمة
class BioButton extends StatelessWidget {
  final VoidCallback onPressed;
  const BioButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () {
          haptic();
          onPressed();
        },
        icon: Icon(Icons.fingerprint, size: 26, color: context.ink),
        label: Text('الدخول بالبصمة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.ink)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: context.ink, width: 1.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
}

/// عرض تفعيل البصمة بعد الدخول بكلمة السر (مرة واحدة إذا رفض)
Future<bool> offerBio(BuildContext context) async {
  if (Bio.declined || !await Bio.available() || !context.mounted) return false;
  final r = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(color: ctx.soft, shape: BoxShape.circle),
            child: Icon(Icons.fingerprint, size: 42, color: ctx.ink),
          ),
          const SizedBox(height: 12),
          Text('تفعيل الدخول بالبصمة؟', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ctx.ink)),
          const SizedBox(height: 6),
          Text('في المرات القادمة يكفي وضع الإصبع بدل كتابة كلمة السر.',
              textAlign: TextAlign.center, style: TextStyle(color: ctx.sub, height: 1.6)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: NavyButton(text: 'تفعيل', onPressed: () => Navigator.pop(ctx, true))),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: const Text('لاحقًا'),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
  if (r != true) {
    await Bio.setDeclined(true);
    return false;
  }
  // تأكيد البصمة قبل التفعيل
  return Bio.auth();
}
