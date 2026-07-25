/**
 * CW3 偈颂检测:段级候选 + 区段归并 + 白文撤销(对齐 Flutter C3)。
 */
import { expect, test } from '@playwright/test';
import { detectVerseClauseLen, verseCandidate } from '../verseDetector';
import { buildTokenStream, tokenizeText } from '../tokenStream';
import type { BookData } from '../models';

const tk = (text: string) =>
  tokenizeText(text, { blockIndex: 0, paragraphIndex: 0, baiwen: false });

test('五言四句:候选 n=5、clauses=4,单段自足判定命中', () => {
  const tokens = tk('一切有为法,如梦幻泡影,如露亦如电,应作如是观。');
  expect(verseCandidate(tokens)).toEqual({ n: 5, clauses: 4 });
  expect(detectVerseClauseLen(tokens)).toBe(5);
});

test('七言二句(按联编码):候选成立但单段不自足', () => {
  const tokens = tk('吾观地藏威神力,恒河沙劫说难尽,');
  expect(verseCandidate(tokens)).toEqual({ n: 7, clauses: 2 });
  expect(detectVerseClauseLen(tokens)).toBeNull();
});

test('拒斥:句长混杂/游离残句/超范围句长/散文', () => {
  expect(verseCandidate(tk('一切有为法,如梦幻泡影影,如露亦如电,应作如是观。'))).toBeNull();
  expect(verseCandidate(tk('一切有为法,如梦幻泡影,尾部残句'))).toBeNull();
  expect(verseCandidate(tk('观自在,行深般若,照见五蕴,度一切苦。'))).toBeNull(); // 首句 n=3
  expect(verseCandidate(tk('观自在菩萨行深般若波,罗蜜多时照见五蕴皆空,'))).toBeNull(); // n=10
  expect(verseCandidate(tk('如是我闻:一时,佛在忉利天为母说法。'))).toBeNull();
});

test('顿号/冒号不切句;悬浮堆含句读即收束(乐。」)', () => {
  // 顿号不是句读边界:「一、二、三。」只有句号收束 → 单句 n=3 → 拒斥。
  expect(verseCandidate(tk('一、二、三。'))).toBeNull();
  // 末句以「。」收束(句号+后引号堆叠)仍算句尾——收束判定看堆内任一句读。
  const closing = tk('心得安乐,身得安乐,家得安乐,国得安乐。」');
  expect(verseCandidate(closing)).toEqual({ n: 4, clauses: 4 });
  expect(detectVerseClauseLen(closing)).toBe(4);
});

const bookOf = (paragraphs: string[]): BookData => ({
  meta: { id: 't', bu: '', title: '', author: '' },
  blocks: [{ id: 'p0', type: 'p', paragraphs }],
});

test('区段归并:相邻同 n 联句凑足 ≥4 句整体标注', () => {
  const paras = buildTokenStream({
    book: bookOf([
      '吾观地藏威神力,恒河沙劫说难尽,',
      '见闻瞻礼一念间,利益人天无量事,',
      '此是散文段落,不参与归并检测的对照文本。',
    ]),
    display: (s) => s,
    baiwen: false,
  });
  expect(paras[0].verseClauseLen).toBe(7);
  expect(paras[1].verseClauseLen).toBe(7);
  expect(paras[2].verseClauseLen).toBeUndefined();
});

test('区段归并:不同 n 不合并、各自不足 4 句则不标注', () => {
  const paras = buildTokenStream({
    book: bookOf(['一切有为法,如梦幻泡影,', '吾观地藏威神力,恒河沙劫说难尽,']),
    display: (s) => s,
    baiwen: false,
  });
  expect(paras[0].verseClauseLen).toBeUndefined();
  expect(paras[1].verseClauseLen).toBeUndefined();
});

test('bt/bm 不参与偈颂检测', () => {
  const paras = buildTokenStream({
    book: {
      meta: { id: 't', bu: '', title: '', author: '' },
      blocks: [
        { id: 'j1', type: 'bt', paragraphs: ['一切有为法,如梦幻泡影,如露亦如电,应作如是观。'] },
      ],
    },
    display: (s) => s,
    baiwen: false,
  });
  expect(paras[0].verseClauseLen).toBeUndefined();
});

test('白文撤销:剥除独立占格标点后不再整除 → 撤销标注(A6 无害化)', () => {
  // 首句含独立占格的间隔号 ·(计入句长):带标点时四句等长 n=4。
  const src = '甲乙丙·,戊己庚辛,壬癸子丑,寅卯辰巳。';
  const withPunct = buildTokenStream({ book: bookOf([src]), display: (s) => s, baiwen: false });
  expect(withPunct[0].verseClauseLen).toBe(4);
  const baiwen = buildTokenStream({ book: bookOf([src]), display: (s) => s, baiwen: true });
  // · 被剥,15 % 4 ≠ 0 → 撤销,按散文连排。
  expect(baiwen[0].tokens).toHaveLength(15);
  expect(baiwen[0].verseClauseLen).toBeUndefined();
});
