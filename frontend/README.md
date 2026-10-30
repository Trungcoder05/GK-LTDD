# ngo_khac_trung_2380602361_nhom4 — An Tâm Số

Ứng dụng Flutter quản lý hồ sơ thiết bị trẻ em, kế hoạch thời gian số và thỏa thuận gia đình.

## Chạy ứng dụng

Từ thư mục này, lấy URL HTTPS backend đã deploy rồi chạy:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=https://TEN-SERVICE.onrender.com
```

Ứng dụng hiện dùng API Render `https://gk-ltdd.onrender.com`. Mật khẩu/OTP, hồ sơ và các tính năng sinh trắc học/cài đặt dùng backend này.

Sau khi ứng dụng ở nền hơn 30 giây, phiên sẽ bị khóa. Đăng nhập lại bằng email/OTP hoặc sinh trắc học nếu đã bật; email tài khoản gần nhất được điền sẵn, mật khẩu không được lưu.

Backend gửi OTP email qua Resend; trên Render cần có `MAIL_PROVIDER=resend`, `RESEND_API_KEY` và `MAIL_FROM`.

Để bật Google OAuth:

1. Tạo OAuth Client loại **Web application** trong Google Cloud Console.
2. Thêm Authorized redirect URI chính xác: `https://gk-ltdd.onrender.com/auth/google/callback`.
3. Thêm `GOOGLE_CLIENT_ID` và `GOOGLE_CLIENT_SECRET` vào **Render → LTDD → Environment**, rồi lưu và deploy lại.

Backend tự nhận URL Render làm callback; không cần đặt `PUBLIC_URL`. Nếu đổi tên service, cập nhật URL mặc định ở `lib/api.dart` và redirect URI trong Google Cloud Console.
