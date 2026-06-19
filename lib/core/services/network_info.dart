/// Abstraction kiểm tra kết nối mạng - dùng chung cho mọi Remote DataSource
/// Production: bọc package connectivity_plus + ping thực tế tới server
abstract class NetworkInfo {
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  /// Cờ giả lập để demo offline-mode (đổi thành false để test luồng offline)
  static bool simulateOnline = true;

  @override
  Future<bool> get isConnected async {
    // Production:
    // final connectivityResult = await Connectivity().checkConnectivity();
    // if (connectivityResult == ConnectivityResult.none) return false;
    // try {
    //   final res = await Dio().get('${ApiConstants.baseUrl}/health',
    //       options: Options(receiveTimeout: const Duration(seconds: 4)));
    //   return res.statusCode == 200;
    // } catch (_) { return false; }
    await Future.delayed(const Duration(milliseconds: 250));
    return simulateOnline;
  }
}
