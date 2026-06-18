# QLR Forest Mobile & Web Dashboard

QLR là hệ thống quản lý dữ liệu rừng, nhật ký hiện trường, GPS check-in, ảnh hiện trường và dự án carbon.

Trạng thái hiện tại: project đã được chuyển khỏi Firebase sang Supabase cho cả Mobile Flutter và Web Dashboard.

## Những Việc Đã Làm

- Gỡ Firebase khỏi luồng chạy chính của Flutter.
- Gỡ Firebase JS SDK khỏi Web Dashboard.
- Thêm `supabase_flutter` cho Mobile Flutter.
- Khởi tạo Supabase trong `lib/main.dart`.
- Tạo cấu hình Supabase tại `lib/core/constants/supabase_constants.dart`.
- Tạo service dùng chung tại `lib/core/services/supabase_service.dart`.
- Thay datasource chính:
  - `AuthRemoteDataSourceSupabase()`
  - `LogbookRemoteDataSourceSupabase()`
  - `CheckinRemoteDataSourceSupabase()`
- Logbook upload ảnh lên Supabase Storage bucket `logbook-images`.
- Logbook lưu URL ảnh vào field `photo_urls`.
- Check-in lưu vào bảng `checkins`.
- Web Dashboard login bằng Supabase Auth, đọc `profiles`, đọc dữ liệu từ các bảng Supabase.
- Web Dashboard hiển thị ảnh logbook từ `photo_urls`.
- Web Dashboard có fallback demo/offline nếu Supabase Auth hoặc `profiles` chưa seed đúng.
- Tạo `supabase_schema.sql`.
- Tạo `supabase_seed.sql`.
- Cập nhật Android Gradle để không dùng `google-services`.
- Xóa cấu hình Firebase cũ:
  - `lib/firebase_options.dart`
  - `android/app/google-services.json`
  - `firebase.json`

## Supabase Đang Cấu Hình

Project URL:

```text
https://idlkismulbicwcxxqakk.supabase.co
```

Publishable key đã được điền trong:

- `lib/core/constants/supabase_constants.dart`
- `web_dashboard/index.html`

Chỉ dùng publishable/anon key ở Flutter và web public. Không dùng `service_role` key trong client.

## Database & Storage

Chạy SQL trong Supabase SQL Editor theo thứ tự:

1. Chạy `supabase_schema.sql`.
2. Tạo 3 user demo trong Supabase Dashboard > Authentication > Users:

| Email | Password | Role profile |
|---|---|---|
| `admin@qlr.vn` | `123456` | `admin` |
| `owner@qlr.vn` | `123456` | `owner` |
| `worker@qlr.vn` | `123456` | `worker` |

3. Copy UUID của 3 auth users.
4. Thay UUID vào `supabase_seed.sql`.
5. Chạy `supabase_seed.sql`.

`supabase_schema.sql` tạo các bảng chính:

- `profiles`
- `forest_owners`
- `forest_projects`
- `checkins`
- `logbooks`
- `inventory_plots`
- `inventory_trees`
- `carbon_factors`
- `notifications`
- `files`

File schema cũng tạo bucket public:

```text
logbook-images
```

Và tạo policy Storage demo cho đọc public, upload authenticated, update authenticated.

## Mobile Flutter

Mobile nằm trong `lib/`, giữ Clean Architecture + BLoC.

Datasource Supabase đang dùng trong `lib/main.dart`:

```dart
AuthRemoteDataSourceSupabase()
LogbookRemoteDataSourceSupabase()
CheckinRemoteDataSourceSupabase()
```

Lệnh chạy:

```bash
flutter clean
flutter pub get
flutter analyze
flutter build apk --debug
```

Kết quả kiểm tra gần nhất:

- `flutter clean`: pass
- `flutter pub get`: pass
- `flutter analyze`: pass, `No issues found!`
- `flutter build apk --debug`: pass

APK debug:

```text
build\app\outputs\flutter-apk\app-debug.apk
```

## Web Dashboard

Dashboard nằm trong:

```text
web_dashboard/
```

Chạy local:

```bash
cd web_dashboard
python -m http.server 5500
```

Mở:

```text
http://127.0.0.1:5500
```

Nếu trang đang mở bản cũ, bấm `Ctrl + F5` để hard refresh.

## Cách Đăng Nhập Dashboard

Dùng một trong các tài khoản:

- `admin@qlr.vn` / `123456`
- `owner@qlr.vn` / `123456`
- `worker@qlr.vn` / `123456`

Nếu Supabase Auth hoặc bảng `profiles` chưa seed đúng, dashboard sẽ tự vào chế độ demo/offline bằng các tài khoản trên để vẫn xem được UI và dữ liệu mẫu.

## Ghi Chú

- Android package vẫn giữ nguyên: `com.example.forest_data_management`.
- Role vẫn giữ đủ Admin/Owner/Worker.
- Firebase không còn được dùng trong luồng chạy chính.
- Web Dashboard vẫn giữ UI hiện có, chỉ thay lớp login/load data sang Supabase và thêm fallback demo.
