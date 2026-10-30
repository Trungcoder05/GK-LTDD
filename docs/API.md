# REST API v1 (đường dẫn không có tiền tố /api)

Mở [Swagger UI](https://gk-ltdd.onrender.com/docs/) để xem danh sách endpoint và thử request trên trình duyệt. OpenAPI JSON: `https://gk-ltdd.onrender.com/openapi.json`. Với endpoint riêng tư, đăng nhập để lấy token rồi bấm **Authorize** và nhập token (không cần thêm tiền tố `Bearer`; Swagger tự thêm). Không nhập token thật trên máy tính công cộng hoặc chia sẻ trang đã đăng nhập.

## Cấu trúc frontend Flutter

Mở thư mục `frontend` trong Android Studio/VS Code. `lib/main.dart` là entry point và nối các phần của ứng dụng thành một Dart library bằng `part`:

| File | Nội dung |
|---|---|
| `lib/main.dart` | Imports, entry point và liên kết các phần |
| `lib/app_theme.dart` | Theme, biểu trưng, màu dùng chung, trường nhập và thông báo |
| `lib/auth_page.dart` | Đăng ký email, đăng nhập OTP, chọn Google native và mở phiên khuôn mặt/vân tay |
| `lib/home_page.dart` | Điều hướng, hồ sơ tài khoản, dashboard, phân quyền và CRUD hồ sơ trẻ |
| `lib/child_page.dart` | Chi tiết hồ sơ, thiết bị, thỏa thuận, NFC và lịch sử check-in |
| `lib/location_card.dart` | Chia sẻ vị trí có đồng ý, xem vị trí gần nhất và ngừng/xóa |
| `lib/api.dart` | REST client HTTPS, token và lưu trữ an toàn |
| `lib/fingerprint.dart` | Kiểm tra và xác thực khuôn mặt/vân tay trên thiết bị |

Các màn hình gọi API HTTPS trong bảng bên dưới; Node.js backend dùng chung, không cần viết lại để thay giao diện. Không xóa `part` hoặc đổi tên file nếu chưa cập nhật các liên kết tương ứng trong `main.dart`.

Base URL là HTTPS Render của nhóm. JSON request/response. Sau đăng nhập gửi `Authorization: Bearer TOKEN`. Lỗi: `{"message":"..."}`; dữ liệu sai trả 400, chưa đăng nhập 401, thiếu quyền 403, không sở hữu/không tồn tại 404, trùng 409. OTP không trả ra response.

| Method | Path | Dữ liệu / quyền |
|---|---|---|
| GET | /health | Kiểm tra DB, không cần token |
| POST | /auth/register | email, username, name, password → challengeId |
| POST | /auth/login | username (hoặc email), password → challengeId |
| POST | /auth/otp | challengeId, code → token, user |
| GET | /auth/google/start | query verifierHash = SHA256(verifier) |
| GET | /auth/google/callback | Google redirect, không gọi thủ công |
| POST | /auth/google/exchange | code, verifier → token, user |
| GET | /me | Thông tin user hiện tại |
| PATCH | /me | name (2–80 ký tự) → cập nhật tên hiển thị |
| GET, POST | /children | List gia đình; POST: name, age (1–17), daily_limit (15–1440), parent |
| PUT, DELETE | /children/:id | Sửa đầy đủ name/age/daily_limit hoặc xóa, parent sở hữu |
| POST | /children/:id/link | email trẻ đã verified và role child, parent sở hữu |
| GET, POST | /children/:id/devices | GET chủ sở hữu/trẻ liên kết; POST name, parent |
| PUT, DELETE | /devices/:id | PUT name, DELETE; parent sở hữu |
| GET, POST | /children/:id/agreements | POST title, reward (1–120); parent/trẻ liên kết |
| PATCH | /agreements/:id | status: approved/rejected; parent sở hữu |
| DELETE | /agreements/:id | parent sở hữu |
| PUT | /children/:id/nfc | tagHash (SHA256 UID bytes), parent sở hữu |
| POST | /children/:id/checkins | tagHash; parent/trẻ liên kết; phải khớp thẻ đã gắn |
| GET | /children/:id/checkins | 50 lượt gần nhất, chủ sở hữu/trẻ liên kết |
| GET | /children/:id/location | Vị trí đã chia sẻ; phụ huynh sở hữu hoặc trẻ liên kết |
| PUT | /children/:id/location | latitude, longitude, accuracy; chỉ tài khoản child đã liên kết |
| DELETE | /children/:id/location | Xóa vị trí; chỉ tài khoản child đã liên kết |
| GET | /staff/dashboard | users, children, devices (count); staff/admin |
| GET | /admin/users | Tối đa 200 user; admin |
| PATCH | /admin/users/:id/role | role: parent/child/staff; admin; không tự đổi mình hoặc admin khác |

Ví dụ tạo trẻ sau khi lấy token:

```http
POST /children HTTP/1.1
Authorization: Bearer TOKEN
Content-Type: application/json

{"name":"An","age":9,"daily_limit":90}
```

Token không chứa mật khẩu. Backend đọc role hiện tại từ database nên thay quyền có hiệu lực trên yêu cầu tiếp theo. Đăng xuất xóa token phiên trong bộ nhớ; token mở phiên sinh trắc học được giữ an toàn trên máy, gắn với đúng tài khoản đến khi hết hạn hoặc người dùng tắt sinh trắc học. Token sao chép trước đó còn hiệu lực đến hết hạn (chưa có revocation server). Staff không có endpoint đọc danh sách trẻ hoặc dữ liệu riêng của phụ huynh khác.

Vị trí chỉ được lấy sau khi trẻ bấm chia sẻ và cấp quyền vị trí khi ứng dụng đang dùng. Không có theo dõi nền. Phụ huynh liên kết có thể xem vị trí và mở bản đồ; chỉ tài khoản trẻ liên kết mới được gửi hoặc xóa vị trí. Bảng `shared_locations` được tạo tự động khi backend khởi động.
