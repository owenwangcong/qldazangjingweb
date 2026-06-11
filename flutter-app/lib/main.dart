import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/connectivity_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/chinese_converter.dart';
import 'data/datasources/local/isar_service.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Eager init of the offline core: local DB (with first-launch seed) and the
  // OpenCC dictionaries. Everything the UI renders comes from these — no
  // network is touched on the startup path.
  final isarService = await IsarService.open();
  final converter = await ChineseConverter.load();
  final connectivity = ConnectivityService();

  runApp(
    ProviderScope(
      overrides: [
        isarServiceProvider.overrideWithValue(isarService),
        chineseConverterProvider.overrideWithValue(converter),
        connectivityServiceProvider.overrideWithValue(connectivity),
      ],
      child: const QldzjApp(),
    ),
  );
}

class QldzjApp extends ConsumerStatefulWidget {
  const QldzjApp({super.key});

  @override
  ConsumerState<QldzjApp> createState() => _QldzjAppState();
}

class _QldzjAppState extends ConsumerState<QldzjApp> {
  @override
  void initState() {
    super.initState();
    // Start draining the offline outbox in the background.
    ref.read(syncManagerProvider).start();
  }

  @override
  Widget build(BuildContext context) {
    final themeKey = ref.watch(settingsProvider.select((s) => s.themeKey));
    return MaterialApp.router(
      title: '乾隆大藏经',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(AppThemeId.fromKey(themeKey)),
      routerConfig: appRouter,
    );
  }
}
