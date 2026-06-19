class DemoAccount {
  final String label;
  final String email;
  final String password;
  final String description;
  final String role;

  const DemoAccount({
    required this.label,
    required this.email,
    required this.password,
    required this.description,
    required this.role,
  });
}

class DemoAccounts {
  DemoAccounts._();

  static const bool enabled = true;

  static const List<DemoAccount> accounts = [
    DemoAccount(
      label: 'Admin',
      email: 'admin@qlr.vn',
      password: '123456',
      description: 'Xem toàn bộ hệ thống',
      role: 'admin',
    ),
    DemoAccount(
      label: 'Chủ rừng A',
      email: 'ownerA@example.com',
      password: '123456',
      description: 'Xem dữ liệu chủ rừng A',
      role: 'owner',
    ),
    DemoAccount(
      label: 'Worker A',
      email: 'workerA@example.com',
      password: '123456',
      description: 'Check-in/nhật ký thuộc chủ rừng A',
      role: 'worker',
    ),
    DemoAccount(
      label: 'Chủ rừng B',
      email: 'ownerB@example.com',
      password: '123456',
      description: 'Xem dữ liệu chủ rừng B',
      role: 'owner',
    ),
    DemoAccount(
      label: 'Worker B',
      email: 'workerB@example.com',
      password: '123456',
      description: 'Check-in/nhật ký thuộc chủ rừng B',
      role: 'worker',
    ),
  ];
}
