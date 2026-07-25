/**
 * CW1 网格几何:公式单测(对齐 Flutter C1 口径)。
 */
import { expect, test } from '@playwright/test';
import {
  cellY,
  colX,
  fitGrid,
  gridBottom,
  ruleX,
  ruleXInColumn,
} from '../gridGeometry';

const BASE = { contentW: 640, contentH: 1257, fontSize: 20, linePitch: 1.75, charGapEm: 0 };

test('基准几何:640×1257 / fs20 / lp1.75 / cg0(对拍参数同款)', () => {
  const g = fitGrid(BASE);
  expect(g.cellW).toBe(20);
  expect(g.cellH).toBe(20);
  expect(g.colPitch).toBe(35);
  expect(g.gap).toBe(15);
  expect(g.charsPerCol).toBe(62);
  expect(g.colsPerPage).toBe(18);
  expect(g.gridW).toBe(18 * 35 - 15);
  expect(g.leftInset).toBeCloseTo((640 - 615) / 2, 10);
  expect(g.degraded).toBe(false);
});

test('坐标公式:colX 严格等差、cellY/gridBottom/ruleX', () => {
  const g = fitGrid(BASE);
  expect(colX(g, 0)).toBeCloseTo(12.5 + 615 - 20, 10);
  // 列 x 严格等差(公差 colPitch)——CW6 矩阵对齐的几何前提。
  for (let i = 1; i < g.colsPerPage; i++) {
    expect(colX(g, i - 1) - colX(g, i)).toBeCloseTo(g.colPitch, 10);
  }
  expect(colX(g, g.colsPerPage - 1)).toBeCloseTo(g.leftInset, 10);
  expect(cellY(g, 0)).toBe(0);
  expect(cellY(g, 3)).toBe(60);
  expect(gridBottom(g)).toBe(62 * 20);
  expect(ruleX(g, 1)).toBeCloseTo(colX(g, 1) + 20 + 15 * 0.62, 10);
  expect(ruleXInColumn(g)).toBeCloseTo(20 + 15 * 0.62, 10);
});

test('字间(charGapEm)拉高字面框、行间(linePitch)钳制到 [1.35, 3.0]', () => {
  const gGap = fitGrid({ ...BASE, charGapEm: 0.2 });
  expect(gGap.cellH).toBeCloseTo(24, 10);
  expect(gGap.charsPerCol).toBe(Math.floor(1257 / 24));

  const gLow = fitGrid({ ...BASE, linePitch: 1.0 });
  expect(gLow.colPitch).toBeCloseTo(20 * 1.35, 10);
  const gHigh = fitGrid({ ...BASE, linePitch: 5 });
  expect(gHigh.colPitch).toBeCloseTo(60, 10);
  // 负字间不缩格(max(0, cg))。
  const gNeg = fitGrid({ ...BASE, charGapEm: -0.5 });
  expect(gNeg.cellH).toBe(20);
});

test('A1 兜底:极小内容区钳制字号,charsPerCol/colsPerPage ≥ 1', () => {
  const g = fitGrid({ contentW: 30, contentH: 40, fontSize: 100, linePitch: 1.75, charGapEm: 0 });
  expect(g.degraded).toBe(true);
  expect(g.fontSize).toBe(30); // min(40/1, 30)
  expect(g.charsPerCol).toBeGreaterThanOrEqual(1);
  expect(g.colsPerPage).toBeGreaterThanOrEqual(1);
});

test('NaN 防御:非有限输入替换安全默认,不产 NaN 网格', () => {
  const g = fitGrid({ contentW: NaN, contentH: Infinity, fontSize: NaN, linePitch: NaN, charGapEm: NaN });
  expect(Number.isFinite(g.cellH)).toBe(true);
  expect(Number.isFinite(g.colPitch)).toBe(true);
  expect(g.charsPerCol).toBeGreaterThanOrEqual(1);
  expect(g.colsPerPage).toBeGreaterThanOrEqual(1);
});

test('整除边界:epsilon 保证 floor 不丢格', () => {
  const g = fitGrid({ contentW: 640, contentH: 1200, fontSize: 20, linePitch: 1.75, charGapEm: 0 });
  expect(g.charsPerCol).toBe(60);
});
