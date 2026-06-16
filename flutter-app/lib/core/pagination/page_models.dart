import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// 翻页模式的页面模型（纯数据，不含 widget）。
///
/// 设计要点：阅读进度/书签/搜索跳转全部锚定 blockIndex（与滚动模式一致），
/// 分页只是 blockIndex ↔ 页码 的运行时映射——见 [PaginationResult]。

/// 页内切片类型，对应滚动模式 reader_page.dart 的渲染单元：
/// header=书名页眉、title=bt 卷标题、subtitle=bm 品名、text=正文行段、
/// image=插图（独占一页）、nav=上一部/下一部按钮。
enum PageSliceKind { header, title, subtitle, text, image, nav }

/// 一页中的一个渲染切片。
///
/// [text] 是该切片所属文本段的**完整**字符串（已剥弯引号 + 简繁转换）；
/// 同段的多个切片引用同一字符串对象，渲染时 `substring(charStart, charEnd)`
/// ——保证测量与渲染操作的是逐字节相同的文本（风险点 #1 的核心防线）。
class PageSlice {
  PageSlice({
    required this.kind,
    this.blockIndex = -1,
    this.paragraphIndex = -1,
    this.text,
    this.charStart = 0,
    this.charEnd = 0,
    this.imageUrl,
    this.paddingAfter = 0,
  });

  final PageSliceKind kind;

  /// 所属块索引；header/nav 为 -1。
  final int blockIndex;
  final int paragraphIndex;
  final String? text;
  final int charStart;
  final int charEnd;
  final String? imageUrl;

  /// 切片之后的段距；段落收尾恰逢页尾时被丢弃（保持 0）。
  /// 可变：分页器在切片放入后才知道段距是否放得下。
  double paddingAfter;

  String get sliceText => text == null ? '' : text!.substring(charStart, charEnd);
}

class ReaderPageModel {
  const ReaderPageModel({required this.slices, required this.firstBlockIndex});

  final List<PageSlice> slices;

  /// 本页第一个正文块索引（无正文切片的页——如纯页眉/纯 nav——
  /// 取该页起点处的阅读上下文块），用作进度保存锚点。
  final int firstBlockIndex;
}

/// 分页缓存键：任一分量变化都意味着整本书需要重新排版。
/// 主题色不参与（颜色不影响度量，渲染时套用当前前景色即可）。
@immutable
class PaginationKey {
  const PaginationKey({
    required this.bookId,
    required this.contentSize,
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacingEm,
    required this.paragraphSpacing,
    required this.isSimplified,
    required this.textScaleFactor,
  });

  final String bookId;

  /// 内容区尺寸（已减去页边距/上下留白/SafeArea）。
  final Size contentSize;

  /// 生效的字体 family（FontState.activeFamily ?? ''——注意是已加载的，
  /// 不是用户选中的；异步字体注册完成会翻转此值触发重排）。
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final double letterSpacingEm;
  final double paragraphSpacing;
  final bool isSimplified;

  /// 系统文字缩放快照；测量与渲染两侧统一用 TextScaler.linear(此值)。
  final double textScaleFactor;

  @override
  bool operator ==(Object other) =>
      other is PaginationKey &&
      other.bookId == bookId &&
      other.contentSize == contentSize &&
      other.fontFamily == fontFamily &&
      other.fontSize == fontSize &&
      other.lineHeight == lineHeight &&
      other.letterSpacingEm == letterSpacingEm &&
      other.paragraphSpacing == paragraphSpacing &&
      other.isSimplified == isSimplified &&
      other.textScaleFactor == textScaleFactor;

  @override
  int get hashCode => Object.hash(
        bookId,
        contentSize,
        fontFamily,
        fontSize,
        lineHeight,
        letterSpacingEm,
        paragraphSpacing,
        isSimplified,
        textScaleFactor,
      );
}

/// 一次分页运行的（可增长的）产物。pages 只追加、索引永不漂移，
/// PageView 可以边分页边翻。
class PaginationResult {
  PaginationResult({
    required this.key,
    required this.baseStyle,
    required int blockCount,
  }) : _firstPageOfBlock = List<int?>.filled(blockCount, null);

  final PaginationKey key;

  /// 分页时的正文样式快照；页面必须用它渲染（仅允许 copyWith 换 color），
  /// 否则旧结果在设置变更过渡期会溢出。
  final TextStyle baseStyle;

  final List<ReaderPageModel> pages = [];
  final List<int?> _firstPageOfBlock;

  bool done = false;

  /// 已测量完成的块数（排版进度展示用）。
  int blocksMeasured = 0;

  /// 块 → 首次出现的页码；分页尚未推进到该块时返回 null。
  /// 注意返回值可能 == pages.length（块已定位到“正在装填、未 flush”的页）。
  int? pageForBlock(int blockIndex) {
    if (blockIndex <= 0) return pages.isEmpty ? null : 0;
    if (blockIndex >= _firstPageOfBlock.length) {
      return done && pages.isNotEmpty ? pages.length - 1 : null;
    }
    return _firstPageOfBlock[blockIndex];
  }

  void recordBlockPage(int blockIndex, int page) {
    if (blockIndex >= 0 && blockIndex < _firstPageOfBlock.length) {
      _firstPageOfBlock[blockIndex] ??= page;
    }
  }

  int blockForPage(int page) =>
      pages.isEmpty ? 0 : pages[page.clamp(0, pages.length - 1)].firstBlockIndex;
}
