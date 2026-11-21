import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../repo.dart';
import '../update_check.dart';
import 'examiner.dart';
import 'guide.dart';
import 'my_exams.dart';
import 'new_exam.dart';
import 'ready.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkForUpdate(context));
    ReadyWatcher.I.start();
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.person, color: brandGreen),
                      title: const Text('المختبر'),
                      subtitle: Text(Repo.I.examinerName ?? '',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      trailing: TextButton(
                        child: const Text('تغيير'),
                        onPressed: () async {
                          await Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => const ExaminerScreen()));
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const ReadyCard(),
                  const SizedBox(height: 14),
                  BigButton(
                    icon: Icons.add_circle_outline,
                    text: 'اختبار جديد',
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewExamScreen())),
                  ),
                  const SizedBox(height: 14),
                  BigButton(
                    icon: Icons.list_alt,
                    text: 'الاختبارات',
                    filled: false,
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyExamsScreen())),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GuideScreen())),
                    child: const Text('نظام الاختبارات ومسار الحفظ', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                  const SyncStatus(),
                  const SizedBox(height: 16),
                  const AyahLine(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// حالة رفع الاختبارات
class SyncStatus extends StatelessWidget {
  const SyncStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: Repo.I.myExams(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs;
        final pending = docs.where((d) => d.metadata.hasPendingWrites).length;
        final ok = pending == 0;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ok ? const Color(0xFFE6F2FA) : const Color(0xFFFFF4DE),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(ok ? Icons.cloud_done : Icons.cloud_upload,
                  color: ok ? brandGreen : const Color(0xFF9A6700)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ok
                      ? 'كل الاختبارات مرفوعة (${docs.length})'
                      : 'بانتظار الرفع: $pending اختبار — تُرفع تلقائياً عند الاتصال بالإنترنت',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
