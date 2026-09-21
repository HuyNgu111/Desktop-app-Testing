# 🔐 Hướng Dẫn Cấu Hình API Key (Bảo Mật Dự Án)

Để đảm bảo tính bảo mật và tuân thủ các quy tắc an toàn thông tin (tránh rò rỉ mã bí mật lên GitHub công khai), dự án **CapReview** không lưu trữ trực tiếp API Key trong mã nguồn được đẩy lên repository.

Hệ thống quản lý phiên bản Git đã được cấu hình tự động bỏ qua (ignore) file chứa API Key thông qua `.gitignore`.

---

## ⚠️ Cơ chế bảo mật qua `.gitignore`

File **`lib/services/api_key.dart`** đã được khai báo trong `.gitignore`:
```gitignore
# Giấu API Key
lib/services/api_key.dart
Điều này có nghĩa:
Khi bạn git add . hoặc git push, file này sẽ không bao giờ được tải lên GitHub.
Khi một thành viên khác git clone hoặc git pull nhánh này về máy, file này sẽ không tồn tại sẵn và cần được khởi tạo thủ công theo hướng dẫn bên dưới để ứng dụng có thể kết nối với AI.
🛠️ Hướng dẫn thiết lập API Key để chạy ứng dụng cục bộ (Local)
Khi mới tải (clone) dự án về máy, bạn cần tạo file cấu hình key theo các bước sau:
Bước 1: Tạo file cấu hình
Điều hướng vào thư mục lib/services/ và tạo một file mới có tên là:
code
Text
lib/services/api_key.dart
Bước 2: Dán nội dung mẫu
Mở file api_key.dart vừa tạo và dán đoạn mã sau:
code
Dart
// File này dùng để lưu trữ API Key cá nhân của bạn
// KHÔNG BAO GIỜ xóa dòng khai báo file này trong .gitignore!

const String deepseekApiKey = 'DÁN_API_KEY_DEEPSEEK_CỦA_BẠN_VÀO_ĐÂY';
Bước 3: Điền API Key của bạn
Lấy mã API Key từ DeepSeek Platform.
Thay thế chuỗi 'DÁN_API_KEY_DEEPSEEK_CỦA_BẠN_VÀO_ĐÂY' bằng key thật của bạn (dạng sk-...).
Nhấn Ctrl + S để lưu file.
🚀 Khởi chạy ứng dụng
Sau khi hoàn tất việc tạo file api_key.dart, bạn có thể chạy ứng dụng bình thường bằng lệnh:
code
Bash
flutter pub get
flutter run -d windows
Nếu gặp bất kỳ lỗi nào liên quan đến việc không tìm thấy deepseekApiKey, hãy kiểm tra lại xem tên file và đường dẫn đã chính xác là lib/services/api_key.dart hay chưa.