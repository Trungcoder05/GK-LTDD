import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

/// Uses only biometric methods that Android reports as enrolled and available.
class FingerprintAuth {
  final LocalAuthentication _auth = LocalAuthentication();
  Future<bool> available() async {
    final types = await _auth.getAvailableBiometrics();
    return types.isNotEmpty;
  }

  Future<bool> authenticate(BuildContext context) async {
    if (!await available()) {
      throw Exception(
        'Thiết bị chưa có sinh trắc học được ứng dụng hỗ trợ. Hãy đăng nhập bằng OTP.',
      );
    }
    return _auth.authenticate(
      localizedReason: 'Dùng sinh trắc học để mở phiên An Tâm Số',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
  }
}
