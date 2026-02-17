import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/pos_repository.dart';
import 'l10n/app_i18n.dart';
import 'pages/main_shell_page.dart';
import 'services/app_settings_store.dart';
import 'state/pos_controller.dart';

class TeaStoreApp extends StatefulWidget {
  const TeaStoreApp({super.key});

  @override
  State<TeaStoreApp> createState() => _TeaStoreAppState();
}

class _TeaStoreAppState extends State<TeaStoreApp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loadingController;
  static const _minSplashDuration = Duration(milliseconds: 1200);
  PosController? _controller;
  Object? _startupError;
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      animationBehavior: AnimationBehavior.preserve,
    )..repeat();
    _startBootstrap();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  Future<void> _startBootstrap() async {
    setState(() {
      _booting = true;
      _startupError = null;
    });
    try {
      final controller = await _bootstrap();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _booting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _startupError = e;
        _booting = false;
      });
    }
  }

  Future<PosController> _bootstrap() async {
    final startAt = DateTime.now();
    final repository = PosRepository();
    await repository.init();
    final controller = PosController(
      repository: repository,
      settingsStore: AppSettingsStore(),
    );
    await controller.loadProducts();
    final elapsed = DateTime.now().difference(startAt);
    if (elapsed < _minSplashDuration) {
      await Future<void>.delayed(_minSplashDuration - elapsed);
    }
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    final fallbackI18n = AppI18n(AppLanguage.th);
    if (_booting) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: RotationTransition(
              turns: _loadingController,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
            ),
          ),
        ),
      );
    }
    if (_startupError != null || _controller == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        supportedLocales: const [Locale('th'), Locale('zh'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    fallbackI18n.startupFailed,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${_startupError ?? 'Unknown startup error'}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _startBootstrap,
                    child: Text(fallbackI18n.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final controller = _controller!;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final i18n = controller.i18n;
        return MaterialApp(
          title: i18n.appTitle,
          debugShowCheckedModeBanner: false,
          locale: i18n.locale,
          supportedLocales: const [Locale('th'), Locale('zh'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1976D2),
              secondary: Color(0xFF1976D2),
              surface: Colors.white,
            ),
            useMaterial3: true,
            splashFactory: NoSplash.splashFactory,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            scaffoldBackgroundColor: Colors.white,
            cardColor: Colors.white,
            canvasColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF1976D2),
              elevation: 0,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                overlayColor: Colors.transparent,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1976D2),
                overlayColor: Colors.transparent,
              ),
            ),
            iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFF1976D2),
                overlayColor: Colors.transparent,
              ),
            ),
            chipTheme: const ChipThemeData(
              backgroundColor: Colors.white,
              selectedColor: Color(0xFF1976D2),
              secondarySelectedColor: Color(0xFF1976D2),
              disabledColor: Color(0xFFE3F2FD),
              checkmarkColor: Colors.white,
              side: BorderSide(color: Color(0xFF90CAF9), width: 1.2),
              shape: StadiumBorder(),
              padding: EdgeInsets.symmetric(horizontal: 8),
              labelStyle: TextStyle(color: Color(0xFF1565C0)),
            ),
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF90CAF9)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Color(0xFF1976D2),
                  width: 1.6,
                ),
              ),
            ),
          ),
          home: MainShellPage(controller: controller),
        );
      },
    );
  }
}
