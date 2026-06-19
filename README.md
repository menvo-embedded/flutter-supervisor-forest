# QLR Forest Mobile & Web Dashboard

QLR là hệ thống quản lý dữ liệu rừng, nhật ký hiện trường, GPS check-in, ảnh hiện trường và dự án carbon.

Trạng thái hiện tại: project đã được chuyển khỏi Firebase sang Supabase cho cả Mobile Flutter và Web Dashboard. Branch hiện tại đã hợp nhất các phần xác thực/phân quyền người dùng với đồng bộ hiện trường, Check-in GPS và GIS trên Web Dashboard.

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
- Web Dashboard đã Việt hóa và cải thiện UI các tab chính: Tổng quan, Nhật ký hiện trường, Người dùng & Phân quyền, Check-in GPS, Bản đồ/GIS.
- Tab Tổng quan đọc KPI từ `forest_owners`, `forest_projects`, `logbooks`, `checkins`, hiển thị ảnh hiện trường mới nhất từ `photo_urls`.
- Tab Nhật ký hiện trường đọc dữ liệu thật từ `logbooks`, hiển thị thumbnail ảnh, modal xem ảnh lớn, GPS và link Google Maps.
- Logic Nhật ký hiện trường theo role:
  - Admin xem toàn bộ logbooks.
  - Owner xem logbooks thuộc các project của owner đó.
  - Worker chỉ xem logbooks do chính worker tạo.
- Web Dashboard enforce `profiles.status` sau login và khi khôi phục session:
  - `active`: cho vào dashboard.
  - `inactive`: chặn với thông báo tài khoản chưa được kích hoạt.
  - `locked`: chặn với thông báo tài khoản đã bị khóa.
- Tab Người dùng & Phân quyền có chức năng mời/tạo tài khoản qua Supabase Edge Function `create-invite-user`.
- Người dùng được mời qua email có flow thiết lập mật khẩu trên Web Dashboard bằng `supabase.auth.updateUser({ password })`.
- Tab Check-in GPS đọc bảng `checkins`, hiển thị lịch sử check-in, lọc theo nhân viên/ngày và mở vị trí bằng Google Maps.
- Bản đồ hiển thị marker dự án, logbook GPS và check-in GPS.
- Bản đồ/GIS hỗ trợ upload GeoJSON/KML, tính diện tích/chu vi/tâm ranh giới bằng Turf.js.
- Bản đồ/GIS có công cụ vẽ/chỉnh sửa thủ công bằng Leaflet-Geoman nếu chạy trên trình duyệt.
- Web Dashboard có fallback demo/offline nếu Supabase Auth hoặc `profiles` chưa seed đúng.
- Tạo `supabase_schema.sql`.
- Tạo `supabase_seed.sql`.
- Tạo Supabase Edge Function:
  - `supabase/functions/create-invite-user/index.ts`
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

Edge Function `create-invite-user` cần được deploy trong Supabase và cấu hình secret server-side cho service role. Không đưa `service_role` vào Flutter hoặc `web_dashboard/index.html`.

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

Các field quan trọng đang được Web Dashboard đọc:

- `profiles.id`, `profiles.email`, `profiles.full_name`, `profiles.phone`, `profiles.role`, `profiles.status`, `profiles.owner_id`
- `forest_projects.owner_id`
- `logbooks.project_id`, `logbooks.user_id`, `logbooks.photo_urls`, `logbooks.latitude`, `logbooks.longitude`
- `checkins.user_id`, `checkins.latitude`, `checkins.longitude`, `checkins.created_at` hoặc `checkins.checked_at`

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

Nếu port `5500` đang bị VS Code Live Server giữ ở root project, mở:

```text
http://127.0.0.1:5500/web_dashboard/index.html
```

Nếu trang đang mở bản cũ, bấm `Ctrl + F5` để hard refresh.

Các tab Web Dashboard hiện có:

- Tổng quan
- Chủ rừng
- Dự án rừng
- Bản đồ/GIS
- Điều tra rừng
- Nhật ký hiện trường
- Check-in GPS
- Tính toán carbon
- Báo cáo
- Hồ sơ/Tài liệu
- Người dùng & Phân quyền
- Thông báo
- Cài đặt

## Cách Đăng Nhập Dashboard

Dùng một trong các tài khoản:

- `admin@qlr.vn` / `123456`
- `owner@qlr.vn` / `123456`
- `worker@qlr.vn` / `123456`

Nếu Supabase Auth hoặc bảng `profiles` chưa seed đúng, dashboard sẽ tự vào chế độ demo/offline bằng các tài khoản trên để vẫn xem được UI và dữ liệu mẫu.

Lưu ý: khi Supabase trả về profile thật, Web Dashboard ưu tiên profile thật và status thật. Fallback demo/offline không được dùng để bỏ qua trạng thái `inactive` hoặc `locked`.

## Tạo/Mời Tài Khoản Trên Web

Admin vào tab `Người dùng & Phân quyền` và bấm `+ Thêm tài khoản`.

Luồng hiện tại:

1. Web gọi Edge Function `create-invite-user`.
2. Edge Function kiểm tra người gọi đang đăng nhập và có role `admin`.
3. Edge Function dùng service role ở server để gọi Supabase Auth invite.
4. Edge Function upsert hồ sơ vào bảng `profiles` với:
   - `id`
   - `email`
   - `full_name`
   - `phone`
   - `role`
   - `status`
5. User nhận email invite, mở link và thiết lập mật khẩu trên Web Dashboard.

Không gọi `auth.admin.createUser()` hoặc `auth.admin.inviteUserByEmail()` trong browser.

## Nhật Ký Hiện Trường

Tab `Nhật ký hiện trường` đọc bảng `logbooks`.

Ảnh hiện trường đọc từ field:

```text
photo_urls
```

Web Dashboard hỗ trợ:

- `photo_urls` dạng array.
- `photo_urls` dạng chuỗi JSON.
- Trường hợp null/rỗng hiển thị `Không có ảnh`.
- Thumbnail ảnh trong danh sách và modal xem ảnh lớn.
- GPS từ `latitude`/`longitude` và link Google Maps nếu đủ tọa độ.

Phân quyền hiển thị:

- Admin: toàn bộ logbooks.
- Owner: logbooks thuộc `forest_projects` của owner hiện tại.
- Worker: logbooks có `user_id` là user hiện tại.

## Check-in GPS & GIS

Tab `Check-in GPS` đọc bảng `checkins`.

Tính năng hiện có:

- Danh sách lịch sử check-in.
- Lọc theo nhân viên.
- Lọc theo ngày.
- Link Google Maps theo lat/lng.
- Dashboard Tổng quan hiển thị check-in mới nhất và thống kê check-in theo ngày.

Tab `Bản đồ/GIS` hiện có:

- Marker dự án rừng.
- Marker logbook có GPS.
- Marker check-in GPS.
- Upload GeoJSON/KML.
- Tính diện tích, chu vi và tâm ranh giới bằng Turf.js.
- Vẽ/chỉnh sửa ranh giới thủ công bằng Leaflet-Geoman.

## Kiểm Tra Nhanh Sau Merge

Web Dashboard:

```bash
cd web_dashboard
python -m http.server 5500
```

Kiểm tra:

- Admin login thấy đầy đủ menu, tab `Người dùng & Phân quyền` và tạo/mời tài khoản.
- Owner login thấy `Nhật ký hiện trường` thuộc project của owner.
- Worker login không thấy chức năng admin và chỉ thấy logbook của chính mình.
- Tab `Check-in GPS` load dữ liệu check-in, lọc được theo nhân viên/ngày.
- Tab `Bản đồ/GIS` hiển thị marker check-in, upload GeoJSON/KML và vẽ thủ công.
- Ảnh logbook từ `photo_urls` hiển thị thumbnail và mở modal ảnh lớn.

## Ghi Chú

- Android package vẫn giữ nguyên: `com.example.forest_data_management`.
- Role vẫn giữ đủ Admin/Owner/Worker.
- Firebase không còn được dùng trong luồng chạy chính.
- Web Dashboard không dùng Firebase JS SDK.
- Web Dashboard không chứa `service_role` key.
- Không đổi field `photo_urls`.
