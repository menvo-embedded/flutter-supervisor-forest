import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../logbook/bloc/logbook_bloc.dart';
import '../../logbook/bloc/logbook_event.dart';
import '../../logbook/pages/logbook_list_page.dart';
import '../../checkin/pages/checkin_page.dart';
import '../../inventory/pages/inventory_page.dart';
import '../../profile/pages/profile_page.dart';
import '../../sync/bloc/sync_bloc.dart';
import '../../sync/bloc/sync_event.dart';
import '../../sync/widgets/sync_status_banner.dart';
import 'analytics_page.dart';
import 'dashboard_page.dart';
import 'gis_map_page.dart';

/// Khung điều hướng chính theo vai trò người dùng.
/// Worker: Trang chủ / Nhật ký / Check-in / Hồ sơ.
/// Owner/Admin: Tổng quan / Bản đồ / Phân tích / Nhật ký / Hồ sơ.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    if (authState is! AuthAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      });

      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final user = authState.user;

    if (!_initialized) {
      _initialized = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<LogbookBloc>().add(
              LogbookLoadRequested(
                userId: user.isWorker ? user.id : null,
              ),
            );

        context.read<SyncBloc>().add(const SyncStatusChecked());
      });
    }

    final List<Widget> pages;
    final List<String> titles;
    final List<BottomNavigationBarItem> items;

    if (user.isWorker) {
      pages = [
        DashboardPage(
          user: user,
          onNavigateTab: (index) => setState(() => _index = index),
        ),
        LogbookListPage(user: user),
        CheckinPage(user: user),
        const InventoryPage(),
        ProfilePage(user: user),
      ];

      titles = const [
        'Trang chủ',
        'Nhật ký',
        'Check-in',
        'Kiểm kê',
        'Hồ sơ',
      ];

      items = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home_rounded),
          label: 'Trang chủ',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.menu_book_outlined),
          activeIcon: Icon(Icons.menu_book_rounded),
          label: 'Nhật ký',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.gps_fixed_outlined),
          activeIcon: Icon(Icons.gps_fixed_rounded),
          label: 'Check-in',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.park_outlined),
          activeIcon: Icon(Icons.park_rounded),
          label: 'Kiểm kê',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_rounded),
          activeIcon: Icon(Icons.person_rounded),
          label: 'Hồ sơ',
        ),
      ];
    } else {
      pages = [
        DashboardPage(user: user),
        const GisMapPage(),
        const AnalyticsPage(),
        LogbookListPage(user: user),
        ProfilePage(user: user),
      ];

      titles = const [
        'Tổng quan',
        'Bản đồ',
        'Phân tích',
        'Nhật ký',
        'Hồ sơ',
      ];

      items = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard_rounded),
          label: 'Tổng quan',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map_outlined),
          activeIcon: Icon(Icons.map_rounded),
          label: 'Bản đồ',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics_outlined),
          activeIcon: Icon(Icons.analytics_rounded),
          label: 'Phân tích',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.menu_book_outlined),
          activeIcon: Icon(Icons.menu_book_rounded),
          label: 'Nhật ký',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_rounded),
          activeIcon: Icon(Icons.person_rounded),
          label: 'Hồ sơ',
        ),
      ];
    }

    if (_index >= pages.length) {
      _index = 0;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(titles[_index]),
      ),
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
        ),
        items: items,
      ),
    );
  }
}
