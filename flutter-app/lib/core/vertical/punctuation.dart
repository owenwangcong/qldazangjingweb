/// 竖排排版的标点分类（实施方案 vertical-reader-plan.md §7）。
///
/// 三类处理：
/// 1. 悬浮类（句读/后置括引）→ 附着于前一字的 trailingPunct，绝不占格；
/// 2. 前置类（开括引）→ v1 并入前一字悬浮堆，段首无前字则舍弃；
/// 3. 其余标点/符号（如间隔号 ·）→ 独立占格居中，保持网格完整。
/// 白文模式剥除以上全部（\p{P} + \p{S}），空白在任何模式下都剥除。
library;

/// 后置悬浮标点：句读、顿逗、叹问、后引号/后括号、省略/破折。
/// 含半角形式——需求要求中英文标点统一处理。
const Set<String> trailingFloatingPunctuation = {
  '。', '，', '、', '；', '：', '！', '？',
  '」', '』', '》', '〉', '）', '〕', '】', '〗',
  '…', '—', '‥', '～',
  '.', ',', ';', ':', '!', '?', ')', ']', '}',
};

/// 前置标点（开括引）：v1 并入前一字悬浮堆（藏经语料中极罕，
/// 弯引号已在上游 cleanParagraph 剥除）。
const Set<String> leadingFloatingPunctuation = {
  '「', '『', '《', '〈', '（', '〔', '【', '〖',
  '(', '[', '{',
};

/// 是否悬浮标点（trailing 与 leading 都悬浮渲染，不占格）。
bool isFloatingPunct(String ch) =>
    trailingFloatingPunctuation.contains(ch) ||
    leadingFloatingPunctuation.contains(ch);

/// 句读边界（偈颂切句用，方案 §7）：仅句/逗/分/叹/问。
/// 顿号、冒号不切句——「说偈言：」类引导语混入时靠等长判据自然拒斥。
const Set<String> clauseBoundaryPunctuation = {
  '。', '，', '；', '！', '？',
  ',', ';', '!', '?',
};

/// 全部标点与符号（白文剥除范围）。\p{S} 覆盖 ～/￥ 等符号类；
/// 〇（U+3007，Nl 字母数字）不在其内，不会被误剥。
final RegExp anyPunctOrSymbol = RegExp(r'[\p{P}\p{S}]', unicode: true);

/// 空白（含全角空格 U+3000、换行）：任何模式下都不进入网格。
final RegExp whitespace = RegExp(r'\s', unicode: true);

/// 白文过滤：剥除全部标点、符号与空白，只留可占格文字。
String stripForBaiwen(String text) =>
    text.replaceAll(anyPunctOrSymbol, '').replaceAll(whitespace, '');
