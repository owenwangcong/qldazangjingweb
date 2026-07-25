/**
 * CW2 字符流:码点切分/标点归属/白文/图片切分/简繁前置(对齐 Flutter C2)。
 */
import { expect, test } from '@playwright/test';
import { anyPunctOrSymbol, stripForBaiwen } from '../punctuation';
import {
  buildTokenStream,
  cleanParagraph,
  splitParagraphSegments,
  stripTokensForBaiwen,
  tokenizeText,
} from '../tokenStream';
import type { BookData } from '../models';

const tk = (text: string, baiwen = false) =>
  tokenizeText(text, { blockIndex: 0, paragraphIndex: 0, baiwen });

const chars = (tokens: { char: string }[]) => tokens.map((t) => t.char).join('');

test('悬浮标点附着前一字,连续标点堆叠', () => {
  const tokens = tk('如是我闻。');
  expect(tokens).toHaveLength(4);
  expect(tokens[3].trailingPunct).toBe('。');

  const stacked = tk('得安乐。」');
  expect(stacked).toHaveLength(3);
  expect(stacked[2].trailingPunct).toBe('。」');
});

test('段首前置符舍弃;段中前置符并入前一字堆(v1)', () => {
  const t1 = tk('「如是我闻');
  expect(chars(t1)).toBe('如是我闻');
  expect(t1[0].trailingPunct).toBe('');

  const t2 = tk('佛言(善哉');
  expect(chars(t2)).toBe('佛言善哉');
  expect(t2[1].trailingPunct).toBe('(');
});

test('代理对安全:扩展区汉字是单 token', () => {
  const tokens = tk('𠀋佛𪛖');
  expect(tokens).toHaveLength(3);
  expect(tokens[0].char).toBe('𠀋');
  expect(tokens[2].char).toBe('𪛖');
});

test('空白全剥除(半角/全角/换行);间隔号独立占格', () => {
  expect(chars(tk(' 如　是\n我 闻 '))).toBe('如是我闻');
  const dot = tk('文殊师利·普贤');
  expect(chars(dot)).toBe('文殊师利·普贤');
  expect(dot[4].char).toBe('·');
});

test('白文:两条路径语义等价、零标点残留', () => {
  const src = '尔时,世尊。而说偈言:「一切有为法·如梦幻泡影。」';
  const direct = tk(src, true);
  const derived = stripTokensForBaiwen(tk(src, false));
  expect(chars(direct)).toBe(chars(derived));
  expect(direct.every((t) => t.trailingPunct === '')).toBe(true);
  expect(direct.every((t) => !anyPunctOrSymbol.test(t.char))).toBe(true);

  const stripped = stripForBaiwen(src);
  expect([...stripped].every((ch) => !anyPunctOrSymbol.test(ch))).toBe(true);
});

test('cleanParagraph 剥弯引号;splitParagraphSegments 切 <img>', () => {
  expect(cleanParagraph('曰“如是”云')).toBe('曰如是云');

  const segs = splitParagraphSegments('前文<img src="/images/x.png">后文');
  expect(segs).toHaveLength(3);
  expect(segs[0].text).toBe('前文');
  expect(segs[1].imageUrl).toBe('/images/x.png');
  expect(segs[2].text).toBe('后文');

  expect(splitParagraphSegments('无图段落')).toEqual([{ text: '无图段落' }]);
  const only = splitParagraphSegments("<img src='/y.jpg'>");
  expect(only).toEqual([{ imageUrl: '/y.jpg' }]);
});

const miniBook = (): BookData => ({
  meta: { id: 't', bu: '', title: '测试经', author: '某某译' },
  blocks: [
    { id: 'j1', type: 'bt', paragraphs: ['\n  测试经卷上 \n', ''] },
    { id: 'p0', type: 'p', paragraphs: ['如是我闻。', '', '一时佛在<img src="/z.png">舍卫国。'] },
    { id: 'j2', type: 'bm', paragraphs: ['序品第一'] },
  ],
});

test('buildTokenStream:bt 合并单段、空段跳过、img 切分、索引保留', () => {
  const paras = buildTokenStream({ book: miniBook(), display: (s) => s, baiwen: false });
  // bt(1) + p段0(1) + p段2 被 img 切成 文/图/文(3) + bm(1) = 6
  expect(paras).toHaveLength(6);
  expect(paras[0].blockType).toBe('bt');
  expect(chars(paras[0].tokens)).toBe('测试经卷上');
  expect(paras[1].blockIndex).toBe(1);
  expect(paras[1].paragraphIndex).toBe(0);
  expect(paras[2].paragraphIndex).toBe(2);
  expect(paras[3].imageUrl).toBe('/z.png');
  expect(paras[3].blockIndex).toBe(1);
  expect(chars(paras[4].tokens)).toBe('舍卫国');
  expect(paras[5].blockType).toBe('bm');
});

test('简繁转换在标点归属之前(display 按段应用)', () => {
  const display = (s: string) => s.replaceAll('云', '雲');
  const paras = buildTokenStream({
    book: {
      meta: { id: 't', bu: '', title: '', author: '' },
      blocks: [{ id: 'p0', type: 'p', paragraphs: ['白云。'] }],
    },
    display,
    baiwen: false,
  });
  expect(paras).toHaveLength(1);
  expect(chars(paras[0].tokens)).toBe('白雲');
  expect(paras[0].tokens[1].trailingPunct).toBe('。');
});

test('白文改变字符流:独立占格标点被剥、流变短', () => {
  const book: BookData = {
    meta: { id: 't', bu: '', title: '', author: '' },
    blocks: [{ id: 'p0', type: 'p', paragraphs: ['文殊·普贤。'] }],
  };
  const punctuated = buildTokenStream({ book, display: (s) => s, baiwen: false });
  const baiwen = buildTokenStream({ book, display: (s) => s, baiwen: true });
  expect(chars(punctuated[0].tokens)).toBe('文殊·普贤');
  expect(chars(baiwen[0].tokens)).toBe('文殊普贤');
});
