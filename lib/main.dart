import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'services/offline_storage_service.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'services/api_service.dart';
import 'services/work_session_service.dart';
import 'services/geofencing_service.dart';
import 'services/background_location_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Offline storage'ı başlat
  await OfflineStorageService.initialize();
  
  // Connectivity service'i başlat
  await ConnectivityService().initialize();
  
  // Background location service'i başlat
  await BackgroundLocationService.initializeService();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('tr'); // Default to Turkish

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'tr';
    setState(() {
      _locale = Locale(languageCode);
    });
  }

  void changeLocale(Locale locale) async {
    setState(() {
      _locale = locale;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => LocaleNotifier(changeLocale)),
        ChangeNotifierProvider(
          create: (context) => AuthService(context.read<ApiService>())..checkAuthStatus(),
        ),
        ChangeNotifierProvider(
          create: (context) => SyncService(context.read<ApiService>()),
        ),
        ChangeNotifierProvider(
          create: (context) => WorkSessionService(context.read<ApiService>()),
        ),
        Provider(create: (_) => ConnectivityService()),
        Provider(create: (_) => GeofencingService()),
      ],
      child: Consumer<LocaleNotifier>(
        builder: (context, localeNotifier, child) {
          return Consumer3<AuthService, WorkSessionService, SyncService>(
            builder: (context, authService, workSessionService, syncService, _) {
              workSessionService.handleAuthChange(authService.currentUser, authService.token);
              if (authService.token != null) {
                syncService.setToken(authService.token!);
              }
              
              return MaterialApp(
                title: 'QuickCity Winterdienst',
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
                  useMaterial3: true,
                ),
                locale: _locale,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('tr', ''), // Turkish
                  Locale('en', ''), // English
                  Locale('de', ''), // German
                ],
                home: const AuthWrapper(),
                debugShowCheckedModeBanner: false,
              );
            },
          );
        },
      ),
    );
  }
}

class LocaleNotifier extends ChangeNotifier {
  final Function(Locale) _changeLocale;

  LocaleNotifier(this._changeLocale);

  void changeLocale(Locale locale) {
    _changeLocale(locale);
    notifyListeners();
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuthStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Uygulama ön plana geldiğinde sadece token durumunu kontrol et
    // Logout etmeyin, sadece background sync yapın
    if (state == AppLifecycleState.resumed) {
      final authService = Provider.of<AuthService>(context, listen: false);
      // Sadece token kontrolü yap, logout etme
      // Kullanıcı manuel olarak çıkış yapana kadar giriş yapmış kalır
      print('📱 App resumed - Token durumu kontrol ediliyor (logout edilmeyecek)');
      authService.checkTokenValidity();
    }
  }

  Future<void> _checkAuthStatus() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.checkAuthStatus();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Consumer<AuthService>(
      builder: (context, authService, child) {
        if (authService.isLoggedIn) {
          return const MainNavigationScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}