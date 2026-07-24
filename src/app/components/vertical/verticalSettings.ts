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
  showRules: true,
  baiwen: false,
  scrollFeedback: true,
};

const KEYS: Record<keyof VerticalSettings, string> = {
  fontSize: 'verticalFontSize',
  charGapEm: 'verticalCharGapEm',
  linePitch: 'verticalLinePitch',
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

export function readStoredMode(): StoredReadingMode {
  if (typeof window === 'undefined') return 'horizontal';
  const raw = localStorage.getItem(MODE_KEY);
  return raw === 'verticalPaged' || raw === 'verticalScroll' ? raw : 'horizontal';
}

export function writeStoredMode(mode: StoredReadingMode): void {
  if (typeof window !== 'undefined') localStorage.setItem(MODE_KEY, mode);
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
