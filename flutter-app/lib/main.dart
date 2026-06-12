import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/ink/canvas/ink_scroll_canvas.dart';
import 'core/ink/shading/ink_paper_background.dart';
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
    // 纸纹 shader 预热（烘焙位图前置依赖）：避免首屏纯色兜底帧。
    InkPaperBackground.warmUp();
  }

  @override
  Widget build(BuildContext context) {
    final themeKey = ref.watch(settingsProvider.select((s) => s.themeKey));
    // System font until the persisted choice finishes its background load,
    // then the whole tree swaps — startup never blocks on font IO.
    final fontFamily = ref.watch(fontControllerProvider).activeFamily;
    return MaterialApp.router(
      title: '乾隆大藏经',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(AppThemeId.fromKey(themeKey), fontFamily: fontFamily),
      routerConfig: appRouter,
      // 一卷画布（P2.1）：持久画卷层跨路由不重建，所有页面浮于其上。
      builder: (context, child) => InkScrollCanvas(child: child!),
    );
  }
}
