import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flyai/core/router/app_router.dart';
import 'package:flyai/core/theme/app_theme.dart';
import 'package:flyai/core/services/supabase_service.dart';
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
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Fly AI',
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
