import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';

class ProjectItem {
  final String id;
  final String code;
  final String name;
  final String ownerId;
  final String ownerCode;
  final String ownerName;
  final String province;
  final String district;
  final String commune;
  final double area;
  final String forestType;
  final String treeSpecies;
  final int yearPlanted;
  final String status;

  ProjectItem({
    required this.id,
    required this.code,
    required this.name,
    required this.ownerId,
    required this.ownerCode,
    required this.ownerName,
    required this.province,
    required this.district,
    required this.commune,
    required this.area,
    required this.forestType,
    required this.treeSpecies,
    required this.yearPlanted,
    required this.status,
  });
}

class ProjectListPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProjectListPage({super.key, required this.user});

  @override
  State<ProjectListPage> createState() => _ProjectListPageState();
}

class _ProjectListPageState extends State<ProjectListPage> with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  String? _errorMessage;

  List<ProjectItem> _allProjects = [];
  List<ProjectItem> _filteredProjects = [];

  // Filter values
  String _searchQuery = "";
  String _selectedStatus = "all";
  String? _selectedOwnerCode;

  // DB Metadata
  List<Map<String, dynamic>> _owners = [];
  bool _isAdmin = false;
  bool _isOwner = false;
  String? _currentOwnerId;
  String? _currentOwnerCode;
  String? _currentOwnerProvince;
  List<String> _speciesList = ['Keo', 'Thông', 'Cao su', 'Keo Lai', 'Bạch đàn'];

  // Tab controller for Admin
  TabController? _tabController;
  int _activeTabIndex = 0;

  // Commune maps copied from web dashboard for realistic form loading
  final Map<String, List<String>> _communeMap = const {
    'Lâm Đồng': ['Tân Châu', 'Gia Hiệp', 'Lộc Sơn', 'Liên Nghĩa', 'Phường 2', 'Lộc Thanh', 'Đại Lào', 'Lộc Nga', 'Lộc Phát'],
    'Đắk Lắk': ['Hòa Phong', 'Ea Wer', 'Ea Bar', 'Hòa Thuận', 'Tân Lập', 'Ea Kao', 'Krông Na', 'Ea Tiêu', 'Ea Ktur'],
    'Gia Lai': ['Ia Pal', 'Ia Hlốp', 'Phường Diên Hồng', 'Ia Kring', 'Chư Á', 'Ia Tiêm', 'Ia Sao', 'Ia Der'],
    'Quảng Trị': ['Tà Long', 'Hướng Hiệp', 'Phường 1', 'Phường 5', 'Gio Mỹ', 'Cam Thành', 'Triệu Độ', 'Hải Quy'],
    'Quảng Nam': ['Trà Mai', 'Trà Cang', 'Phường An Mỹ', 'Phường Phước Hòa', 'Trà Linh', 'Trà Don', 'Trà Leng', 'Trà Dơn'],
    'Đắk Nông': ['Quảng Tâm', 'Đắk Rung', 'Nhân Cơ', 'Kiến Đức', 'Đắk Wer', 'Đắk Ru', 'Quảng Tín'],
  };

  @override
  void initState() {
    super.initState();
    final role = widget.user['role']?.toString() ?? '';
    _isAdmin = (role == 'platform_admin' || role == 'admin');
    _isOwner = (role == 'forest_owner' || role == 'owner');

    if (_isAdmin) {
      _tabController = TabController(length: 2, vsync: this);
      _tabController!.addListener(() {
        if (_tabController!.indexIsChanging) return;
        setState(() {
          _activeTabIndex = _tabController!.index;
          _applyFilters();
        });
      });
    }

    _fetchData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("Người dùng chưa đăng nhập.");

      // 1. Fetch user profile
      final profile = await _supabase
          .from('profiles')
          .select('role, owner_id')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) throw Exception("Không tìm thấy thông tin profile.");

      _currentOwnerId = profile['owner_id'];

      // 2. Fetch owners data
      final ownersRes = await _supabase
          .from('forest_owners')
          .select('id, owner_code, owner_name, address');
      
      _owners = List<Map<String, dynamic>>.from(ownersRes);

      if (_isOwner && _currentOwnerId != null) {
        final ownerData = _owners.firstWhere((o) => o['id'] == _currentOwnerId, orElse: () => {});
        _currentOwnerCode = ownerData['owner_code'];
        _currentOwnerProvince = ownerData['address']; // In web this is stored in address
      }

      // Fetch carbon factors for species dropdown
      try {
        final factorsRes = await _supabase.from('carbon_factors').select('species');
        final fetchedSpecies = List<String>.from(factorsRes.map((f) => f['species']?.toString()).where((s) => s != null && s.isNotEmpty));
        if (fetchedSpecies.isNotEmpty) {
          _speciesList = fetchedSpecies.toSet().toList();
        }
      } catch (_) {
        // Keep default species list
      }

      // 3. Fetch projects
      List<dynamic> projectsData = [];
      try {
        var query = _supabase.from('projects').select('*');
        if (_isOwner && _currentOwnerCode != null) {
          query = query.eq('owner_code', _currentOwnerCode!);
        }
        projectsData = await query;
      } catch (e) {
        // Fallback to forest_projects
        var query = _supabase.from('forest_projects').select('*');
        if (_isOwner && _currentOwnerId != null) {
          query = query.eq('owner_id', _currentOwnerId!);
        }
        projectsData = await query;
      }

      // Map to items
      final ownersMap = {for (var o in _owners) o['id']: o};

      _allProjects = projectsData.map<ProjectItem>((p) {
        final ownerObj = ownersMap[p['owner_id']];
        final oCode = p['owner_code']?.toString() ?? ownerObj?['owner_code']?.toString() ?? '';
        final oName = ownerObj?['owner_name']?.toString() ?? '';
        final oId = p['owner_id']?.toString() ?? ownerObj?['id']?.toString() ?? '';

        return ProjectItem(
          id: p['id']?.toString() ?? '',
          code: p['project_code']?.toString() ?? p['code']?.toString() ?? 'PRJ',
          name: p['project_name']?.toString() ?? p['name']?.toString() ?? 'Không tên',
          ownerId: oId,
          ownerCode: oCode,
          ownerName: oName,
          province: p['province']?.toString() ?? '',
          district: p['district']?.toString() ?? '',
          commune: p['commune']?.toString() ?? '',
          area: double.tryParse(p['area_ha']?.toString() ?? p['area']?.toString() ?? '') ?? 0.0,
          forestType: p['forest_type']?.toString() ?? '',
          treeSpecies: p['tree_species']?.toString() ?? '',
          yearPlanted: int.tryParse(p['year_planted']?.toString() ?? '') ?? DateTime.now().year,
          status: p['status']?.toString() ?? 'pending',
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
    List<ProjectItem> list = List.from(_allProjects);

    // Filter by Admin Tab (Pending vs All)
    if (_isAdmin && _activeTabIndex == 1) {
      list = list.where((p) => p.status == 'pending').toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) => p.name.toLowerCase().contains(q) || p.code.toLowerCase().contains(q)).toList();
    }

    // Filter by status dropdown
    if (_selectedStatus != "all") {
      list = list.where((p) => p.status == _selectedStatus).toList();
    }

    // Filter by admin owner dropdown
    if (_isAdmin && _selectedOwnerCode != null) {
      list = list.where((p) => p.ownerCode == _selectedOwnerCode).toList();
    }

    setState(() {
      _filteredProjects = list;
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'active':
        return const Color(0xFF2E7D32); // Green
      case 'pending':
        return const Color(0xFFEF6C00); // Orange
      case 'rejected':
        return const Color(0xFFC62828); // Red
      case 'surveying':
        return const Color(0xFF1565C0); // Blue
      default:
        return const Color(0xFF78909C); // Grey
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Đã duyệt';
      case 'active':
        return 'Hoạt động';
      case 'pending':
        return 'Chờ phê duyệt';
      case 'rejected':
        return 'Bị từ chối';
      case 'surveying':
        return 'Đang khảo sát';
      default:
        return status;
    }
  }

  Future<void> _approveProjectDirectly(ProjectItem project, bool approve) async {
    final nextStatus = approve ? 'approved' : 'rejected';

    try {
      setState(() {
        _isLoading = true;
      });

      // Update project table or forest_projects
      try {
        await _supabase
            .from('projects')
            .update({'status': nextStatus})
            .eq('id', project.id);
      } catch (e) {
        await _supabase
            .from('forest_projects')
            .update({'status': nextStatus})
            .eq('id', project.id);
      }

      // Add notification to owner
      // Find owner's profile user ID
      final ownerProfiles = await _supabase
          .from('profiles')
          .select('id')
          .eq('owner_id', project.ownerId);
      
      final String? targetUserId = ownerProfiles.isNotEmpty ? ownerProfiles[0]['id']?.toString() : null;

      await _supabase
          .from('notifications')
          .insert({
            'user_id': targetUserId,
            'title': approve ? 'Dự án đã được duyệt' : 'Dự án bị từ chối',
            'message': 'Dự án rừng "${project.name}" của bạn đã được Admin ${approve ? 'phê duyệt và chuyển sang hoạt động' : 'từ chối phê duyệt'}.',
            'type': 'project',
            'is_read': false
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Đã phê duyệt dự án thành công!' : 'Đã từ chối phê duyệt dự án.'),
          backgroundColor: approve ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
        ),
      );

      _fetchData();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  void _showProjectFormModal({ProjectItem? project}) {
    final isEdit = project != null;
    final formKey = GlobalKey<FormState>();

    // Form controllers
    final nameController = TextEditingController(text: project?.name ?? '');
    final areaController = TextEditingController(text: project?.area.toString() ?? '');
    final yearController = TextEditingController(text: project?.yearPlanted.toString() ?? DateTime.now().year.toString());

    // Form dropdown selections
    String? selectedOwnerCodeVal = isEdit ? project.ownerCode : (_isOwner ? _currentOwnerCode : (_owners.isNotEmpty ? _owners[0]['owner_code'] : null));
    String selectedProvince = isEdit ? project.province : (_isOwner ? (_currentOwnerProvince ?? 'Lâm Đồng') : _communeMap.keys.first);
    List<String> communes = List<String>.from(_communeMap[selectedProvince] ?? []);
    String selectedCommune = isEdit ? project.commune : (communes.isNotEmpty ? communes[0] : '');
    String selectedFormStatus = isEdit ? project.status : (_isAdmin ? 'approved' : 'pending');
    String selectedForestType = isEdit ? (project.forestType.isNotEmpty ? project.forestType : 'Rừng trồng') : 'Rừng trồng';
    String selectedSpeciesVal = isEdit ? (project.treeSpecies.isNotEmpty ? project.treeSpecies : 'Keo') : 'Keo';

    // Safety checks
    if (communes.isNotEmpty && !communes.contains(selectedCommune)) {
      communes.add(selectedCommune);
    }
    if (!_speciesList.contains(selectedSpeciesVal)) {
      _speciesList.add(selectedSpeciesVal);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
            final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final labelColor = isDark ? Colors.white70 : const Color(0xFF334155);

            return Container(
              padding: EdgeInsets.only(
                top: 24, left: 24, right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48, height: 5,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Text(
                        isEdit ? "Chỉnh sửa thông tin dự án" : "Đăng ký dự án mới",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 16),

                      // Info/Crown banner
                      if (_isAdmin && !isEdit)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.15)),
                          ),
                          child: Row(
                            children: [
                              const Text('👑', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  text: const TextSpan(
                                    style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), height: 1.4),
                                    children: [
                                      TextSpan(text: "Admin tạo dự án ", style: TextStyle(fontWeight: FontWeight.bold)),
                                      TextSpan(text: "sẽ tự động kích hoạt ở trạng thái "),
                                      TextSpan(text: "Đã duyệt", style: TextStyle(fontWeight: FontWeight.bold)),
                                      TextSpan(text: " ."),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_isOwner && !isEdit)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Hạn chế khu vực: Bạn chỉ có thể đăng ký dự án thuộc tỉnh $_currentOwnerProvince.",
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Tên dự án
                      Text("Tên dự án *", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: labelColor)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        style: TextStyle(color: textColor, fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: "Tên dự án Keo/Thông...",
                          hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? "Vui lòng nhập tên dự án" : null,
                      ),
                      const SizedBox(height: 16),

                      // Chủ rừng (Dropdown if admin, read-only if owner)
                      Text("Chủ rừng *", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: labelColor)),
                      const SizedBox(height: 6),
                      if (_isAdmin)
                        DropdownButtonFormField<String>(
                          value: selectedOwnerCodeVal,
                          dropdownColor: surfaceColor,
                          style: TextStyle(color: textColor, fontSize: 13.5),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          items: _owners.map((owner) {
                            final code = owner['owner_code']?.toString() ?? '';
                            final name = owner['owner_name']?.toString() ?? '';
                            return DropdownMenuItem(
                              value: code,
                              child: Text("$name ($code)", style: TextStyle(color: textColor, fontSize: 13.5)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setModalState(() {
                              selectedOwnerCodeVal = val;
                            });
                          },
                        )
                      else
                        TextFormField(
                          initialValue: "${widget.user['fullName']} ($_currentOwnerCode)",
                          enabled: false,
                          style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 13.5),
                          decoration: InputDecoration(
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Tỉnh thành & Xã
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Tỉnh thành *", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: labelColor)),
                                const SizedBox(height: 6),
                                if (_isAdmin)
                                  DropdownButtonFormField<String>(
                                    value: selectedProvince,
                                    dropdownColor: surfaceColor,
                                    style: TextStyle(color: textColor, fontSize: 13.5),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                    items: _communeMap.keys.map((prov) {
                                      return DropdownMenuItem(
                                        value: prov,
                                        child: Text(prov, style: TextStyle(color: textColor, fontSize: 13.5)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setModalState(() {
                                          selectedProvince = val;
                                          communes = List<String>.from(_communeMap[val] ?? []);
                                          selectedCommune = communes.isNotEmpty ? communes[0] : '';
                                        });
                                      }
                                    },
                                  )
                                else
                                  TextFormField(
                                    initialValue: selectedProvince,
                                    enabled: false,
                                    style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 13.5),
                                    decoration: InputDecoration(
                                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                      filled: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Xã *", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: labelColor)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: selectedCommune,
                                  dropdownColor: surfaceColor,
                                  style: TextStyle(color: textColor, fontSize: 13.5),
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  items: communes.map((c) {
                                    return DropdownMenuItem(
                                      value: c,
                                      child: Text(c, style: TextStyle(color: textColor, fontSize: 13.5)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() {
                                        selectedCommune = val;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Loại rừng & Loài cây
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Loại rừng", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: labelColor)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: selectedForestType,
                                  dropdownColor: surfaceColor,
                                  style: TextStyle(color: textColor, fontSize: 13.5),
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: "Rừng trồng", child: Text("Rừng trồng", style: TextStyle(fontSize: 13.5))),
                                    DropdownMenuItem(value: "Rừng tự nhiên", child: Text("Rừng tự nhiên", style: TextStyle(fontSize: 13.5))),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() {
                                        selectedForestType = val;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Loài cây", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: labelColor)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: selectedSpeciesVal,
                                  dropdownColor: surfaceColor,
                                  style: TextStyle(color: textColor, fontSize: 13.5),
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  items: _speciesList.map((s) {
                                    return DropdownMenuItem(
                                      value: s,
                                      child: Text(s, style: TextStyle(color: textColor, fontSize: 13.5)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() {
                                        selectedSpeciesVal = val;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Năm trồng & Diện tích
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Năm trồng", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: labelColor)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: yearController,
                                  style: TextStyle(color: textColor, fontSize: 13.5),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return "Nhập năm trồng";
                                    if (int.tryParse(value) == null) return "Phải là số nguyên";
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Diện tích (ha) *", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: labelColor)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: areaController,
                                  style: TextStyle(color: textColor, fontSize: 13.5),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    hintText: "Ví dụ: 250.75",
                                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return "Nhập diện tích";
                                    if (double.tryParse(value) == null) return "Phải là số";
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Trạng thái (Admin only / Owner read-only)
                      Text("Trạng thái", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: labelColor)),
                      const SizedBox(height: 6),
                      if (_isAdmin)
                        DropdownButtonFormField<String>(
                          value: selectedFormStatus,
                          dropdownColor: surfaceColor,
                          style: TextStyle(color: textColor, fontSize: 13.5),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          items: (isEdit
                                  ? ['pending', 'approved', 'rejected', 'active', 'suspended']
                                  : ['approved', 'pending'])
                              .map((s) {
                            String label = s;
                            if (s == 'approved') label = 'Đã duyệt';
                            if (s == 'pending') label = 'Chờ duyệt';
                            if (s == 'rejected') label = 'Bị từ chối';
                            if (s == 'active') label = 'Hoạt động';
                            if (s == 'suspended') label = 'Tạm dừng';

                            return DropdownMenuItem(
                              value: s,
                              child: Text(label, style: TextStyle(color: textColor, fontSize: 13.5)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedFormStatus = val;
                              });
                            }
                          },
                        )
                      else
                        TextFormField(
                          initialValue: selectedFormStatus == 'approved'
                              ? 'Đã duyệt'
                              : (selectedFormStatus == 'pending'
                                  ? 'Chờ duyệt'
                                  : (selectedFormStatus == 'rejected'
                                      ? 'Bị từ chối'
                                      : (selectedFormStatus == 'active' ? 'Hoạt động' : 'Tạm dừng'))),
                          enabled: false,
                          style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 13.5),
                          decoration: InputDecoration(
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Save/Cancel buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Hủy"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (formKey.currentState?.validate() ?? false) {
                                  Navigator.pop(context);
                                  await _saveProject(
                                    id: project?.id,
                                    name: nameController.text.trim(),
                                    ownerCode: selectedOwnerCodeVal ?? '',
                                    province: selectedProvince,
                                    district: '', // Quận/Huyện bị loại bỏ hoàn toàn
                                    commune: selectedCommune,
                                    forestType: selectedForestType,
                                    treeSpecies: selectedSpeciesVal,
                                    area: double.parse(areaController.text),
                                    yearPlanted: int.parse(yearController.text),
                                    status: selectedFormStatus,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF107C41),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.save, size: 16),
                                  SizedBox(width: 6),
                                  Text("Lưu", style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveProject({
    String? id,
    required String name,
    required String ownerCode,
    required String province,
    required String district,
    required String commune,
    required String forestType,
    required String treeSpecies,
    required double area,
    required int yearPlanted,
    required String status,
  }) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Find owner_id corresponding to ownerCode
      final ownerObj = _owners.firstWhere((o) => o['owner_code'] == ownerCode, orElse: () => {});
      final ownerId = ownerObj['id'];

      final Map<String, dynamic> projectsMap = {
        'project_name': name,
        'name': name,
        'owner_id': ownerId,
        'owner_code': ownerCode,
        'province': province,
        'district': district,
        'commune': commune,
        'forest_type': forestType,
        'tree_species': treeSpecies,
        'year_planted': yearPlanted,
        'area_ha': area,
        'area': area,
        'status': status,
      };

      if (id != null) {
        // Edit existing project
        projectsMap['id'] = id;
        try {
          await _supabase.from('projects').update(projectsMap).eq('id', id);
        } catch (_) {
          await _supabase.from('forest_projects').update(projectsMap).eq('id', id);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật dự án thành công!')));
      } else {
        // Create new project
        projectsMap['project_code'] = 'PRJ-${DateTime.now().millisecondsSinceEpoch % 100000}';
        try {
          await _supabase.from('projects').insert(projectsMap);
        } catch (_) {
          await _supabase.from('forest_projects').insert(projectsMap);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đăng ký dự án mới thành công!')));
      }

      _fetchData();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  void _showProjectDetailsBottomSheet(ProjectItem project) {
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
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48, height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        Text(
                          project.code,
                          style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      _getStatusLabel(project.status),
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              _buildDetailRow("Chủ rừng", project.ownerName, subColor, textColor),
              _buildDetailRow("Mã chủ rừng", project.ownerCode, subColor, textColor),
              _buildDetailRow("Khu vực", "${project.province} / ${project.district} / ${project.commune}", subColor, textColor),
              _buildDetailRow("Diện tích", "${project.area.toStringAsFixed(2)} ha", subColor, textColor),
              _buildDetailRow("Loại rừng", project.forestType, subColor, textColor),
              _buildDetailRow("Loài cây", project.treeSpecies, subColor, textColor),
              _buildDetailRow("Năm trồng", project.yearPlanted.toString(), subColor, textColor),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("Đóng", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, Color labelColor, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? "—" : value,
              style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF64748B);

    Widget searchAndFilter = Column(
      children: [
        // Search bar
        TextField(
          style: TextStyle(color: textPrimary),
          decoration: InputDecoration(
            hintText: "Tìm kiếm dự án...",
            hintStyle: TextStyle(color: textSecondary),
            prefixIcon: const Icon(Icons.search, color: AppColors.primary),
            filled: true,
            fillColor: cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
            ),
          ),
          onChanged: (val) {
            _searchQuery = val;
            _applyFilters();
          },
        ),
        const SizedBox(height: 12),

        // Dropdown filters Row
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedStatus,
                dropdownColor: cardBg,
                style: TextStyle(color: textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: cardBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text("Tất cả trạng thái")),
                  DropdownMenuItem(value: 'pending', child: Text("Chờ duyệt")),
                  DropdownMenuItem(value: 'approved', child: Text("Đã duyệt")),
                  DropdownMenuItem(value: 'rejected', child: Text("Bị từ chối")),
                  DropdownMenuItem(value: 'active', child: Text("Hoạt động")),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedStatus = val;
                      _applyFilters();
                    });
                  }
                },
              ),
            ),
            if (_isAdmin && _owners.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedOwnerCode,
                  dropdownColor: cardBg,
                  style: TextStyle(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text("Tất cả chủ rừng")),
                    ..._owners.map((o) {
                      final code = o['owner_code']?.toString() ?? '';
                      final name = o['owner_name']?.toString() ?? '';
                      return DropdownMenuItem(
                        value: code,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedOwnerCode = val;
                      _applyFilters();
                    });
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );

    Widget projectList = _isLoading
        ? const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        : _errorMessage != null
            ? Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Lỗi: $_errorMessage", style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _fetchData, child: const Text("Thử lại")),
                    ],
                  ),
                ),
              )
            : _filteredProjects.isEmpty
                ? const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.park_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text("Không tìm thấy dự án phù hợp", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                : Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: _filteredProjects.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final p = _filteredProjects[index];
                        final statusColor = _getStatusColor(p.status);

                        return Card(
                          elevation: 2,
                          color: cardBg,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: InkWell(
                            onTap: () => _showProjectDetailsBottomSheet(p),
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top row: code and status
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        p.code,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                          color: Colors.blue,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _getStatusLabel(p.status),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Project Name
                                  Text(
                                    p.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // Owner name and province
                                  Text(
                                    "Chủ rừng: ${p.ownerName} · Tỉnh: ${p.province}",
                                    style: TextStyle(color: textSecondary, fontSize: 12),
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 12),

                                  // Details line: area, tree, year
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Diện tích", style: TextStyle(color: textSecondary, fontSize: 10)),
                                          Text("${p.area.toStringAsFixed(1)} ha", style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Loài cây", style: TextStyle(color: textSecondary, fontSize: 10)),
                                          Text(p.treeSpecies.isEmpty ? "—" : p.treeSpecies, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Năm trồng", style: TextStyle(color: textSecondary, fontSize: 10)),
                                          Text(p.yearPlanted.toString(), style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // Quick approve buttons for admin if pending status
                                  if (_isAdmin && p.status == 'pending') ...[
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () => _approveProjectDirectly(p, false),
                                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                                          child: const Text("Từ chối"),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () => _approveProjectDirectly(p, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text("Phê duyệt"),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    // Sửa button
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () => _showProjectFormModal(project: p),
                                          icon: const Icon(Icons.edit, size: 14),
                                          label: const Text("Sửa", style: TextStyle(fontSize: 12)),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );

    // Build tabs if Admin, otherwise direct layouts
    Widget bodyContent;
    if (_isAdmin) {
      bodyContent = Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: "Tất cả dự án (${_allProjects.length})"),
              Tab(text: "Chờ phê duyệt (${_allProjects.where((p) => p.status == 'pending').length})"),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              children: [
                searchAndFilter,
                const SizedBox(height: 12),
                projectList,
              ],
            ),
          ),
        ],
      );
    } else {
      bodyContent = Column(
        children: [
          searchAndFilter,
          const SizedBox(height: 12),
          projectList,
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Padding(
        padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
        child: bodyContent,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProjectFormModal(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        tooltip: "Đăng ký dự án mới",
        child: const Icon(Icons.add),
      ),
    );
  }
}
