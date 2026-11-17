import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../logic.dart';
import '../repo.dart';
import 'widgets.dart';

/// الاختبارات التي سجّلها هذا الجهاز وحالة رفعها
class MyExamsScreen extends StatelessWidget {
  const MyExamsScreen({super.key});

  static String resultText(Map<String, dynamic> e) =>
      e['closed'] == true ? 'راسب – أُغلق' : (e['passed'] == true ? 'ناجح' : 'راسب');

  void _details(BuildContext context, Map<String, dynamic> e) {
    final qs = (e['questions'] as List?) ?? [];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e['studentName'] ?? ''),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${examTypes[e['type']] ?? ''}${e['isRetest'] == true ? ' (إعادة)' : ''}'),
              Text(juzLabel(e['startJuz'] ?? 1, e['endJuz'] ?? 1)),
              Text('${e['createdAtText'] ?? ''}'),
              Text('الحلقة: ${e['halaqaName'] ?? ''}'),
              const Divider(),
              for (var i = 0; i < qs.length; i++)
                Text(qs[i] == null
                    ? 'السؤال ${i + 1}: —'
                    : 'السؤال ${i + 1}: ${fmt(qs[i]['score'])}  (أخطاء ${qs[i]['errors']}، تنبيهات ${qs[i]['alerts']})'),
              if (e['closed'] != true) ...[
                Text('أحكام التجويد: ${fmt(e['tajweed'])}'),
                Text('الأداء: ${fmt(e['performance'])}'),
                Text('المجموع: ${fmt(e['total'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
              Text('النتيجة: ${resultText(e)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (e['closeReason'] != null) Text('${e['closeReason']}'),
              if ((e['notes'] ?? '').toString().isNotEmpty) ...[
                const Divider(),
                Text('ملاحظات: ${e['notes']}'),
              ],
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اختباراتي')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: Repo.I.myExams(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('تعذّر عرض الاختبارات'));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = [...snap.data!.docs];
          docs.sort((a, b) {
            final ta = a.data()['createdAt'], tb = b.data()['createdAt'];
            if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
            return 0;
          });
          if (docs.isEmpty) {
            return const Center(child: Text('لا توجد اختبارات بعد', style: TextStyle(color: Colors.grey)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final e = docs[i].data();
              final pending = docs[i].metadata.hasPendingWrites;
              final passed = e['passed'] == true;
              return Card(
                child: ListTile(
                  onTap: () => _details(context, e),
                  leading: Icon(pending ? Icons.cloud_upload : Icons.cloud_done,
                      color: pending ? const Color(0xFF9A6700) : brandGreen),
                  title: Text('${e['studentName'] ?? ''}${e['isRetest'] == true ? ' (إعادة)' : ''}'),
                  subtitle: Text('${examTypes[e['type']] ?? ''} · ${e['createdAtText'] ?? ''}'
                      '${pending ? '\nبانتظار الرفع' : ''}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (e['closed'] != true)
                        Text(fmt(e['total']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(resultText(e),
                          style: TextStyle(color: passed ? brandGreen : Colors.red.shade700, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
