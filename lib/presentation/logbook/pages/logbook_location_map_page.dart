import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../core/theme/app_colors.dart';

/// Trang bản đồ hiển thị vị trí nhật ký hiện trường.
/// Nhận tọa độ GPS (latitude, longitude) và tên công việc để hiển thị marker.
class LogbookLocationMapPage extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String title;
  final String? description;
  final DateTime? timestamp;

  const LogbookLocationMapPage({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.title,
    this.description,
    this.timestamp,
  });

  @override
  State<LogbookLocationMapPage> createState() => _LogbookLocationMapPageState();
}

class _LogbookLocationMapPageState extends State<LogbookLocationMapPage> {
  final MapController _mapController = MapController();
  bool _isSatellite = false;

  String _fmtTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} lúc ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final center = LatLng(widget.latitude, widget.longitude);

    final tileUrl = _isSatellite
        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        title: const Text(
          'Vị trí nhật ký',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Bản đồ
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15.0,
              minZoom: 4.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.example.forest_data_management',
                maxZoom: 18,
              ),
              // Vòng tròn highlight vị trí
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: center,
                    radius: 40,
                    color: AppColors.primary.withOpacity(0.12),
                    borderColor: AppColors.primary.withOpacity(0.5),
                    borderStrokeWidth: 2,
                    useRadiusInMeter: true,
                  ),
                ],
              ),
              // Marker chính
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 48,
                    height: 56,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 10,
                                spreadRadius: 2,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.edit_location_alt_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        // Pin tail
                        CustomPaint(
                          size: const Size(12, 8),
                          painter: _PinTailPainter(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Thẻ thông tin phía dưới
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.description != null && widget.description!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      widget.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                  if (widget.timestamp != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _fmtTime(widget.timestamp!),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Các nút điều khiển bản đồ
          Positioned(
            right: 16,
            top: 16,
            child: SafeArea(
              child: Column(
                children: [
                  // Chuyển đổi chế độ bản đồ
                  _buildFloatingControl(
                    context: context,
                    icon: _isSatellite ? Icons.map_rounded : Icons.satellite_alt_rounded,
                    tooltip: _isSatellite ? 'Bản đồ thường' : 'Bản đồ vệ tinh',
                    onTap: () => setState(() => _isSatellite = !_isSatellite),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  // Phóng to
                  _buildFloatingControl(
                    context: context,
                    icon: Icons.add,
                    tooltip: 'Phóng to',
                    onTap: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1.0,
                    ),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  // Thu nhỏ
                  _buildFloatingControl(
                    context: context,
                    icon: Icons.remove,
                    tooltip: 'Thu nhỏ',
                    onTap: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1.0,
                    ),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  // Về trung tâm
                  _buildFloatingControl(
                    context: context,
                    icon: Icons.my_location_rounded,
                    tooltip: 'Về vị trí nhật ký',
                    onTap: () => _mapController.move(center, 15.0),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingControl({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 20,
            color: isDark ? Colors.white70 : const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;

  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter oldDelegate) => oldDelegate.color != color;
}
