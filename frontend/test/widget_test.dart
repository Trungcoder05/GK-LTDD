import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngo_khac_trung_0354121528/main.dart';

void main() {
  final secureValues = <String, String>{};

  setUp(() {
    secureValues.clear();
    api.token = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final arguments = Map<String, dynamic>.from(call.arguments as Map);
            switch (call.method) {
              case 'read':
                return secureValues[arguments['key']];
              case 'write':
                secureValues[arguments['key'] as String] =
                    arguments['value'] as String;
                return null;
              case 'delete':
                secureValues.remove(arguments['key']);
                return null;
              default:
                return null;
            }
          },
        );
  });

  testWidgets('Login remembers the account and enabled biometric session', (
    tester,
  ) async {
    secureValues['remembered_account'] = 'parent@example.com';
    secureValues['biometric_token'] = 'saved-token';

    await tester.pumpWidget(const AnTamSo());
    await tester.pumpAndSettle();

    expect(find.text('An Tâm Số'), findsOneWidget);
    expect(find.text('Đăng nhập với OTP'), findsOneWidget);
    expect(find.text('Tiếp tục với Google'), findsOneWidget);
    expect(find.text('Mở phiên bằng khuôn mặt / vân tay'), findsOneWidget);
    final usernameField = tester
        .widgetList<TextField>(find.byType(TextField))
        .first;
    expect(usernameField.controller?.text, 'parent@example.com');
    await tester.ensureVisible(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();
    expect(find.text('Tạo tài khoản gia đình'), findsOneWidget);
    expect(find.text('Địa chỉ email'), findsOneWidget);
  });

  testWidgets('Expired background session requires sign-in again', (
    tester,
  ) async {
    secureValues['session_token'] = 'expired-session';
    secureValues['session_user_id'] = 'user-id';
    secureValues['remembered_account'] = 'parent@example.com';
    secureValues['app_backgrounded_at'] = DateTime.now()
        .subtract(sessionTimeout + const Duration(seconds: 1))
        .millisecondsSinceEpoch
        .toString();

    await tester.pumpWidget(const AnTamSo());
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Phiên đã khóa vì bạn rời ứng dụng quá 30 giây. Đăng nhập lại bằng email/OTP hoặc sinh trắc học.',
      ),
      findsOneWidget,
    );
    expect(secureValues.containsKey('session_token'), isFalse);
    expect(secureValues['remembered_account'], 'parent@example.com');
  });
}
