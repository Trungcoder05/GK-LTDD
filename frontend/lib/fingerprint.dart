import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

/// Selects an enrolled biometric type before opening Android's system prompt.
class FingerprintAuth {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<List<BiometricType>> availableMethods() async {
    final types = await _auth.getAvailableBiometrics();
    final specificTypes = [
      if (types.contains(BiometricType.face)) BiometricType.face,
      if (types.contains(BiometricType.fingerprint)) BiometricType.fingerprint,
    ];
    if (specificTypes.isNotEmpty) return specificTypes;
    if (types.contains(BiometricType.strong)) return [BiometricType.strong];
    if (types.contains(BiometricType.weak)) return [BiometricType.weak];
    return [];
  }

  Future<BiometricType> chooseMethod(BuildContext context) async {
    final methods = await availableMethods();
    if (methods.isEmpty) {
      throw Exception(
        'Thiết bị chưa đăng ký khuôn mặt hoặc vân tay. Hãy đăng nhập bằng OTP.',
      );
    }
    if (!context.mounted) {
      throw Exception('Màn hình đã đóng trước khi chọn sinh trắc học.');
    }

    final selected = await showModalBottomSheet<BiometricType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                child: Text(
                  'Chọn cách xác thực',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final method in methods)
                ListTile(
                  leading: Icon(
                    switch (method) {
                      BiometricType.face => Icons.face_retouching_natural,
                      BiometricType.fingerprint => Icons.fingerprint_rounded,
                      _ => Icons.fingerprint_rounded,
                    },
                  ),
                  title: Text(_label(method)),
                  subtitle: const Text('Tiếp tục bằng xác thực của Android'),
                  onTap: () => Navigator.pop(context, method),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Text(
                  'Android mở hộp xác thực hệ thống; cảm biến thực tế có thể do thiết bị quyết định.',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null) {
      throw Exception('Đã hủy chọn phương thức sinh trắc học.');
    }
    return selected;
  }

  Future<bool> authenticate(BuildContext context, BiometricType method) async {
    if (!(await availableMethods()).contains(method)) {
      throw Exception(
        '${_label(method)} chưa được đăng ký hoặc không được thiết bị hỗ trợ.',
      );
    }
    return _auth.authenticate(
      localizedReason: 'Xác thực bằng ${_label(method)} để mở phiên An Tâm Số',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
  }

  String _label(BiometricType method) => switch (method) {
    BiometricType.face => 'Khuôn mặt',
    BiometricType.fingerprint => 'Vân tay',
    BiometricType.strong || BiometricType.weak =>
      'Sinh trắc học (thiết bị tự chọn)',
    _ => 'Sinh trắc học',
  };

  String methodKey(BiometricType method) => switch (method) {
    BiometricType.face => 'face',
    BiometricType.fingerprint => 'fingerprint',
    BiometricType.strong => 'strong',
    BiometricType.weak => 'weak',
    _ => 'biometric',
  };
}
