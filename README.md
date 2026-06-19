# 🌲 QLR Forest Mobile & Web Dashboard

Hệ thống quản lý dữ liệu rừng toàn diện, bao gồm nhật ký tuần tra rừng hiện trường, Check-in định vị GPS, quản lý hình ảnh hiện thực và giám sát dự án tín chỉ Carbon. 

Dự án đã được chuyển đổi hoàn toàn kiến trúc từ **Firebase** sang **Supabase** cho cả ứng dụng **Mobile Flutter** và trang quản trị **Web Dashboard**.

---

## ⚡ Các Tính Năng Chính

* **Mobile App (Flutter)**:
  * Đăng nhập & phân quyền với Supabase Auth.
  * Check-in hiện trường gửi tọa độ GPS lên hệ thống.
  * Tạo nhật ký tuần tra rừng (Logbook) kèm mô tả công việc, tọa độ thực tế.
  * Tải ảnh trực tiếp lên **Supabase Storage** (bucket `logbook-images`) và lưu liên kết URL.
  * Kiến trúc ứng dụng chuẩn **Clean Architecture** kết hợp state management **BLoC**.
* **Web Dashboard (HTML/JS/CSS)**:
  * Giao diện Dashboard trực quan, hiển thị tổng quan số liệu tài nguyên rừng và dự án.
  * Đăng nhập thông qua Supabase Auth, tự động đồng bộ vai trò người dùng (`profiles`).
  * Xem danh sách logbook kèm hình ảnh chụp từ thực địa.
  * Phê duyệt / từ chối các dự án Carbon mới đăng ký.
  * Chế độ **Fallback Demo/Offline** tự động kích hoạt nếu kết nối Supabase gặp sự cố, đảm bảo hiển thị dữ liệu mẫu mượt mà.
* **Database & Security**:
  * Tự động kiểm tra ràng buộc tỉnh thành và diện tích bằng trigger Postgres (`validate_project_owner_area_and_province`).
  * Cơ chế bảo mật dữ liệu cấp dòng **Row Level Security (RLS)** trên Supabase, đảm bảo vai trò nào chỉ truy cập đúng dữ liệu của vai trò đó.

---

## 🛠️ Hướng Dẫn Cài Đặt Hệ Thống Supabase

Để chạy ứng dụng với cơ sở dữ liệu Supabase của riêng bạn, hãy làm theo các bước hướng dẫn chi tiết dưới đây:

### Bước 1: Khởi Tạo Dự Án Trên Supabase
1. Truy cập [Supabase Dashboard](https://supabase.com) và tạo một dự án (Project) mới.
2. Lấy thông tin **Project URL** và **Anon Key (API Key)** tại mục **Project Settings > API**.

### Bước 2: Thiết Lập Database Schema
1. Đi tới mục **SQL Editor** trong Supabase Dashboard.
2. Nhấp vào **New Query**, copy toàn bộ nội dung trong file [supabase_schema.sql](file:///d:/DT/cuoiki/flutter-supervisor-forest-main/flutter-supervisor-forest-main/supabase_schema.sql) và dán vào cửa sổ.
3. Bấm **Run** để khởi tạo các bảng, quan hệ, RLS policies, trigger kiểm tra và bucket `logbook-images`.

### Bước 3: Tạo Tài Khoản Demo (Supabase Auth)
Đi tới mục **Authentication > Users** trên Supabase Dashboard và nhấp **Add User > Create User** để tạo 3 tài khoản thử nghiệm sau:

| Email | Mật khẩu | Vai trò (Role) | Mô tả |
| :--- | :--- | :--- | :--- |
| `admin@qlr.vn` | `123456` | **admin** | Quản trị viên toàn hệ thống, toàn quyền đọc/ghi. |
| `owner@qlr.vn` | `123456` | **owner** | Chủ rừng, quản lý dự án carbon và các lô rừng thuộc sở hữu. |
| `worker@qlr.vn` | `123456` | **worker** | Nhân viên kiểm lâm hiện trường, tạo check-in và logbook tuần tra. |

### Bước 4: Chạy Seed Dữ Liệu Mẫu
1. Sau khi tạo xong 3 tài khoản ở Bước 3, sao chép (copy) **User ID (UUID)** của từng tài khoản từ bảng danh sách Users.
2. Mở file [supabase_seed.sql](file:///d:/DT/cuoiki/flutter-supervisor-forest-main/flutter-supervisor-forest-main/supabase_seed.sql) và thay thế các giá trị UUID ở các biến sau bằng UUID tương ứng bạn vừa copy:
   * `admin_user_id` (Dòng 11)
   * `owner_user_id` (Dòng 12)
   * `worker_user_id` (Dòng 13)
3. Copy toàn bộ nội dung file [supabase_seed.sql](file:///d:/DT/cuoiki/flutter-supervisor-forest-main/flutter-supervisor-forest-main/supabase_seed.sql) đã thay UUID, dán vào **SQL Editor** của Supabase và bấm **Run**.

### Bước 5: Cấu Hình Supabase Trên Client

#### 📱 Mobile Flutter Configuration
Mở file [supabase_constants.dart](file:///d:/DT/cuoiki/flutter-supervisor-forest-main/flutter-supervisor-forest-main/lib/core/constants/supabase_constants.dart) và cập nhật thông tin kết nối Supabase của bạn:
```dart
class SupabaseConstants {
  static const String url = 'YOUR_SUPABASE_PROJECT_URL';
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';
  static const String logbookImagesBucket = 'logbook-images';
}
```

#### 💻 Web Dashboard Configuration
Mở file [index.html](file:///d:/DT/cuoiki/flutter-supervisor-forest-main/flutter-supervisor-forest-main/web_dashboard/index.html) (khoảng dòng 1608) và điền cấu hình:
```javascript
const SUPABASE_URL = 'YOUR_SUPABASE_PROJECT_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

---

## 📱 Phát Triển & Build Mobile Flutter

### Các Lệnh Chạy Cơ Bản
Thực hiện các lệnh sau tại thư mục gốc của project:

```bash
# Xóa bộ nhớ cache build cũ
flutter clean

# Tải các gói phụ thuộc (dependencies)
flutter pub get

# Kiểm tra cú pháp và chất lượng mã nguồn
flutter analyze

# Build ứng dụng phiên bản Debug APK
flutter build apk --debug
```

### Đường Dẫn Xuất Bản APK
Sau khi build hoàn tất, file APK chạy thử nghiệm nằm ở đường dẫn:
```text
build/app/outputs/flutter-apk/app-debug.apk
```

---

## 💻 Chạy Web Dashboard

### Chạy Local Server
Để chạy giao diện Web Dashboard trên máy cục bộ, truy cập thư mục `web_dashboard` và khởi chạy máy chủ HTTP:

```bash
cd web_dashboard
python -m http.server 5500
```

Truy cập trên trình duyệt qua địa chỉ:
```text
http://127.0.0.1:5500
```
> 💡 **Mẹo**: Nếu chỉnh sửa mã nguồn mà trình duyệt không thay đổi, hãy nhấn **Ctrl + F5** để xóa bộ nhớ đệm (Hard Refresh).

---

## 📝 Lưu Ý Quan Trọng

* **Android Package Name**: Được giữ nguyên là `com.example.forest_data_management`.
* **Phân quyền Storage**: Bucket `logbook-images` được cấu hình Public để hiển thị URL trực tiếp trên Web Dashboard, nhưng RLS policies chỉ cho phép người dùng đã xác thực (Authenticated) thực hiện Upload và Update ảnh của chính họ.
* **Xác thực fallback**: Nếu kết nối tới Supabase Auth thất bại hoặc dữ liệu database chưa được seed đúng cách, Web Dashboard sẽ hiển thị cảnh báo và tự động chuyển sang chế độ sử dụng dữ liệu offline giả lập để người dùng vẫn trải nghiệm được giao diện đầy đủ.
* **Firebase**: Toàn bộ SDK, cấu hình Android (`google-services.json`), file cấu hình Flutter (`firebase_options.dart`) đã được gỡ bỏ hoàn toàn khỏi dự án.
