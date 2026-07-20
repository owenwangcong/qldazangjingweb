/// shell（reader_page）向翻页类阅读视图（横排 PagedReader / 竖排
/// VerticalReader）发起块级跳转的共享句柄：TOC / 书签 / 进度恢复都走
/// [jumpToBlock]。视图未挂载时挂起，attach 后自动执行。
class BlockJumpController {
  void Function(int blockIndex)? _handler;
  int? _pendingBlock;

  void jumpToBlock(int blockIndex) {
    final handler = _handler;
    if (handler != null) {
      handler(blockIndex);
    } else {
      _pendingBlock = blockIndex;
    }
  }

  void attach(void Function(int) handler) {
    _handler = handler;
    final pending = _pendingBlock;
    _pendingBlock = null;
    if (pending != null) handler(pending);
  }

  void detach(void Function(int) handler) {
    if (identical(_handler, handler)) _handler = null;
  }
}
