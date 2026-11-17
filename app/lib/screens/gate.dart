import 'package:flutter/material.dart';

import '../repo.dart';
import 'examiner.dart';
import 'home.dart';
import 'widgets.dart';

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
    final next = Repo.I.examinerName == null ? const ExaminerScreen(first: true) : const HomeScreen();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: ListView(
          children: [
            const AppHeader(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _noNet
                      ? Column(
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
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('اختبارات الحفظ',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brandGreen)),
                            const SizedBox(height: 20),
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
                                child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                              ),
                            const SizedBox(height: 20),
                            BigButton(icon: Icons.login, text: 'دخول', onPressed: _check),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
