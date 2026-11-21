import 'package:flutter/material.dart';

import 'ui.dart';
import 'widgets.dart';

import '../repo.dart';
import 'home.dart';

/// اختيار اسم المختبر (من القائمة أو كتابته)
class ExaminerScreen extends StatefulWidget {
  final bool first;
  const ExaminerScreen({super.key, this.first = false});

  @override
  State<ExaminerScreen> createState() => _ExaminerScreenState();
}

class _ExaminerScreenState extends State<ExaminerScreen> {
  final _name = TextEditingController();

  Future<void> _choose(String name) async {
    name = name.trim();
    if (name.isEmpty) return;
    await Repo.I.setExaminerName(name);
    if (!mounted) return;
    if (widget.first) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = Repo.I.examinerName;
    return Scaffold(
      appBar: AppBar(title: const BrandTitle('اسم المختبر')),
      body: StreamBuilder<List<String>>(
        stream: Repo.I.examiners(),
        builder: (context, snap) {
          final names = snap.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              SectionLabel('اختر اسمك من القائمة', color: context.ink),
              if (snap.connectionState == ConnectionState.waiting && names.isEmpty)
                const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
              for (final n in names)
                Panel(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  borderColor: n == current ? context.accent : null,
                  onTap: () => _choose(n),
                  child: Row(children: [
                    NameAvatar(n, color: n == current ? brandBlue : null, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(n, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.ink))),
                    if (n == current) Icon(Icons.check_circle_rounded, color: context.okFg),
                  ]),
                ),
              SectionLabel('أو اكتب اسمك', color: context.ink),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم المختبر', prefixIcon: Icon(Icons.edit_rounded)),
                onSubmitted: _choose,
              ),
              const SizedBox(height: 14),
              GoldButton(text: 'متابعة', onPressed: () => _choose(_name.text)),
            ],
          );
        },
      ),
    );
  }
}
