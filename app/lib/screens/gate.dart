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
  bool _bioAvail = false, _bioWant = false, _showPass = false, _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    Bio.available().then((v) {
      if (mounted) setState(() => _bioAvail = v);
    });
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
    if (Repo.I.appPassword == null && !Repo.I.secReady) await Repo.I.fetchPasswordOnce();
    Repo.I.verifyDevice(); // بالخلفية: لا ننتظر السيرفر عند فتح التطبيق
    if (mounted) setState(() => _loading = false);
    if (_role != 'sheikh' && Bio.examinerPass != null) _bioLogin();
  }

  /// الدخول بالبصمة للمختبِر
  Future<void> _bioLogin() async {
    if (!await Bio.auth() || !mounted) return;
    setState(() => _busy = true);
    final err = await examinerLogin(Bio.examinerPass ?? '');
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      if (err != offlineFirstMsg) await Bio.setExaminer(null);
      setState(() {
        _showPass = true;
        _error = err == offlineFirstMsg ? err : 'تغيّرت كلمة السر — أدخلها مرة واحدة لإعادة تفعيل البصمة';
      });
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
    final p = _pass.text.trim();
    if (p.isEmpty) {
      setState(() => _error = 'أدخل كلمة السر');
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await examinerLogin(p);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (Bio.examinerPass != null || (_bioAvail && _bioWant)) await Bio.setExaminer(p);
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
            'أول تشغيل للتطبيق يحتاج اتصالًا بالإنترنت لتحميل القوائم.\nبعدها يعمل التطبيق بدون إنترنت.',
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
          else if (Bio.examinerPass != null && !_showPass)
            BioPad(onTap: _bioLogin, passText: 'الدخول بكلمة السر', onPassword: () => setState(() => _showPass = true))
          else ...[
            TextField(
              controller: _pass,
              obscureText: true,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'كلمة السر', prefixIcon: Icon(Icons.lock_outline)),
              onSubmitted: (_) => _check(),
            ),
            if (_bioAvail && Bio.examinerPass == null) BioCheck(value: _bioWant, onChanged: (v) => setState(() => _bioWant = v)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: context.badFg, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 18),
            _busy
                ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                : BigButton(icon: Icons.login, text: 'دخول', onPressed: _check, gold: true),
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


/// شاشة البصمة: رمز كبير للمس، ورابط للدخول بكلمة السر
class BioPad extends StatelessWidget {
  final VoidCallback onTap, onPassword;
  final String passText;
  const BioPad({super.key, required this.onTap, required this.onPassword, required this.passText});

  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: 18),
        Material(
          color: context.soft,
          shape: CircleBorder(side: BorderSide(color: context.line, width: 2)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              haptic();
              onTap();
            },
            child: SizedBox(width: 118, height: 118, child: Icon(Icons.fingerprint, size: 70, color: context.ink)),
          ),
        ),
        const SizedBox(height: 14),
        Text('المس للدخول', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.ink)),
        const SizedBox(height: 2),
        Text('ضع إصبعك على مستشعر الجوال', style: TextStyle(color: context.sub, fontSize: 13)),
        const SizedBox(height: 30),
        TextButton(
          onPressed: onPassword,
          child: Text(passText, style: TextStyle(color: context.accent, fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ]);
}

/// خيار «الدخول بالبصمة في المرات القادمة» تحت كلمة السر
class BioCheck extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const BioCheck({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onChanged(!value),
          child: Row(children: [
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false), activeColor: context.chosen),
            Expanded(child: Text('الدخول بالبصمة في المرات القادمة', style: TextStyle(color: context.txt, fontSize: 14))),
          ]),
        ),
      );
}


const offlineFirstMsg = 'لا يوجد اتصال بالإنترنت — أول دخول على هذا الجوال يحتاج اتصالًا';

/// دخول المختبر: يعيد null عند النجاح أو رسالة الخطأ
Future<String?> examinerLogin(String p) async {
  if (p.isEmpty) return 'كلمة السر غير صحيحة';
  // جهاز معتمد بنفس كلمة السر ← دخول فوري (يعمل بدون إنترنت)
  if (Repo.I.deviceOk && p == Repo.I.verifiedPass) {
    Repo.I.touchDevice();
    return null;
  }
  // بدون إنترنت لا ننتظر السيرفر
  final r = NetWatcher.I.online ? await Repo.I.registerDevice(pass: p, name: Repo.I.examinerName) : 'offline';
  if (r == 'ok') return null;
  // قبل تفعيل الحماية: كلمة السر القديمة المحفوظة على الجهاز
  final legacy = Repo.I.appPassword;
  if (legacy != null && p == legacy && (r == 'offline' || !Repo.I.secReady)) return null;
  if (r == 'offline') return (Repo.I.deviceOk || legacy != null) ? 'كلمة السر غير صحيحة' : offlineFirstMsg;
  return 'كلمة السر غير صحيحة';
}

/// دخول الشيخ: يعيد null عند النجاح أو رسالة الخطأ
Future<String?> sheikhLogin(String sheikhId, String pin, {String? legacyPin, String? name}) async {
  if (pin.isEmpty) return 'رمز الدخول غير صحيح';
  if (Repo.I.deviceOk && Repo.I.verifiedSheikh == sheikhId && Repo.I.verifiedPin == pin) {
    Repo.I.touchDevice();
    return null;
  }
  final r = NetWatcher.I.online ? await Repo.I.registerDevice(sheikhId: sheikhId, pin: pin, name: name) : 'offline';
  if (r == 'ok') return null;
  final hasLegacy = legacyPin != null && legacyPin.isNotEmpty;
  if (hasLegacy && pin == legacyPin && (r == 'offline' || !Repo.I.secReady)) return null;
  if (r == 'offline' && !hasLegacy) return 'لا يوجد اتصال بالإنترنت — أول دخول لهذا الحساب على هذا الجوال يحتاج اتصالًا';
  return 'رمز الدخول غير صحيح';
}
