import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

import 'repo.dart';

/// الدخول بالبصمة (لهذا الجهاز فقط)
class Bio {
  static final _la = LocalAuthentication();

  /// هل في الجهاز بصمة مسجّلة
  static Future<bool> available() async {
    try {
      if (!await _la.isDeviceSupported()) return false;
      if (!await _la.canCheckBiometrics) return false;
      return (await _la.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> auth() async {
    try {
      return await _la.authenticate(
        localizedReason: 'ضع إصبعك على مستشعر البصمة',
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'تأكيد الدخول',
            biometricHint: '',
            cancelButton: 'استخدام كلمة السر',
            biometricNotRecognized: 'لم تُعرف البصمة، حاول مرة أخرى',
            biometricSuccess: 'تم',
            biometricRequiredTitle: 'البصمة غير مفعّلة',
            goToSettingsButton: 'الإعدادات',
            goToSettingsDescription: 'لا توجد بصمة مسجّلة على الجوال. أضفها من إعدادات الجوال.',
          ),
        ],
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }

  // ----- المختبِر: نحفظ كلمة السر التي دخل بها، ونتحقق أنها ما تغيّرت -----
  static String? get examinerPass => Repo.I.prefs.getString('bio_examiner');
  static Future<void> setExaminer(String? pass) =>
      pass == null ? Repo.I.prefs.remove('bio_examiner') : Repo.I.prefs.setString('bio_examiner', pass);

  // ----- الشيخ: حسابه ورمزه -----
  static String? get sheikhId => Repo.I.prefs.getString('bio_sheikh_id');
  static String? get sheikhPin => Repo.I.prefs.getString('bio_sheikh_pin');
  static Future<void> setSheikh(String? id, String? pin) async {
    if (id == null || pin == null) {
      await Repo.I.prefs.remove('bio_sheikh_id');
      await Repo.I.prefs.remove('bio_sheikh_pin');
    } else {
      await Repo.I.prefs.setString('bio_sheikh_id', id);
      await Repo.I.prefs.setString('bio_sheikh_pin', pin);
    }
  }

  static bool get enabled => examinerPass != null || sheikhId != null;
  static Future<void> disableAll() async {
    await setExaminer(null);
    await setSheikh(null, null);
    await Repo.I.prefs.remove('bio_declined');
  }

  /// رفض العرض (لا نسأله كل مرة)
  static bool get declined => Repo.I.prefs.getBool('bio_declined') ?? false;
  static Future<void> setDeclined(bool v) => Repo.I.prefs.setBool('bio_declined', v);
}
