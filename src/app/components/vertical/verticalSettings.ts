'use client';

/**
 * 竖排设置与进度持久化(web-vertical-reader-plan.md §9,验收 CW10)。
 * localStorage 逐键存储(FontContext 同款模式);W16:正向命名,无回填陷阱。
 */
import { useCallback, useState } from 'react';

export type StoredReadingMode = 'horizontal' | 'verticalPaged' | 'verticalScroll';

export interface VerticalSettings {
  /** 竖排独立字号 px(W7,默认 26,18~40)。 */
  fontSize: number;
  /** 字间(列内字距 em,0~0.4,默认 0 紧排)。 */
  charGapEm: number;
  /** 行间(列距倍率,1.35~3.0,默认 1.75)。 */
  linePitch: number;
  /** 版面宽度(页窗占视口百分比,50~100,默认 50;W20)。 */
  widthPct: number;
  /** 乌丝栏(默认开;只重绘不重排)。 */
  showRules: boolean;
  /** 白文(默认关;进分页键)。 */
  baiwen: boolean;
  /** 展卷反馈(默认开,W14;仅展卷模式生效)。 */
  scrollFeedback: boolean;
}

export const VERTICAL_DEFAULTS: VerticalSettings = {
  fontSize: 26,
  charGapEm: 0,
  linePitch: 1.75,
  widthPct: 50,
  showRules: true,
  baiwen: false,
  scrollFeedback: true,
};

const KEYS: Record<keyof VerticalSettings, string> = {
  fontSize: 'verticalFontSize',
  charGapEm: 'verticalCharGapEm',
  linePitch: 'verticalLinePitch',
  widthPct: 'verticalWidthPct',
  showRules: 'verticalShowRules',
  baiwen: 'verticalBaiwen',
  scrollFeedback: 'verticalScrollFeedback',
};

const clamp = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi);

function sanitize(s: VerticalSettings): VerticalSettings {
  return {
    fontSize: clamp(Number.isFinite(s.fontSize) ? s.fontSize : 26, 18, 40),
    charGapEm: clamp(Number.isFinite(s.charGapEm) ? s.charGapEm : 0, 0, 0.4),
    linePitch: clamp(Number.isFinite(s.linePitch) ? s.linePitch : 1.75, 1.35, 3.0),
    widthPct: clamp(Number.isFinite(s.widthPct) ? s.widthPct : 50, 50, 100),
    showRules: s.showRules,
    baiwen: s.baiwen,
    scrollFeedback: s.scrollFeedback,
  };
}

export function loadVerticalSettings(): VerticalSettings {
  if (typeof window === 'undefined') return VERTICAL_DEFAULTS;
  const num = (k: string, d: number) => {
    const raw = localStorage.getItem(k);
    return raw === null ? d : Number(raw);
  };
  const bool = (k: string, d: boolean) => {
    const raw = localStorage.getItem(k);
    return raw === null ? d : raw === 'true';
  };
  return sanitize({
    fontSize: num(KEYS.fontSize, VERTICAL_DEFAULTS.fontSize),
    charGapEm: num(KEYS.charGapEm, VERTICAL_DEFAULTS.charGapEm),
    linePitch: num(KEYS.linePitch, VERTICAL_DEFAULTS.linePitch),
    widthPct: num(KEYS.widthPct, VERTICAL_DEFAULTS.widthPct),
    showRules: bool(KEYS.showRules, VERTICAL_DEFAULTS.showRules),
    baiwen: bool(KEYS.baiwen, VERTICAL_DEFAULTS.baiwen),
    scrollFeedback: bool(KEYS.scrollFeedback, VERTICAL_DEFAULTS.scrollFeedback),
  });
}

/** 竖排设置 hook:读取即水合,update 同步写 localStorage。 */
export function useVerticalSettings(): {
  settings: VerticalSettings;
  update: (partial: Partial<VerticalSettings>) => void;
} {
  const [settings, setSettings] = useState<VerticalSettings>(loadVerticalSettings);
  const update = useCallback((partial: Partial<VerticalSettings>) => {
    setSettings((prev) => {
      const next = sanitize({ ...prev, ...partial });
      if (typeof window !== 'undefined') {
        for (const k of Object.keys(partial) as (keyof VerticalSettings)[]) {
          localStorage.setItem(KEYS[k], String(next[k]));
        }
      }
      return next;
    });
  }, []);
  return { settings, update };
}

// ---- 阅读模式与进度(imperative 读写:入口在横排页,避免双 hook 状态漂移) ----

const MODE_KEY = 'readingMode';
const LAST_VERTICAL_KEY = 'verticalLastMode';

export function readStoredMode(): StoredReadingMode {
  if (typeof window === 'undefined') return 'horizontal';
  const raw = localStorage.getItem(MODE_KEY);
  return raw === 'verticalPaged' || raw === 'verticalScroll' ? raw : 'horizontal';
}

/**
 * W19:readingMode 是**当前状态**(刷新书页按它自动恢复竖排);
 * verticalLastMode 记住最后用过的竖排预设(退出写回 horizontal 后,
 * 再进竖排仍还原上次偏好)。
 */
export function writeStoredMode(mode: StoredReadingMode): void {
  if (typeof window === 'undefined') return;
  localStorage.setItem(MODE_KEY, mode);
  if (mode !== 'horizontal') localStorage.setItem(LAST_VERTICAL_KEY, mode);
}

export function readLastVerticalMode(): 'verticalPaged' | 'verticalScroll' {
  if (typeof window === 'undefined') return 'verticalPaged';
  const raw = localStorage.getItem(LAST_VERTICAL_KEY);
  return raw === 'verticalScroll' ? raw : 'verticalPaged';
}

export function readProgress(bookId: string): number | null {
  if (typeof window === 'undefined') return null;
  const raw = localStorage.getItem(`verticalProgress:${bookId}`);
  if (raw === null) return null;
  const v = Number(raw);
  return Number.isFinite(v) && v >= 0 ? Math.floor(v) : null;
}

export function writeProgress(bookId: string, blockIndex: number): void {
  if (typeof window !== 'undefined') {
    localStorage.setItem(`verticalProgress:${bookId}`, String(Math.max(0, Math.floor(blockIndex))));
  }
}
