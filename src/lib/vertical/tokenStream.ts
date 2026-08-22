/**
 * 竖排字符流构建器(web-vertical-reader-plan.md §5.3,验收 CW2/CW3;
 * 移植自 flutter-app/lib/core/vertical/token_stream.dart +
 * core/pagination/paragraph_text.dart,处理次序两端一致):
 *
 * cleanParagraph 剥双弯引号 → splitParagraphSegments 切 <img> →
 * mapVerticalQuotes 单弯引号→竖排直角引号 → display() 按段简繁转换 →
 * tokenize(带标点)→ 偈颂**区段归并**检测 →(白文时)剥除标点。
 * 次序不可调换:标点归属必须在转换之后,偈颂检测必须在白文剥除之前
 * (剥后无句读可切);引号映射按文本段应用,绝不触碰 <img> 标签属性。
 */
import {
  anyPunctOrSymbol,
  isFloatingPunct,
  whitespace,
} from './punctuation';
import { verseCandidate, type VerseCandidate } from './verseDetector';
import {
  withTrailing,
  type BookData,
  type GridToken,
  type JuanBlockType,
  type TokenParagraph,
} from './models';

const dev = process.env.NODE_ENV !== 'production';

function devAssert(cond: boolean, msg: string): void {
  if (dev && !cond) throw new Error(`vertical assert: ${msg}`);
}

// ---- 段落预处理(paragraph_text.dart 移植) ---------------------------------

/** 剥去双弯引号(与横排渲染器对齐)。在简繁转换**之前**调用。 */
export function cleanParagraph(raw: string): string {
  return raw.replace(/“/g, '').replace(/”/g, '');
}

/**
 * 单弯引号 → 竖排直角引号(台账 font-weight-quotes-plan.md FQ2,竖排管线独占):
 * ‘(U+2018)→﹁(U+FE41)、’(U+2019)→﹂(U+FE42)。
 * ﹁﹂ 不在悬浮表内 → 独立占格直立居中;白文随 \p{P} 剥除。
 * 与 flutter token_stream.dart 的 mapVerticalQuotes 逐位一致(CW14 指纹对拍)。
 */
export function mapVerticalQuotes(text: string): string {
  return text.replace(/‘/g, '﹁').replace(/’/g, '﹂');
}

const srcRegex = /src=["']([^"']+)["']/;

/** 段落切分结果:text 与 imageUrl 二选一。 */
export type ParagraphSegment =
  | { text: string; imageUrl?: undefined }
  | { text?: undefined; imageUrl: string };

/**
 * 把(已剥引号的)段落按 <img> 标签切成文本段与图片段。
 * 无图片时返回单个文本段。src 保留原样(web 同源相对路径可直接渲染,
 * 与 Flutter 端 resolveImageUrl 补全域名的差异仅在渲染层,不影响排版)。
 */
export function splitParagraphSegments(cleaned: string): ParagraphSegment[] {
  if (!cleaned.includes('<img')) {
    return [{ text: cleaned }];
  }
  const segments: ParagraphSegment[] = [];
  const imgRegex = /<img[^>]*>/g; // 局部实例:/g 正则的 lastIndex 有状态,不共享。
  let cursor = 0;
  let match: RegExpExecArray | null;
  while ((match = imgRegex.exec(cleaned)) !== null) {
    const start = match.index;
    if (start > cursor) {
      segments.push({ text: cleaned.slice(cursor, start) });
    }
    const src = srcRegex.exec(match[0])?.[1];
    if (src !== undefined && src.length > 0) {
      segments.push({ imageUrl: src });
    }
    cursor = start + match[0].length;
  }
  if (cursor < cleaned.length) {
    segments.push({ text: cleaned.slice(cursor) });
  }
  return segments;
}

// ---- token 化 ---------------------------------------------------------------

/**
 * 把(已转换的)文本段切成占格 token 序列。
 *
 * 规则:
 * - 按码点迭代——扩展区汉字(如 𠀋)是单 token,绝不按 code unit 断裂;
 * - 空白一律剥除(古籍无空格,全角空格/换行同理);
 * - 句读:悬浮标点附着前一字 trailingPunct(连续标点堆叠、数据全留),
 *   段首前置符无所附则舍弃;非悬浮类标点(如间隔号 ·)独立占格;
 * - 白文 = 带标点形态再剥除(单一真源,见 stripTokensForBaiwen)。
 */
export function tokenizeText(
  text: string,
  opts: { blockIndex: number; paragraphIndex: number; baiwen: boolean },
): GridToken[] {
  const tokens: GridToken[] = [];
  for (const ch of text) {
    if (whitespace.test(ch)) continue;
    if (isFloatingPunct(ch)) {
      if (tokens.length === 0) continue; // 段首前置符:无所附,舍弃。
      const last = tokens[tokens.length - 1];
      tokens[tokens.length - 1] = withTrailing(last, last.trailingPunct + ch);
      continue;
    }
    tokens.push({
      char: ch,
      trailingPunct: '',
      blockIndex: opts.blockIndex,
      paragraphIndex: opts.paragraphIndex,
    });
  }
  // 不变式:占格 token 一律是单码点;悬浮堆只含悬浮类标点。
  devAssert(
    tokens.every((t) => Array.from(t.char).length === 1),
    '占格 token 必须是单码点',
  );
  devAssert(
    tokens.every((t) => Array.from(t.trailingPunct).every(isFloatingPunct)),
    '悬浮堆只能含悬浮类标点',
  );
  return opts.baiwen ? stripTokensForBaiwen(tokens) : tokens;
}

/**
 * 白文剥除:去掉独立占格的标点/符号 token、清空悬浮堆。
 * 只留可占格文字,与直接按白文 tokenize 语义等价(CW2 锁定)。
 */
export function stripTokensForBaiwen(tokens: GridToken[]): GridToken[] {
  const out: GridToken[] = [];
  for (const t of tokens) {
    if (anyPunctOrSymbol.test(t.char)) continue;
    out.push(t.trailingPunct === '' ? t : withTrailing(t, ''));
  }
  return out;
}

// ---- 流构建(三遍:展开 → 区段归并 → 白文产出) -----------------------------

interface RawEntry {
  blockIndex: number;
  paragraphIndex: number;
  blockType: JuanBlockType;
  tokens?: GridToken[];
  imageUrl?: string;
  cand: VerseCandidate | null;
  /** 归并后敲定的偈颂句长(第二遍写入)。 */
  verse?: number;
}

/**
 * BookData → TokenParagraph 流。
 *
 * 区段归并(2026-07-20 漏检修复):藏经数据常把偈颂按「联」编码
 * (两句一段),单段句数不足 4;故先做段级候选(等长 n、句读收束、
 * 句数不限),再把**相邻同 n 的正文段**归并为区段,区段总句数 ≥4
 * 才整体标注——从严门槛保留在区段层,漏检无害化不变。
 */
export function buildTokenStream(opts: {
  book: BookData;
  display: (s: string) => string;
  baiwen: boolean;
}): TokenParagraph[] {
  const { book, display, baiwen } = opts;

  // ---- 第一遍:展开为带标点条目 + 段级偈颂候选 ----------------------------
  const entries: RawEntry[] = [];

  const addText = (b: number, p: number, type: JuanBlockType, raw: string): void => {
    const cleaned = cleanParagraph(raw);
    for (const segment of splitParagraphSegments(cleaned)) {
      if (segment.imageUrl !== undefined) {
        entries.push({
          blockIndex: b,
          paragraphIndex: p,
          blockType: type,
          imageUrl: segment.imageUrl,
          cand: null,
        });
        continue;
      }
      const punctuated = tokenizeText(display(mapVerticalQuotes(segment.text)), {
        blockIndex: b,
        paragraphIndex: p,
        baiwen: false, // 恒带标点——偈颂检测的唯一可靠输入。
      });
      if (punctuated.length === 0) continue;
      entries.push({
        blockIndex: b,
        paragraphIndex: p,
        blockType: type,
        tokens: punctuated,
        // 只对正文段做候选;标题(bt/bm)不是偈颂。
        cand: type === 'p' ? verseCandidate(punctuated) : null,
      });
    }
  };

  for (let b = 0; b < book.blocks.length; b++) {
    const block = book.blocks[b];
    if (block.type === 'bt' || block.type === 'bm') {
      // 标题块合并为单段(镜像横排分页器的标题装填)。
      addText(b, 0, block.type, block.paragraphs.join('').trim());
    } else {
      for (let p = 0; p < block.paragraphs.length; p++) {
        addText(b, p, block.type, block.paragraphs[p]);
      }
    }
  }

  // ---- 第二遍:相邻同 n 候选归并为区段,总句数 ≥4 → 整体标注 ----------------
  let i = 0;
  while (i < entries.length) {
    const cand = entries[i].cand;
    if (cand === null) {
      i++;
      continue;
    }
    let j = i;
    let clauses = 0;
    while (j < entries.length && entries[j].cand?.n === cand.n) {
      clauses += entries[j].cand!.clauses;
      j++;
    }
    if (clauses >= 4) {
      for (let k = i; k < j; k++) {
        entries[k].verse = cand.n;
      }
    }
    i = j;
  }

  // ---- 第三遍:白文剥除 + A6 校验 + 产出 ------------------------------------
  const paragraphs: TokenParagraph[] = [];
  for (const e of entries) {
    if (e.imageUrl !== undefined) {
      paragraphs.push({
        blockIndex: e.blockIndex,
        paragraphIndex: e.paragraphIndex,
        blockType: e.blockType,
        tokens: [],
        imageUrl: e.imageUrl,
      });
      continue;
    }
    const tokens = baiwen ? stripTokensForBaiwen(e.tokens!) : e.tokens!;
    if (tokens.length === 0) continue;
    let verse = e.verse;
    // 白文剥除了独立占格标点后格数可能改变;不再整除句长时撤销
    // 标注(按散文连排,漏检无害化),维持 A6 不变式。
    if (verse !== undefined && tokens.length % verse !== 0) verse = undefined;
    devAssert(verse === undefined || tokens.length % verse === 0, 'A6 偈颂整除不变式');
    paragraphs.push({
      blockIndex: e.blockIndex,
      paragraphIndex: e.paragraphIndex,
      blockType: e.blockType,
      tokens,
      verseClauseLen: verse,
    });
  }
  return paragraphs;
}
