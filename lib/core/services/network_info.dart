import 'package:connectivity_plus/connectivity_plus.dart';

/// Abstraction kiểm tra kết nối mạng - dùng chung cho mọi Remote DataSource
/// Production: bọc package connectivity_plus + ping thực tế tới server
abstract class NetworkInfo {
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  @override
  Future<bool> get isConnected async {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }
}
