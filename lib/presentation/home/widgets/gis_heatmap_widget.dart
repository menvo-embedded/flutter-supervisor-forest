import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';

// ─── Data Model ──────────────────────────────────────────────────────────────
class ForestProject {
  final String id;
  final String name;
  final double areaHa;
  final LatLng position;
  final Color color;
  final double carbonStock;
  final String status;

  const ForestProject({
    required this.id,
    required this.name,
    required this.areaHa,
    required this.position,
    required this.color,
    required this.carbonStock,
    required this.status,
  });
}

// ─── Mock sample plots kept for GIS visual overlay ───────────────────────────
const _samplePlots = [
  LatLng(12.645, 108.060),
  LatLng(12.672, 108.075),
  LatLng(12.690, 108.040),
  LatLng(12.658, 108.105),
  LatLng(12.700, 108.115),
  LatLng(12.628, 108.048),
  LatLng(12.715, 108.088),
];

// ─── Layer Config ─────────────────────────────────────────────────────────────
enum _LayerType { project, samplePlot, activity, satellite, basemap }

class _LayerConfig {
  final _LayerType type;
  final String label;
  final String emoji;
  final Color color;
  bool visible;
  _LayerConfig(this.type, this.label, this.emoji, this.color, {this.visible = true});
}

// ─── Main widget ─────────────────────────────────────────────────────────────
class GISHeatmapWidget extends StatefulWidget {
  const GISHeatmapWidget({super.key});

  @override
  State<GISHeatmapWidget> createState() => _GISHeatmapWidgetState();
}

class _GISHeatmapWidgetState extends State<GISHeatmapWidget> {
  final _supabase = Supabase.instance.client;
  final _mapController = MapController();
  
  bool _isLoading = true;
  String? _errorMessage;
  List<ForestProject> _supabaseProjects = [];
  ForestProject? _selectedProject;
  bool _isSatellite = false;

  final _layers = [
    _LayerConfig(_LayerType.project,    'Dự án',      '🌳', const Color(0xFF107C41)),
    _LayerConfig(_LayerType.samplePlot, 'Ô mẫu',      '📍', const Color(0xFF3B82F6)),
    _LayerConfig(_LayerType.activity,   'Hoạt động',  '⚡', const Color(0xFFF59E0B)),
    _LayerConfig(_LayerType.satellite,  'Vệ tinh',    '🛰️', const Color(0xFF8B5CF6), visible: false),
    _LayerConfig(_LayerType.basemap,    'Bản đồ nền', '🗺️', const Color(0xFF64748B)),
  ];

  @override
  void initState() {
    super.initState();
    _fetchSupabaseData();
  }

  Future<void> _fetchSupabaseData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception("Người dùng chưa đăng nhập.");
      }

      // 1. Get role and owner_id from profiles
      final profile = await _supabase
          .from('profiles')
          .select('role, owner_id')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        throw Exception("Không tìm thấy cấu hình profiles.");
      }

      final roleStr = profile['role'] ?? 'worker';
      final isOwner = (roleStr == 'owner' || roleStr == 'forest_owner');
      final ownerId = profile['owner_id'];

      // 2. Fetch specific owner code if owner
      String? ownerCode;
      if (isOwner && ownerId != null) {
        final ownerRes = await _supabase
            .from('forest_owners')
            .select('owner_code')
            .eq('id', ownerId)
            .maybeSingle();
        if (ownerRes != null) {
          ownerCode = ownerRes['owner_code'];
        }
      }

      // 3. Query projects table (tries projects, falls back to forest_projects)
      List<dynamic> rawProjects = [];
      try {
        var query = _supabase.from('projects').select('lat, lng, name, area, forest_type, status, owner_code');
        if (isOwner && ownerCode != null) {
          query = query.eq('owner_code', ownerCode);
        }
        rawProjects = await query;
      } catch (e) {
        // Fallback
        var query = _supabase.from('forest_projects').select('id, project_name, area_ha, forest_type, status, owner_id');
        if (isOwner && ownerId != null) {
          query = query.eq('owner_id', ownerId);
        }
        final res = await query;
        
        final ownersRes = await _supabase.from('forest_owners').select('id, owner_code');
        final ownersMap = {for (var o in ownersRes) o['id']: o['owner_code']};

        rawProjects = res.map((item) {
          final int idx = item['id'].toString().hashCode;
          final double lat = 12.4 + (idx % 100) * 0.008;
          final double lng = 107.8 + (idx % 100) * 0.008;
          return {
            'name': item['project_name'],
            'area': item['area_ha'],
            'forest_type': item['forest_type'],
            'status': item['status'],
            'owner_code': ownersMap[item['owner_id']] ?? '',
            'lat': lat,
            'lng': lng,
          };
        }).toList();
      }

      _supabaseProjects = rawProjects.map<ForestProject>((p) {
        final double latVal = double.tryParse(p['lat']?.toString() ?? '') ?? 12.6667;
        final double lngVal = double.tryParse(p['lng']?.toString() ?? '') ?? 108.0500;
        final double areaVal = double.tryParse(p['area']?.toString() ?? '') ?? 0.0;
        final String statusVal = p['status']?.toString() ?? 'pending';

        Color statusColor = const Color(0xFF78909C); // Slate grey
        if (statusVal.toLowerCase() == 'approved' || statusVal.toLowerCase() == 'active') {
          statusColor = const Color(0xFF2E7D32); // Green
        } else if (statusVal.toLowerCase() == 'pending') {
          statusColor = const Color(0xFFEF6C00); // Orange
        }

        return ForestProject(
          id: p['owner_code']?.toString() ?? 'PRJ',
          name: p['name']?.toString() ?? 'Dự án không tên',
          areaHa: areaVal,
          position: LatLng(latVal, lngVal),
          color: statusColor,
          carbonStock: areaVal * 10,
          status: statusVal,
        );
      }).toList();

      if (mounted) {
        setState(() {});
      }
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

  String get _tileUrl => _isSatellite
      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  void _openFullscreen() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => _FullscreenMapPage(
          initialCenter: const LatLng(12.6667, 108.0500),
          initialZoom: 9,
          layers: _layers,
          isSatellite: _isSatellite,
          selectedProject: _selectedProject,
          projects: _supabaseProjects,
          onStateChanged: (sat, sel, layers) {
            setState(() {
              _isSatellite = sat;
              _selectedProject = sel;
              for (int i = 0; i < layers.length; i++) {
                _layers[i].visible = layers[i].visible;
              }
            });
          },
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: Tween(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          ), child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 380,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_errorMessage != null) {
      return SizedBox(
        height: 380,
        child: Center(
          child: Text("Lỗi tải bản đồ: $_errorMessage", style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = AppColors.getSurface(isDark);
    final borderColor = AppColors.getBorder(isDark);
    final textPrimary = AppColors.getTextPrimary(isDark);
    final textSecondary = AppColors.getTextSecondary(isDark);

    return Column(children: [
      // ── Map + side panel ───────────────────────────────────────────────────
      SizedBox(
        height: 380,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ─ Map ─────────────────────────────────────────────────────────────
          Expanded(
            child: Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _MapView(
                  mapController: _mapController,
                  tileUrl: _tileUrl,
                  layers: _layers,
                  selectedProject: _selectedProject,
                  projects: _supabaseProjects,
                  onProjectTap: (p) => setState(() => _selectedProject = p),
                  onMapTap: () => setState(() => _selectedProject = null),
                ),
              ),
              // Fullscreen button (top-right corner of map)
              Positioned(
                top: 10, right: 10,
                child: _MapButton(
                  icon: Icons.fullscreen_rounded,
                  tooltip: 'Phóng to bản đồ',
                  onTap: _openFullscreen,
                ),
              ),
              // Zoom controls (top-left)
              Positioned(
                top: 10, left: 10,
                child: Column(children: [
                  _MapButton(
                    icon: Icons.add_rounded,
                    onTap: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _MapButton(
                    icon: Icons.remove_rounded,
                    onTap: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(width: 10),

          // ─ Right panel ────────────────────────────────────────────────────
          SizedBox(
            width: 130,
            child: Column(children: [
              // Layer control card (refined)
              _LayerPanel(
                layers: _layers,
                isDark: isDark,
                onToggle: (l, v) => setState(() {
                  l.visible = v;
                  if (l.type == _LayerType.satellite) _isSatellite = v;
                }),
              ),
              const SizedBox(height: 8),
              // Project list
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('Dự án', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textPrimary)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('${_supabaseProjects.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _supabaseProjects.length,
                        separatorBuilder: (_, __) => Divider(height: 10, color: borderColor),
                        itemBuilder: (_, i) {
                          final p = _supabaseProjects[i];
                          final isActive = _selectedProject?.name == p.name;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedProject = p);
                              _mapController.move(p.position, 11);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isActive ? p.color.withOpacity(0.08) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(color: p.color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                          color: isActive ? p.color : textPrimary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${p.areaHa.toStringAsFixed(0)} ha',
                                        style: TextStyle(fontSize: 10, color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),

      // ── Stats bar ────────────────────────────────────────────────────────
      const SizedBox(height: 12),
      Row(children: [
        _StatChip(label: 'Tổng diện tích', value: '${_fmtNum(_supabaseProjects.fold(0.0, (s, p) => s + p.areaHa))} ha', color: AppColors.primary),
        const SizedBox(width: 8),
        _StatChip(label: 'Carbon', value: '${_fmtNum(_supabaseProjects.fold(0.0, (s, p) => s + p.carbonStock))} tCO₂e', color: AppColors.primaryMid),
        const SizedBox(width: 8),
        _StatChip(label: 'Dự án', value: '${_supabaseProjects.length}', color: AppColors.primary),
      ]),
    ]);
  }
}

// ─── Fullscreen Map Page ──────────────────────────────────────────────────────
class _FullscreenMapPage extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final List<_LayerConfig> layers;
  final bool isSatellite;
  final ForestProject? selectedProject;
  final List<ForestProject> projects;
  final void Function(bool isSat, ForestProject? sel, List<_LayerConfig> layers) onStateChanged;

  const _FullscreenMapPage({
    required this.initialCenter,
    required this.initialZoom,
    required this.layers,
    required this.isSatellite,
    required this.selectedProject,
    required this.projects,
    required this.onStateChanged,
  });

  @override
  State<_FullscreenMapPage> createState() => _FullscreenMapPageState();
}

class _FullscreenMapPageState extends State<_FullscreenMapPage> {
  late final MapController _ctrl;
  late bool _isSatellite;
  ForestProject? _selectedProject;
  bool _showPanel = true;
  late final List<_LayerConfig> _layers;

  @override
  void initState() {
    super.initState();
    _ctrl = MapController();
    _isSatellite = widget.isSatellite;
    _selectedProject = widget.selectedProject;
    _layers = widget.layers.map((l) =>
      _LayerConfig(l.type, l.label, l.emoji, l.color, visible: l.visible)
    ).toList();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    widget.onStateChanged(_isSatellite, _selectedProject, _layers);
    super.dispose();
  }

  String get _tileUrl => _isSatellite
      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // Full-screen map
        _MapView(
          mapController: _ctrl,
          tileUrl: _tileUrl,
          layers: _layers,
          selectedProject: _selectedProject,
          projects: widget.projects,
          onProjectTap: (p) => setState(() => _selectedProject = p),
          onMapTap: () => setState(() => _selectedProject = null),
        ),

        // Top bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              _MapButton(
                icon: Icons.fullscreen_exit_rounded,
                tooltip: 'Thu nhỏ',
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() {
                  _isSatellite = !_isSatellite;
                  final satLayer = _layers.firstWhere((l) => l.type == _LayerType.satellite);
                  satLayer.visible = _isSatellite;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _isSatellite
                        ? const Color(0xFF8B5CF6).withOpacity(0.92)
                        : Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6)],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('🛰️', style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text('Vệ tinh',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: _isSatellite ? Colors.white : const Color(0xFF0F172A),
                      )),
                  ]),
                ),
              ),
              const Spacer(),
              _MapButton(
                icon: _showPanel ? Icons.layers_clear_rounded : Icons.layers_rounded,
                tooltip: _showPanel ? 'Ẩn panel' : 'Hiện panel',
                onTap: () => setState(() => _showPanel = !_showPanel),
              ),
            ]),
          ),
        ),

        // Zoom controls
        Positioned(
          right: 12,
          bottom: 100,
          child: Column(children: [
            _MapButton(
              icon: Icons.add_rounded,
              onTap: () => _ctrl.move(_ctrl.camera.center, _ctrl.camera.zoom + 1),
            ),
            const SizedBox(height: 4),
            _MapButton(
              icon: Icons.remove_rounded,
              onTap: () => _ctrl.move(_ctrl.camera.center, _ctrl.camera.zoom - 1),
            ),
            const SizedBox(height: 4),
            _MapButton(
              icon: Icons.my_location_rounded,
              onTap: () => _ctrl.move(const LatLng(12.6667, 108.0500), 9),
            ),
          ]),
        ),

        // Right floating panel
        if (_showPanel)
          Positioned(
            right: 12, top: 80,
            child: AnimatedSlide(
              offset: _showPanel ? Offset.zero : const Offset(1.2, 0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: SizedBox(
                width: 160,
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _LayerPanel(
                    layers: _layers,
                    isDark: isDark,
                    onToggle: (l, v) => setState(() {
                      l.visible = v;
                      if (l.type == _LayerType.satellite) _isSatellite = v;
                    }),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withOpacity(0.8)
                          : Colors.white.withOpacity(0.93),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Dự án', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      )),
                      const SizedBox(height: 6),
                      ...widget.projects.map((p) => GestureDetector(
                        onTap: () {
                          setState(() => _selectedProject = p);
                          _ctrl.move(p.position, 12);
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: p.color, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(p.name,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                                color: _selectedProject?.name == p.name ? p.color : (isDark ? Colors.white70 : const Color(0xFF0F172A))),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ]),
                        ),
                      )),
                    ]),
                  ),
                ]),
              ),
            ),
          ),

        // Bottom stats bar
        Positioned(
          left: 12, right: 12, bottom: 24,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                 child: Row(children: [
                   _FsStat(label: 'Diện tích', value: '${_fmtNum(widget.projects.fold(0.0, (s, p) => s + p.areaHa))} ha', color: AppColors.primary),
                   _vDivider(),
                   _FsStat(label: 'Carbon', value: '${_fmtNum(widget.projects.fold(0.0, (s, p) => s + p.carbonStock))} tCO₂e', color: AppColors.primaryMid),
                   _vDivider(),
                   _FsStat(label: 'Dự án', value: '${widget.projects.length}', color: AppColors.primary),
                 ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _vDivider() => Container(margin: const EdgeInsets.symmetric(horizontal: 12), width: 1, height: 28, color: Colors.white.withOpacity(0.25));
}

class _FsStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _FsStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
    ]),
  );
}

// ─── Shared map body widget ───────────────────────────────────────────────────
class _MapView extends StatelessWidget {
  final MapController mapController;
  final String tileUrl;
  final List<_LayerConfig> layers;
  final ForestProject? selectedProject;
  final List<ForestProject> projects;
  final ValueChanged<ForestProject> onProjectTap;
  final VoidCallback onMapTap;

  const _MapView({
    required this.mapController,
    required this.tileUrl,
    required this.layers,
    required this.selectedProject,
    required this.projects,
    required this.onProjectTap,
    required this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    final showProjects  = layers.any((l) => l.type == _LayerType.project    && l.visible);
    final showSamplePlt = layers.any((l) => l.type == _LayerType.samplePlot && l.visible);

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: const LatLng(12.6667, 108.0500),
        initialZoom: 9,
        minZoom: 4,
        maxZoom: 18,
        onTap: (_, __) => onMapTap(),
      ),
      children: [
        TileLayer(urlTemplate: tileUrl, userAgentPackageName: 'com.qlr.forest', maxZoom: 18),
        if (showProjects)
          CircleLayer(circles: projects.map((p) => CircleMarker(
            point: p.position,
            radius: _areaToRadius(p.areaHa),
            color: p.color.withOpacity(0.15),
            borderColor: p.color,
            borderStrokeWidth: 1.8,
            useRadiusInMeter: true,
          )).toList()),
        if (showProjects)
          MarkerLayer(markers: projects.map((p) => Marker(
            point: p.position,
            width: 36, height: 44,
            child: GestureDetector(
              onTap: () => onProjectTap(p),
              child: _ProjectPin(color: p.color, isSelected: selectedProject?.name == p.name),
            ),
          )).toList()),
        if (showSamplePlt)
          MarkerLayer(markers: _samplePlots.map((ll) => Marker(
            point: ll, width: 12, height: 12,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          )).toList()),
        if (selectedProject != null)
          MarkerLayer(markers: [Marker(
            point: selectedProject!.position,
            width: 200, height: 120,
            alignment: Alignment.topCenter,
            child: _ProjectPopup(project: selectedProject!),
          )]),
      ],
    );
  }
}

// ─── Compact Legend Panel ───────────────────────────────────────────────────────
class _LayerPanel extends StatelessWidget {
  final List<_LayerConfig> layers;
  final bool isDark;
  final void Function(_LayerConfig, bool) onToggle;
  const _LayerPanel({required this.layers, required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? const Color(0xFF0F172A).withOpacity(0.88)
        : Colors.white.withOpacity(0.94);
    final labelColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final dividerColor = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Icon(Icons.layers_rounded, size: 11, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('Lớp bản đồ',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: labelColor, letterSpacing: 0.2)),
              ]),
              const SizedBox(height: 6),
              ...layers.take(3).map((l) => _LayerChip(config: l, isDark: isDark, onToggle: (v) => onToggle(l, v))),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Divider(height: 1, thickness: 1, color: dividerColor),
              ),
              ...layers.skip(3).map((l) => _LayerChip(config: l, isDark: isDark, onToggle: (v) => onToggle(l, v))),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayerChip extends StatelessWidget {
  final _LayerConfig config;
  final bool isDark;
  final ValueChanged<bool> onToggle;
  const _LayerChip({required this.config, required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    return GestureDetector(
      onTap: () => onToggle(!config.visible),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: config.visible ? config.color : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: config.color.withOpacity(config.visible ? 1.0 : 0.35),
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              config.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: config.visible ? FontWeight.w500 : FontWeight.w400,
                color: config.visible
                    ? (isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF1E293B))
                    : labelColor.withOpacity(0.4),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Map overlay button ───────────────────────────────────────────────────────
class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _MapButton({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.93),
            borderRadius: BorderRadius.circular(9),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF1E293B)),
        ),
      ),
    );
  }
}

// ─── Project Pin ─────────────────────────────────────────────────────────────
class _ProjectPin extends StatelessWidget {
  final Color color;
  final bool isSelected;
  const _ProjectPin({required this.color, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.25 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: isSelected ? 30 : 26,
          height: isSelected ? 30 : 26,
          decoration: BoxDecoration(
            color: color, shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: isSelected ? 14 : 6, offset: const Offset(0, 2))],
          ),
          child: const Icon(Icons.park_rounded, color: Colors.white, size: 14),
        ),
        CustomPaint(painter: _PinTailPainter(color: color), size: const Size(10, 8)),
      ]),
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = ui.Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(_PinTailPainter old) => old.color != color;
}

// ─── Project Popup ────────────────────────────────────────────────────────────
class _ProjectPopup extends StatelessWidget {
  final ForestProject project;
  const _ProjectPopup({required this.project});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 14, offset: const Offset(0, 4))],
        border: Border.all(color: project.color, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: project.color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Expanded(child: Text(project.name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 6),
        _infoRow('Diện tích', '${project.areaHa.toStringAsFixed(2)} ha'),
        _infoRow('Carbon', '${project.carbonStock.toStringAsFixed(0)} tCO₂e'),
        _infoRow('Trạng thái', project.status == 'approved' || project.status == 'active' ? '🟢 Hoạt động' : '🟡 Chờ duyệt'),
      ]),
    );
  }

  Widget _infoRow(String k, String v) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
      Text(v, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
    ]),
  );
}

// ─── Stat chip ────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.getSurface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.getBorder(isDark)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: AppColors.getTextSecondary(isDark))),
        ]),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
double _areaToRadius(double ha) => math.sqrt((ha * 10000) / math.pi) * 2.5;

String _fmtNum(double v) => v >= 1000
    ? '${(v / 1000).toStringAsFixed(1)}k'
    : v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
