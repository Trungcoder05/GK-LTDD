import 'package:flutter_test/flutter_test.dart';
import 'package:ngo_khac_trung_0354121528/main.dart';

void main() {
  testWidgets(
    'Login exposes OTP, Google and biometric sign-in; registration can be opened',
    (tester) async {
      await tester.pumpWidget(const AnTamSo());
      expect(find.text('An Tâm Số'), findsOneWidget);
      expect(find.text('Đăng nhập với OTP'), findsOneWidget);
      expect(find.text('Tiếp tục với Google'), findsOneWidget);
      expect(find.text('Mở phiên bằng sinh trắc học'), findsOneWidget);
      await tester.ensureVisible(find.text('Chưa có tài khoản? Đăng ký'));
      await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
      await tester.pumpAndSettle();
      expect(find.text('Tạo tài khoản gia đình'), findsOneWidget);
      expect(find.text('Địa chỉ email'), findsOneWidget);
    },
  );
}
