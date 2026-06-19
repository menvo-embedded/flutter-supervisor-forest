class DemoAccount {
  final String label;
  final String email;
  final String password;
  final String role;
  final String description;

  const DemoAccount({
    required this.label,
    required this.email,
    required this.password,
    required this.role,
    required this.description,
  });
}

class DemoAccounts {
  static const bool enabled = true;

  static const List<DemoAccount> accounts = [
    DemoAccount(
      label: 'Quản trị viên',
      email: 'admin@qlr.vn',
      password: '123456',
      role: 'admin',
      description: 'Xem toàn bộ hệ thống',
    ),
    DemoAccount(
      label: 'Chủ rừng A',
      email: 'phambao4399@gmail.com',
      password: '123456',
      role: 'owner',
      description: 'Xem dữ liệu chủ rừng A',
    ),
    DemoAccount(
      label: 'Worker A',
      email: 'menthcstk@gmail.com',
      password: '123456',
      role: 'worker',
      description: 'Check-in/nhật ký thuộc chủ rừng A',
    ),
    DemoAccount(
      label: 'Chủ rừng B',
      email: 'thienbimchua12@gmail.com',
      password: '123456',
      role: 'owner',
      description: 'Xem dữ liệu chủ rừng B',
    ),
    DemoAccount(
      label: 'Worker B',
      email: 'worker@qlr.vn',
      password: '123456',
      role: 'worker',
      description: 'Check-in/nhật ký thuộc chủ rừng B',
    ),
  ];
}