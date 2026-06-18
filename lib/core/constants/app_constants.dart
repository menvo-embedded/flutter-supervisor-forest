class AppConstants {
  AppConstants._();
  static const int    maxImages    = 10;
  static const String tokenKey     = 'qlr_auth_token';
  static const String userKey      = 'qlr_user_data';
  static const String pendingKey   = 'qlr_pending_sync';
  static const List<String> jobTypes = [
    'Trồng cây','Chăm sóc cây','Bón phân',
    'Kiểm tra sinh trưởng','Tuần tra','Phòng cháy chữa cháy',
  ];
  static const Map<String,String> roleLabels = {
    'platform_admin' : 'Quản trị viên',
    'forest_owner'   : 'Chủ rừng',
    'forest_worker'  : 'Nhân viên hiện trường',
  };
}
