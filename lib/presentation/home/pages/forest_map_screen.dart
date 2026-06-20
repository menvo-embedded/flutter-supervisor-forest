import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';

class ForestProjectModel {
  final String name;
  final double area;
  final String forestType;
  final String status;
  final String ownerCode;
  final double lat;
  final double lng;
  final String? ownerName;

  ForestProjectModel({
    required this.name,
    required this.area,
    required this.forestType,
    required this.status,
    required this.ownerCode,
    required this.lat,
    required this.lng,
    this.ownerName,
  });
}

class ForestMapScreen extends StatefulWidget {
  const ForestMapScreen({super.key});

  @override
  State<ForestMapScreen> createState() => _ForestMapScreenState();
}

class _ForestMapScreenState extends State<ForestMapScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final MapController _mapController = MapController();

  bool _isLoading = true;
  String? _errorMessage;

  List<ForestProjectModel> _allProjects = [];
  List<ForestProjectModel> _filteredProjects = [];

  // Authentication & authorization states
  bool _isAdmin = false;
  bool _isOwner = false;
  String? _currentOwnerCode;

  // Filter lists for admin dropdown
  List<Map<String, dynamic>> _owners = [];
  String? _selectedOwnerCode; // null means "Tất cả chủ rừng"

  // Map settings
  bool _isSatellite = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception("Người dùng chưa đăng nhập. Vui lòng đăng nhập lại.");
      }

      // 1. Get user profile role and associated owner_id
      final profileResponse = await _supabase
          .from('profiles')
          .select('role, owner_id')
          .eq('id', user.id)
          .maybeSingle();

      if (profileResponse == null) {
        throw Exception(
            "Không tìm thấy thông tin phân quyền cho tài khoản này.");
      }

      final roleStr = profileResponse['role'] ?? 'worker';
      _isOwner = (roleStr == 'owner' || roleStr == 'forest_owner');
      _isAdmin = (roleStr == 'admin' || roleStr == 'platform_admin');

      // 2. Fetch owners list if admin (for filtering dropdown)
      if (_isAdmin) {
        final ownersRes = await _supabase
            .from('forest_owners')
            .select('owner_code, owner_name')
            .order('owner_name');

        _owners = List<Map<String, dynamic>>.from(ownersRes);
      }

      // 3. Fetch specific owner code if current user is owner
      final ownerId = profileResponse['owner_id'];
      if (_isOwner && ownerId != null) {
        final ownerRes = await _supabase
            .from('forest_owners')
            .select('owner_code')
            .eq('id', ownerId)
            .maybeSingle();
        if (ownerRes != null) {
          _currentOwnerCode = ownerRes['owner_code'];
        }
      }

      // 4. Fetch projects
      List<dynamic> projectsData = [];

      try {
        // Query forest_projects as primary (which is the actual seeded table)
        var query = _supabase.from('forest_projects').select(
            'id, project_name, area_ha, forest_type, status, owner_id, province, district, commune, centroid_lat, centroid_lng');
        if (_isOwner && ownerId != null) {
          query = query.eq('owner_id', ownerId);
        }
        final res = await query;

        // Fetch owner info to map IDs to owner_codes
        final ownersRes = await _supabase
            .from('forest_owners')
            .select('id, owner_code, owner_name');
        final ownersMap = {for (var o in ownersRes) o['id']: o};

        projectsData = res.map((item) {
          final ownerData = ownersMap[item['owner_id']];
          final oCode = ownerData?['owner_code'] ?? '';
          final oName = ownerData?['owner_name'] ?? '';

          return {
            'name': item['project_name'],
            'area': item['area_ha'],
            'forest_type': item['forest_type'],
            'status': item['status'],
            'owner_code': oCode,
            'owner_name': oName,
            'lat': item['centroid_lat'],
            'lng': item['centroid_lng'],
          };
        }).toList();
      } catch (e) {
        // Fallback to legacy projects table/view if available
        var query = _supabase
            .from('forest_projects')
            .select('lat, lng, name, area, forest_type, status, owner_code');
        if (_isOwner && _currentOwnerCode != null) {
          query = query.eq('owner_code', _currentOwnerCode!);
        }
        projectsData = await query;
      }

      _allProjects = projectsData
          .where((p) => p['lat'] != null && p['lng'] != null)
          .map((p) {
        final double latVal = double.tryParse(p['lat']?.toString() ?? '') ?? 0;
        final double lngVal = double.tryParse(p['lng']?.toString() ?? '') ?? 0;
        final double areaVal =
            double.tryParse(p['area']?.toString() ?? '') ?? 0.0;

        return ForestProjectModel(
          name: p['name']?.toString() ?? 'Dự án không tên',
          area: areaVal,
          forestType: p['forest_type']?.toString() ?? 'Không rõ',
          status: p['status']?.toString() ?? 'pending',
          ownerCode: p['owner_code']?.toString() ?? '',
          lat: latVal,
          lng: lngVal,
          ownerName: p['owner_name']?.toString(),
        );
      }).toList();

      _applyFilters();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    if (_isAdmin && _selectedOwnerCode != null) {
      _filteredProjects =
          _allProjects.where((p) => p.ownerCode == _selectedOwnerCode).toList();
    } else {
      _filteredProjects = List.from(_allProjects);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'active':
        return const Color(0xFF2E7D32); // Beautiful forest green
      case 'pending':
      case 'surveying':
        return const Color(0xFFEF6C00); // Vivid orange
      default:
        return const Color(0xFF78909C); // Neutral slate grey
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Đã duyệt';
      case 'active':
        return 'Hoạt động';
      case 'pending':
        return 'Chờ duyệt';
      case 'surveying':
        return 'Đang khảo sát';
      default:
        return status;
    }
  }

  void _showProjectBottomSheet(ForestProjectModel project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final statusColor = _getStatusColor(project.status);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pull handle indicator
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Title & Status Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      project.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      _getStatusLabel(project.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // Specifications Grid
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(2.0),
                },
                children: [
                  _buildSpecRow(
                      "Diện tích",
                      "${project.area.toStringAsFixed(2)} ha",
                      subColor,
                      textColor),
                  _buildSpecRow(
                      "Loại rừng", project.forestType, subColor, textColor),
                  if (project.ownerCode.isNotEmpty)
                    _buildSpecRow(
                        "Mã chủ rừng", project.ownerCode, subColor, textColor),
                  if (project.ownerName != null)
                    _buildSpecRow("Tên chủ rừng", project.ownerName!, subColor,
                        textColor),
                  _buildSpecRow(
                      "Tọa độ",
                      "${project.lat.toStringAsFixed(5)}, ${project.lng.toStringAsFixed(5)}",
                      subColor,
                      textColor),
                ],
              ),
              const SizedBox(height: 24),

              // Action button to dismiss
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Đóng",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  TableRow _buildSpecRow(
      String label, String value, Color labelColor, Color valueColor) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: labelColor),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileUrl = _isSatellite
        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    // Center map around first item or general Vietnam Central Highlands center
    LatLng mapCenter = const LatLng(12.6667, 108.0500);
    if (_filteredProjects.isNotEmpty) {
      mapCenter = LatLng(_filteredProjects[0].lat, _filteredProjects[0].lng);
    }

    return Scaffold(
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text("Đang tải dữ liệu bản đồ từ Supabase..."),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          "Lỗi: $_errorMessage",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _fetchData,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary),
                          child: const Text("Tải lại"),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    // The Map Widget
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: mapCenter,
                        initialZoom: 9.0,
                        minZoom: 4.0,
                        maxZoom: 18.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: tileUrl,
                          userAgentPackageName:
                              'com.example.forest_data_management',
                          maxZoom: 18,
                        ),
                        // Transparent area circles representation
                        CircleLayer(
                          circles: _filteredProjects.map((p) {
                            final color = _getStatusColor(p.status);
                            final radiusMeters =
                                math.sqrt((p.area * 10000) / math.pi) * 2.5;
                            return CircleMarker(
                              point: LatLng(p.lat, p.lng),
                              radius: radiusMeters,
                              color: color.withOpacity(0.12),
                              borderColor: color.withOpacity(0.6),
                              borderStrokeWidth: 1.5,
                              useRadiusInMeter: true,
                            );
                          }).toList(),
                        ),
                        // Rich custom markers representing project status
                        MarkerLayer(
                          markers: _filteredProjects.map((p) {
                            final statusColor = _getStatusColor(p.status);
                            return Marker(
                              point: LatLng(p.lat, p.lng),
                              width: 40,
                              height: 48,
                              child: GestureDetector(
                                onTap: () => _showProjectBottomSheet(p),
                                child: _buildMarkerWidget(statusColor),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),

                    // Top Bar Filters for Admin
                    if (_isAdmin && _owners.isNotEmpty)
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: SafeArea(
                          child: Card(
                            elevation: 8,
                            shadowColor: Colors.black.withOpacity(0.15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            color:
                                isDark ? const Color(0xFF1E293B) : Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedOwnerCode,
                                  isExpanded: true,
                                  hint: Text(
                                    "Tất cả chủ rừng",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                  icon: const Icon(Icons.filter_list_rounded,
                                      color: AppColors.primary),
                                  dropdownColor: isDark
                                      ? const Color(0xFF1E293B)
                                      : Colors.white,
                                  items: [
                                    DropdownMenuItem<String>(
                                      value: null,
                                      child: Text(
                                        "Tất cả chủ rừng",
                                        style: TextStyle(
                                          fontWeight: _selectedOwnerCode == null
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    ..._owners.map((owner) {
                                      final code =
                                          owner['owner_code']?.toString() ?? '';
                                      final name =
                                          owner['owner_name']?.toString() ?? '';
                                      return DropdownMenuItem<String>(
                                        value: code,
                                        child: Text(
                                          "$name ($code)",
                                          style: TextStyle(
                                            fontWeight:
                                                _selectedOwnerCode == code
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedOwnerCode = val;
                                      _applyFilters();
                                      if (_filteredProjects.isNotEmpty) {
                                        _mapController.move(
                                          LatLng(_filteredProjects[0].lat,
                                              _filteredProjects[0].lng),
                                          9.5,
                                        );
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Map controls floating on the side
                    Positioned(
                      right: 16,
                      bottom: 30,
                      child: Column(
                        children: [
                          // Satellite Toggle Control Button
                          _buildFloatingControl(
                            icon: _isSatellite
                                ? Icons.map_rounded
                                : Icons.satellite_alt_rounded,
                            tooltip: _isSatellite
                                ? "Bản đồ thường"
                                : "Bản đồ vệ tinh",
                            onTap: () {
                              setState(() {
                                _isSatellite = !_isSatellite;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          // Zoom In Control
                          _buildFloatingControl(
                            icon: Icons.add,
                            tooltip: "Phóng to",
                            onTap: () {
                              _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom + 1.0,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          // Zoom Out Control
                          _buildFloatingControl(
                            icon: Icons.remove,
                            tooltip: "Thu nhỏ",
                            onTap: () {
                              _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom - 1.0,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          // Reset location button
                          _buildFloatingControl(
                            icon: Icons.my_location_rounded,
                            tooltip: "Vị trí dự án",
                            onTap: () {
                              if (_filteredProjects.isNotEmpty) {
                                _mapController.move(
                                  LatLng(_filteredProjects[0].lat,
                                      _filteredProjects[0].lng),
                                  9.0,
                                );
                              } else {
                                _mapController.move(
                                    const LatLng(12.6667, 108.0500), 9.0);
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    // Empty State overlay
                    if (_filteredProjects.isEmpty)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          decoration: BoxDecoration(
                            color: (isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white)
                                .withOpacity(0.95),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.map_outlined,
                                  color: AppColors.textHint, size: 40),
                              SizedBox(height: 8),
                              Text(
                                "Không tìm thấy dự án nào",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Không có dữ liệu hiển thị trên bản đồ.",
                                style: TextStyle(
                                    color: AppColors.textHint, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildMarkerWidget(Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 1.5,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: const Icon(
            Icons.park_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
        // Pin tail indicator pointing down
        CustomPaint(
          size: const Size(10, 6),
          painter: _PinTailPainter(color: color),
        ),
      ],
    );
  }

  Widget _buildFloatingControl({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
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
