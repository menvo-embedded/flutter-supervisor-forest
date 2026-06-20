import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  String? _projectId;
  String? _plotId;
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _plots = [];
  List<Map<String, dynamic>> _trees = [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await _client
          .from('forest_projects')
          .select('id,project_code,project_name')
          .order('project_name');
      _projects = List<Map<String, dynamic>>.from(rows);
      if (_projects.isEmpty) {
        _projectId = null;
        _plots = [];
        _trees = [];
      } else {
        final ids = _projects.map((row) => row['id'].toString()).toSet();
        if (_projectId == null || !ids.contains(_projectId)) {
          _projectId = _projects.first['id'].toString();
        }
        await _loadPlots(showLoading: false);
      }
    } catch (error) {
      _showMessage('Không thể tải dữ liệu kiểm kê: $error', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPlots({bool showLoading = true}) async {
    if (_projectId == null) return;
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final rows = await _client
          .from('inventory_plots')
          .select('id,plot_code,latitude,longitude,elevation,area')
          .eq('project_id', _projectId!)
          .order('plot_code');
      _plots = List<Map<String, dynamic>>.from(rows);
      final ids = _plots.map((row) => row['id'].toString()).toSet();
      if (_plots.isEmpty) {
        _plotId = null;
        _trees = [];
      } else {
        if (_plotId == null || !ids.contains(_plotId)) {
          _plotId = _plots.first['id'].toString();
        }
        await _loadTrees(showLoading: false);
      }
    } catch (error) {
      _showMessage('Không thể tải ô tiêu chuẩn: $error', isError: true);
    } finally {
      if (showLoading && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTrees({bool showLoading = true}) async {
    if (_plotId == null) return;
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final rows = await _client
          .from('inventory_trees')
          .select('id,species,dbh,height,quantity,created_at')
          .eq('plot_id', _plotId!)
          .order('created_at', ascending: false);
      _trees = List<Map<String, dynamic>>.from(rows);
    } catch (error) {
      _showMessage('Không thể tải danh sách cây: $error', isError: true);
    } finally {
      if (showLoading && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addPlot() async {
    if (_projectId == null) return;
    final code = TextEditingController();
    final area = TextEditingController();
    final latitude = TextEditingController();
    final longitude = TextEditingController();
    final elevation = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thêm ô tiêu chuẩn'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(code, 'Mã ô *'),
              _field(area, 'Diện tích (ha)', number: true),
              _field(latitude, 'Vĩ độ', number: true),
              _field(longitude, 'Kinh độ', number: true),
              _field(elevation, 'Độ cao (m)', number: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              if (code.text.trim().isEmpty) return;
              try {
                await _client.from('inventory_plots').insert({
                  'project_id': _projectId,
                  'plot_code': code.text.trim(),
                  'area': _numberOrNull(area.text),
                  'latitude': _numberOrNull(latitude.text),
                  'longitude': _numberOrNull(longitude.text),
                  'elevation': _numberOrNull(elevation.text),
                });
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Không thể thêm ô: $error')),
                  );
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    code.dispose();
    area.dispose();
    latitude.dispose();
    longitude.dispose();
    elevation.dispose();
    if (saved == true) {
      await _loadPlots();
      _showMessage('Đã thêm ô tiêu chuẩn.');
    }
  }

  Future<void> _addTree() async {
    if (_plotId == null) return;
    final species = TextEditingController();
    final dbh = TextEditingController();
    final height = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ghi nhận cây'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(species, 'Loài cây *'),
              _field(dbh, 'Đường kính D1.3 (cm) *', number: true),
              _field(height, 'Chiều cao (m) *', number: true),
              _field(quantity, 'Số lượng *', number: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              final count = int.tryParse(quantity.text.trim());
              if (species.text.trim().isEmpty ||
                  _numberOrNull(dbh.text) == null ||
                  _numberOrNull(height.text) == null ||
                  count == null ||
                  count < 1) {
                return;
              }
              try {
                await _client.from('inventory_trees').insert({
                  'plot_id': _plotId,
                  'species': species.text.trim(),
                  'dbh': _numberOrNull(dbh.text),
                  'height': _numberOrNull(height.text),
                  'quantity': count,
                });
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Không thể ghi nhận cây: $error')),
                  );
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    species.dispose();
    dbh.dispose();
    height.dispose();
    quantity.dispose();
    if (saved == true) {
      await _loadTrees();
      _showMessage('Đã ghi nhận dữ liệu cây.');
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  double? _numberOrNull(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.red : AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadProjects,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _projectId,
            decoration: const InputDecoration(
              labelText: 'Dự án',
              prefixIcon: Icon(Icons.forest_outlined),
            ),
            items: _projects
                .map(
                  (project) => DropdownMenuItem(
                    value: project['id'].toString(),
                    child: Text(
                      (project['project_name'] ??
                              project['project_code'] ??
                              'Dự án')
                          .toString(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              setState(() {
                _projectId = value;
                _plotId = null;
              });
              await _loadPlots();
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _plotId,
                  decoration: const InputDecoration(labelText: 'Ô tiêu chuẩn'),
                  items: _plots
                      .map(
                        (plot) => DropdownMenuItem(
                          value: plot['id'].toString(),
                          child: Text((plot['plot_code'] ?? 'Ô').toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    setState(() => _plotId = value);
                    await _loadTrees();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Thêm ô tiêu chuẩn',
                onPressed: _projectId == null ? null : _addPlot,
                icon: const Icon(Icons.add_location_alt_outlined),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Danh sách cây',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: _plotId == null ? null : _addTree,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ghi nhận'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_projects.isEmpty)
            const _EmptyState('Chưa có dự án được phân quyền.')
          else if (_plots.isEmpty)
            const _EmptyState('Chưa có ô tiêu chuẩn trong dự án này.')
          else if (_trees.isEmpty)
            const _EmptyState('Chưa có dữ liệu cây trong ô này.')
          else
            ..._trees.map(
              (tree) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(Icons.park_outlined, color: AppColors.primary),
                  ),
                  title: Text(
                    (tree['species'] ?? 'Chưa rõ loài').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'D1.3: ${tree['dbh'] ?? '—'} cm  •  H: ${tree['height'] ?? '—'} m',
                  ),
                  trailing: Text(
                    'x${tree['quantity'] ?? 0}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
