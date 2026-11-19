import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'env.dart';

/// يفحص إذا في نسخة كاملة جديدة من التطبيق على GitHub (للتحديثات التي تحتاج تنزيل)
/// التحديثات العادية تصل تلقائياً عبر Shorebird بدون تنزيل.
const _latestUrl = 'https://api.github.com/repos/MohammedFSharaf/taqwa-exams/releases/latest';
const _releasesUrl = 'https://api.github.com/repos/MohammedFSharaf/taqwa-exams/releases';

bool _checked = false;

Future<void> checkForUpdate(BuildContext context) async {
  if (_checked) return;
  _checked = true;
  try {
    final info = await PackageInfo.fromPlatform();
    final current = int.tryParse(info.buildNumber) ?? 0;
    // النسخة التجريبية تتابع الإصدارات التجريبية (beta-N)، والأصلية تتابع آخر إصدار رسمي (build-N)
    final res = await http
        .get(Uri.parse(kBeta ? '$_releasesUrl?per_page=20' : _latestUrl))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return;
    Map<String, dynamic>? data;
    final prefix = kBeta ? 'beta-' : 'build-';
    if (kBeta) {
      for (final r in (jsonDecode(res.body) as List)) {
        if (r is Map<String, dynamic> && (r['tag_name'] ?? '').toString().startsWith(prefix)) {
          data = r;
          break;
        }
      }
    } else {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    }
    if (data == null) return;
    final tag = (data['tag_name'] ?? '').toString();
    if (!tag.startsWith(prefix)) return;
    final latest = int.tryParse(tag.substring(prefix.length)) ?? 0;
    if (latest <= current) return;
    final assets = (data['assets'] as List?) ?? [];
    if (assets.isEmpty) return;
    final url = (assets.first as Map)['browser_download_url'].toString();
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(kBeta ? 'نسخة تجريبية جديدة' : 'نسخة جديدة من التطبيق'),
        content: const Text('توجد نسخة جديدة من التطبيق تحتاج تنزيلاً. اضغط "تنزيل" ثم ثبّت الملف.\nبياناتك المحفوظة لن تُحذف.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لاحقاً')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            child: const Text('تنزيل'),
          ),
        ],
      ),
    );
  } catch (_) {
    // بدون إنترنت أو أي خطأ: نتجاهل بهدوء
  }
}
