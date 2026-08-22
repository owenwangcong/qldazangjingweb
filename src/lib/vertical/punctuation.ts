/**
 * 竖排排版的标点分类(web-vertical-reader-plan.md §5.3;
 * 从 flutter-app/lib/core/vertical/punctuation.dart 逐表移植,两端必须逐字一致)。
 *
 * 三类处理:
 * 1. 悬浮类(句读/后置括引)→ 附着于前一字的 trailingPunct,绝不占格;
 * 2. 前置类(开括引)→ v1 并入前一字悬浮堆,段首无前字则舍弃;
 * 3. 其余标点/符号(如间隔号 ·)→ 独立占格居中,保持网格完整。
 * 白文模式剥除以上全部(\p{P} + \p{S}),空白在任何模式下都剥除。
 */

/** 后置悬浮标点:句读、顿逗、叹问、后引号/后括号、省略/破折。含半角形式。 */
export const trailingFloatingPunctuation: ReadonlySet<string> = new Set([
  '。', '，', '、', '；', '：', '！', '？',
  '」', '』', '》', '〉', '）', '〕', '】', '〗',
  '…', '—', '‥', '～',
  '.', ',', ';', ':', '!', '?', ')', ']', '}',
]);

/** 前置标点(开括引):v1 并入前一字悬浮堆(藏经语料中极罕;双弯引号上游剥除,
 * 单弯引号已映射为 ﹁﹂ 独立占格,见 tokenStream.mapVerticalQuotes)。 */
export const leadingFloatingPunctuation: ReadonlySet<string> = new Set([
  '「', '『', '《', '〈', '（', '〔', '【', '〖',
  '(', '[', '{',
]);

/** 是否悬浮标点(trailing 与 leading 都悬浮渲染,不占格)。 */
export function isFloatingPunct(ch: string): boolean {
  return trailingFloatingPunctuation.has(ch) || leadingFloatingPunctuation.has(ch);
}

/** 句读边界(偈颂切句用):仅句/逗/分/叹/问。顿号、冒号不切句。 */
export const clauseBoundaryPunctuation: ReadonlySet<string> = new Set([
  '。', '，', '；', '！', '？',
  ',', ';', '!', '?',
]);

/** 全部标点与符号(白文剥除范围)。〇(U+3007,Nl)不在其内,不会被误剥。 */
export const anyPunctOrSymbol = /[\p{P}\p{S}]/u;

/** 空白(含全角空格 U+3000、换行):任何模式下都不进入网格。 */
export const whitespace = /\s/u;

const anyPunctOrSymbolAll = /[\p{P}\p{S}]/gu;
const whitespaceAll = /\s/gu;

/** 白文过滤:剥除全部标点、符号与空白,只留可占格文字。 */
export function stripForBaiwen(text: string): string {
  return text.replace(anyPunctOrSymbolAll, '').replace(whitespaceAll, '');
}
