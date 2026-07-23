/**
 * 偈颂检测(web-vertical-reader-plan.md §5.3,验收 CW3;
 * 移植自 flutter-app/lib/core/vertical/verse_detector.dart,启发式两端一致)。
 *
 * 在**带标点**的 token 序列上按句读边界切句(白文剥标点后无从切句,
 * 故检测发生在剥除之前)。句长以**占格 token 数**计——悬浮引号不占格
 * 不计数,独立占格的间隔号等则计入,与分页器的列格算术完全同源。
 *
 * 判定从严(漏检无害化:漏检 = 按散文连排,网格仍对齐):
 * - 全部句子等长,句长 n ∈ [4, 7](四/五/六/七言);
 * - 段尾必须以句读收束(有游离残句 = 非偈颂);
 * - 句数门槛(≥4)由 tokenStream 的区段归并层把关。
 */
import { clauseBoundaryPunctuation } from './punctuation';
import type { GridToken } from './models';

export interface VerseCandidate {
  n: number;
  clauses: number;
}

/**
 * 段级偈颂候选:全部句子等长 n ∈ [4,7] 且段尾句读收束 → {n, 句数}。
 * 不设句数门槛——藏经数据常把偈颂按「联」编码(两句一段),单段句数
 * 不足以自证,由相邻段区段归并凑足总句数(≥4)后统一标注。
 */
export function verseCandidate(tokens: GridToken[]): VerseCandidate | null {
  if (tokens.length === 0) return null;
  const lengths: number[] = [];
  let current = 0;
  for (const t of tokens) {
    current++;
    if (endsClause(t.trailingPunct)) {
      lengths.push(current);
      current = 0;
    }
  }
  if (current !== 0) return null;
  if (lengths.length === 0) return null;
  const n = lengths[0];
  if (n < 4 || n > 7) return null;
  if (lengths.some((l) => l !== n)) return null;
  return { n, clauses: lengths.length };
}

/** 单段自足判定(候选 + 句数 ≥4);区段归并场景走 verseCandidate。 */
export function detectVerseClauseLen(tokens: GridToken[]): number | null {
  const c = verseCandidate(tokens);
  return c !== null && c.clauses >= 4 ? c.n : null;
}

/**
 * 悬浮堆中含任一句读边界符即视为句子收束
 * (如「乐。」——句号后跟后引号,仍是句尾)。
 */
export function endsClause(trailingPunct: string): boolean {
  for (const ch of trailingPunct) {
    if (clauseBoundaryPunctuation.has(ch)) return true;
  }
  return false;
}
