import 'package:flutter/material.dart';

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
            padding: const EdgeInsets.all(16),
            children: [
              const Text('اختر اسمك من القائمة:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (snap.connectionState == ConnectionState.waiting && names.isEmpty)
                const Center(child: CircularProgressIndicator()),
              for (final n in names)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(n),
                    trailing: n == current ? const Icon(Icons.check_circle, color: Colors.green) : null,
                    onTap: () => _choose(n),
                  ),
                ),
              const SizedBox(height: 20),
              const Text('أو اكتب اسمك:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم المختبر'),
                onSubmitted: _choose,
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => _choose(_name.text), child: const Text('متابعة')),
            ],
          );
        },
      ),
    );
  }
}
