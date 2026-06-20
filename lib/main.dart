import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'core/constants/supabase_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/services/location_service.dart';
import 'core/services/storage_service.dart';

// Auth
import 'data/auth/datasources/auth_local_data_source.dart';
import 'data/auth/datasources/auth_remote_data_source.dart';
import 'data/auth/repositories/auth_repository_impl.dart';
import 'presentation/auth/bloc/auth_bloc.dart';
import 'presentation/auth/bloc/auth_event.dart';
import 'presentation/auth/bloc/auth_state.dart';
import 'presentation/auth/pages/login_page.dart';

// Logbook
import 'data/logbook/datasources/logbook_local_data_source.dart';
import 'data/logbook/datasources/logbook_remote_data_source.dart';
import 'data/logbook/repositories/logbook_repository_impl.dart';
import 'presentation/logbook/bloc/logbook_bloc.dart';

// Checkin
import 'data/checkin/datasources/checkin_local_data_source.dart';
import 'data/checkin/datasources/checkin_remote_data_source.dart';
import 'data/checkin/repositories/checkin_repository_impl.dart';
import 'presentation/checkin/bloc/checkin_bloc.dart';

// Sync
import 'data/sync/sync_repository.dart';
import 'presentation/sync/bloc/sync_bloc.dart';

// Home
import 'presentation/home/pages/home_shell.dart';

// Theme
import 'presentation/theme/bloc/theme_bloc.dart';
import 'presentation/theme/bloc/theme_event.dart';
import 'presentation/theme/bloc/theme_state.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.anonKey,
  );
  runApp(const QLRApp());
}

/// ROOT WIDGET - Cấu hình Dependency Injection (thủ công) + MultiBlocProvider
///
/// 🔧 CHUYỂN SANG PRODUCTION (kết nối Web Server thật):
///    Thay `AuthRemoteDataSourceMock()`     -> `AuthRemoteDataSourceImpl()`
///    Thay `LogbookRemoteDataSourceMock()`  -> `LogbookRemoteDataSourceImpl()`
///    Thay `CheckinRemoteDataSourceMock()`  -> `CheckinRemoteDataSourceImpl()`
///    và cập nhật `ApiConstants.baseUrl` trong core/constants/api_constants.dart
class QLRApp extends StatelessWidget {
  const QLRApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ── Shared services ──
    final storage = StorageService();
    final locationService = LocationService();

    // ── Auth module ──
    final authLocal = AuthLocalDataSourceImpl(storage: storage);
    final authRemote = AuthRemoteDataSourceSupabase();
    final authRepo = AuthRepositoryImpl(remote: authRemote, local: authLocal);

    // ── Logbook module (Module 8) ──
    final logbookLocal = LogbookLocalDataSourceImpl(storage: storage);
    final logbookRemote = LogbookRemoteDataSourceSupabase();
    final logbookRepo = LogbookRepositoryImpl(local: logbookLocal, remote: logbookRemote, authLocal: authLocal);

    // ── Checkin module (Module 6/9) ──
    final checkinLocal = CheckinLocalDataSourceImpl(storage: storage);
    final checkinRemote = CheckinRemoteDataSourceSupabase();
    final checkinRepo = CheckinRepositoryImpl(local: checkinLocal, remote: checkinRemote, authLocal: authLocal);

    // ── Sync orchestrator (Module 9 - Offline) ──
    final syncRepo = SyncRepository(logbookRepo: logbookRepo, checkinRepo: checkinRepo);

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeBloc()..add(const ThemeCheckRequested())),
        BlocProvider(create: (_) => AuthBloc(repository: authRepo)..add(const AuthCheckRequested())),
        BlocProvider(create: (_) => LogbookBloc(repository: logbookRepo, locationService: locationService)),
        BlocProvider(create: (_) => CheckinBloc(repository: checkinRepo, locationService: locationService)),
        BlocProvider(create: (_) => SyncBloc(repository: syncRepo)),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          final currentThemeMode = themeState.themeMode;
          return kIsWeb
              ? Center(
                  child: Container(
                    width: 420,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      child: MaterialApp(
                        title: 'QLR',
                        debugShowCheckedModeBanner: false,
                        theme: AppTheme.lightTheme,
                        darkTheme: AppTheme.darkTheme,
                        themeMode: currentThemeMode,
                        initialRoute: '/splash',
                        routes: {
                          '/splash': (_) => const _SplashPage(),
                          '/login': (_) => const LoginPage(),
                          '/home': (_) => const HomeShell(),
                        },
                      ),
                    ),
                  ),
                )
              : MaterialApp(
                  title: 'QLR',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: currentThemeMode,
                  initialRoute: '/splash',
                  routes: {
                    '/splash': (_) => const _SplashPage(),
                    '/login': (_) => const LoginPage(),
                    '/home': (_) => const HomeShell(),
                  },
                );
        },
      ),
    );
  }
}

/// Màn hình chờ - kiểm tra session đã lưu (Module 3: AuthCheckRequested)
class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
        } else if (state is AuthUnauthenticated || state is AuthError) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset('assets/logo.png', width: 84, height: 84, fit: BoxFit.cover),
          ),
          const SizedBox(height: 20),
          const Text('QLR', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
        ])),
      ),
    );
  }
}
