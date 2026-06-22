import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flyai/core/router/app_router.dart';
import 'package:flyai/core/theme/app_theme.dart';
import 'package:flyai/core/services/supabase_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flyai/core/providers/locale_provider.dart';
import 'package:flyai/core/constants/app_colors.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Supabase init
  await SupabaseService.initialize();

  runApp(
    const ProviderScope(
      child: FlyAIApp(),
    ),
  );
}

class FlyAIApp extends ConsumerWidget {
  const FlyAIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Synchronize AppColors state
    AppColors.isDark = themeMode == ThemeMode.dark;

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Fly AI',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      locale: locale,
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
