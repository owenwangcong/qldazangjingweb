import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// 展卷跨列音效（DS4 预留接口的默认实现，2026-07-20 用户点名启用）：
/// 一枚程序化生成的干脆短「嗒」（assets/audio/scroll_tick.wav，~55ms）。
///
/// 设计要点：
/// - 低延迟模式 + 预载源，跨列时 seek(0)+resume 复触发，40ms 节流下
///   连滚呈「嗒嗒嗒」展卷感；
/// - **尽力而为**：任何初始化/播放失败静默吞掉（widget 测试无插件通道、
///   个别机型音频栈异常都不得影响滚动本身）；
/// - 无马达设备（如 Tab S6 Lite）上这是唯一可感知的跨列反馈。
class ScrollTickSound {
  ScrollTickSound._();

  static final ScrollTickSound instance = ScrollTickSound._();

  AudioPlayer? _player;
  Future<void>? _loading;

  Future<void> _ensureLoaded() {
    return _loading ??= () async {
      final p = AudioPlayer();
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setVolume(0.6);
      await p.setSource(AssetSource('audio/scroll_tick.wav'));
      _player = p;
    }()
        .catchError((_) {}); // 尽力而为：失败即静音。
  }

  /// 触发一声「嗒」。同步返回，播放异步进行且吞错。
  void tick() {
    unawaited(() async {
      try {
        await _ensureLoaded();
        final p = _player;
        if (p == null) return;
        await p.seek(Duration.zero);
        await p.resume();
      } catch (_) {
        // 静默：音效永不影响滚动。
      }
    }());
  }
}
