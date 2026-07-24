'use client';

/**
 * 竖排阅读覆盖层(web-vertical-reader-plan.md §7,验收 CW9;WS3)。
 *
 * 一条列带 + 两套吸附预设(§1 核心认识):
 * - 展卷:每列 scroll-snap;翻页:仅页首列 snap(mandatory)+ 断列补白(W2)。
 * - rtl 滚动容器(W4):卷首天然居右、零初始跳转;offset 经 scrollOffset.ts 归一化。
 * - 沉浸态(W13):fixed 全屏、锁 body 滚动;点按显隐 chrome,Esc/✕ 退出。
 * - 点按分区(§7.3):翻页=左 25% 前进/右 25% 后退/中部 chrome;展卷=任意处 chrome。
 */
import React, {
  useCallback,
  useContext,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import { FontContext } from '@/app/context/FontContext';
import { useLanguage } from '@/app/context/LanguageContext';
import { paginateVertical, type VerticalPaginationResult } from '@/lib/vertical/paginator';
import type { BookData } from '@/lib/vertical/models';
import VerticalChrome from './VerticalChrome';
import VerticalColumn from './VerticalColumn';
import VerticalSettingsPanel from './VerticalSettingsPanel';
import { maxOffset, readOffset, setOffset } from './scrollOffset';
import { useVerticalSettings, writeProgress, writeStoredMode } from './verticalSettings';

export type ReadingMode = 'verticalPaged' | 'verticalScroll';

export interface VerticalReaderOverlayProps {
  book: BookData;
  initialMode: ReadingMode;
  initialBlockIndex?: number;
  onExit: (blockIndex: number) => void;
  onModeChange?: (mode: ReadingMode) => void;
}

const BASE_PAD = 16;
const CHROME_AUTOHIDE_MS = 3000;
const REFLOW_DEBOUNCE_MS = 250;

/** 「页面宽度」设置 → 竖排内容宽上限 px(§8.1:超宽桌面屏不出巨页)。 */
const WIDTH_CAP: Record<string, number> = {
  'max-w-xl': 576,
  'max-w-2xl': 672,
  'max-w-3xl': 768,
  'max-w-4xl': 896,
  'max-w-5xl': 1024,
  'max-w-6xl': 1152,
  'max-w-7xl': 1280,
  'max-w-screen-xl': 1280,
  'max-w-full': Number.POSITIVE_INFINITY,
};

export default function VerticalReaderOverlay({
  book,
  initialMode,
  initialBlockIndex = 0,
  onExit,
  onModeChange,
}: VerticalReaderOverlayProps) {
  const { fontFamily, selectedWidth } = useContext(FontContext);
  const { convertText, isSimplified } = useLanguage();
  const { settings, update: updateSettings } = useVerticalSettings();

  const rootRef = useRef<HTMLDivElement>(null);
  const scrollerRef = useRef<HTMLDivElement>(null);

  const [mode, setMode] = useState<ReadingMode>(initialMode);
  const [size, setSize] = useState<{ w: number; h: number } | null>(null);
  const [chromeVisible, setChromeVisible] = useState(true);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [scrollState, setScrollState] = useState({ offset: 0, max: 0 });

  const { fontSize: fs, linePitch, charGapEm, showRules, baiwen } = settings;

  // ---- 尺寸测量与重排管线(§8.1/A7):初测同步;变化→防抖 250ms→重排 --------
  useLayoutEffect(() => {
    const el = rootRef.current;
    if (!el) return;
    let last = { w: el.clientWidth, h: el.clientHeight };
    let timer: ReturnType<typeof setTimeout> | null = null;
    setSize(last);
    const ro = new ResizeObserver(() => {
      const next = { w: el.clientWidth, h: el.clientHeight };
      if (next.w === last.w && next.h === last.h) return;
      last = next;
      if (timer) clearTimeout(timer);
      timer = setTimeout(() => {
        setSize((prev) => (prev && prev.w === last.w && prev.h === last.h ? prev : last));
      }, REFLOW_DEBOUNCE_MS);
    });
    ro.observe(el);
    return () => {
      ro.disconnect();
      if (timer) clearTimeout(timer);
    };
  }, []);

  // ---- 排版(同键缓存,翻页⇄展卷互切零重排) ---------------------------------
  const result: VerticalPaginationResult | null = useMemo(() => {
    if (!size) return null;
    const cap = WIDTH_CAP[selectedWidth] ?? Number.POSITIVE_INFINITY;
    return paginateVertical({
      key: {
        bookId: book.meta.id,
        contentW: Math.max(Math.min(size.w, cap) - 2 * BASE_PAD, 1),
        contentH: Math.max(size.h - 2 * BASE_PAD, 1),
        fontFamily,
        fontSize: fs,
        linePitch,
        charGapEm,
        isSimplified,
        baiwen,
      },
      book,
      display: convertText,
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [book, size, selectedWidth, fontFamily, fs, linePitch, charGapEm, isSimplified, baiwen]);

  const metrics = result ? result.metricsFor(mode === 'verticalPaged' ? 'paged' : 'scroll') : null;

  const pageOffsets = useMemo(
    () => (result ? result.pageStarts.map((i) => result.metricsPaged.offsetOfItem(i)) : []),
    [result],
  );

  const padTotal = result && size ? (size.w - result.grid.gridW) / 2 : BASE_PAD;

  // ---- 锚定与跳转(CW5:blockIndex 是唯一进度锚) ----------------------------
  // 实时进度锚:随滚动更新;result 变化(尺寸/设置重排)后据此还原(A7/W3)。
  // 块 0 首现于 bt 列(题署两列之前无块),块 0 = 卷首,不跳转——
  // 否则展卷模式会滚过书名/作者列(E2E 实证的 136.5 偏移事故)。
  const liveBlockRef = useRef<number>(initialBlockIndex);
  /** 模式互切用条目级锚(比块锚更细,翻页⇄展卷往返零漂移)。 */
  const anchorItemRef = useRef<number | null>(null);
  /** 连续翻页的目标页(滚动动画期间页码状态滞后,以此避免吃步)。 */
  const pendingPageRef = useRef<number | null>(null);

  const currentBlock = useCallback((): number => {
    const el = scrollerRef.current;
    if (!el || !result || !metrics) return 0;
    return result.blockForStripItem(metrics.itemAtOffset(readOffset(el) + 0.5));
  }, [result, metrics]);

  const jumpToBlock = useCallback(
    (b: number, behavior: ScrollBehavior = 'auto') => {
      const el = scrollerRef.current;
      if (!el || !result) return;
      if (mode === 'verticalPaged') {
        setOffset(el, pageOffsets[result.pageForBlock(b)] ?? 0, behavior);
      } else {
        setOffset(el, result.metricsScroll.offsetOfItem(result.stripItemForBlock(b)), behavior);
      }
    },
    [result, mode, pageOffsets],
  );

  useLayoutEffect(() => {
    if (!result) return;
    pendingPageRef.current = null;
    const el = scrollerRef.current;
    if (anchorItemRef.current !== null && el) {
      // 条目级还原(模式互切):翻页取包含该条目的页,展卷取条目边缘。
      const item = anchorItemRef.current;
      anchorItemRef.current = null;
      if (mode === 'verticalPaged') {
        let lo = 0;
        let hi = result.pageStarts.length - 1;
        while (lo < hi) {
          const mid = (lo + hi + 1) >> 1;
          if (result.pageStarts[mid] <= item) lo = mid;
          else hi = mid - 1;
        }
        setOffset(el, pageOffsets[lo] ?? 0);
      } else {
        setOffset(el, result.metricsScroll.offsetOfItem(item));
      }
    } else if (liveBlockRef.current > 0) {
      jumpToBlock(liveBlockRef.current);
    }
    if (el) setScrollState({ offset: readOffset(el), max: maxOffset(el) });
  }, [result, mode, jumpToBlock, pageOffsets]);

  // 回调内读取最新排版(onScroll 的闭包不随每次滚动重建)。
  const resultRef = useRef(result);
  const metricsRef = useRef(metrics);
  resultRef.current = result;
  metricsRef.current = metrics;

  const switchMode = useCallback(
    (m: ReadingMode) => {
      if (m === mode) return;
      const el = scrollerRef.current;
      if (el && metrics) anchorItemRef.current = metrics.itemAtOffset(readOffset(el) + 0.5);
      setMode(m);
      writeStoredMode(m); // §9:记忆上次竖排模式
      onModeChange?.(m);
    },
    [mode, metrics, onModeChange],
  );

  /** 统一退出:落进度 + 交回锚定块(§9 进度交接)。 */
  const exit = useCallback(() => {
    const b = currentBlock();
    writeProgress(book.meta.id, b);
    onExit(b);
  }, [currentBlock, book.meta.id, onExit]);

  // ---- chrome 显隐(W13:自动隐去 + 点按切换) --------------------------------
  const hideTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const showChrome = useCallback((autoHide: boolean) => {
    setChromeVisible(true);
    if (hideTimer.current) clearTimeout(hideTimer.current);
    if (autoHide) hideTimer.current = setTimeout(() => setChromeVisible(false), CHROME_AUTOHIDE_MS);
  }, []);
  useEffect(() => {
    showChrome(true);
    return () => {
      if (hideTimer.current) clearTimeout(hideTimer.current);
    };
  }, [showChrome]);
  const toggleChrome = useCallback(() => {
    setChromeVisible((v) => {
      if (hideTimer.current) clearTimeout(hideTimer.current);
      return !v;
    });
  }, []);

  // ---- 滚动状态(页码/进度) --------------------------------------------------
  const rafRef = useRef(0);
  const settleRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const onScroll = useCallback(() => {
    cancelAnimationFrame(rafRef.current);
    rafRef.current = requestAnimationFrame(() => {
      const el = scrollerRef.current;
      if (!el) return;
      const off = readOffset(el);
      setScrollState({ offset: off, max: maxOffset(el) });
      const r = resultRef.current;
      const m = metricsRef.current;
      if (r && m) liveBlockRef.current = r.blockForStripItem(m.itemAtOffset(off + 0.5));
    });
    // 兜底:滚动停驻在非 pending 目标处(如手动拖走)→ 作废 pending 基准。
    if (settleRef.current) clearTimeout(settleRef.current);
    settleRef.current = setTimeout(() => {
      const el = scrollerRef.current;
      const pending = pendingPageRef.current;
      if (el && pending !== null && Math.abs(readOffset(el) - (pageOffsets[pending] ?? 0)) >= 2) {
        pendingPageRef.current = null;
      }
      // 滚动停驻即落进度(§9,停驻粒度天然节流)。
      writeProgress(bookIdRef.current, liveBlockRef.current);
    }, 250);
  }, [pageOffsets]);

  const bookIdRef = useRef(book.meta.id);
  bookIdRef.current = book.meta.id;

  const currentPage = useMemo(() => {
    if (pageOffsets.length === 0) return 0;
    let lo = 0;
    let hi = pageOffsets.length - 1;
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (pageOffsets[mid] <= scrollState.offset + 1) lo = mid;
      else hi = mid - 1;
    }
    return lo;
  }, [pageOffsets, scrollState.offset]);

  // pending 目标页在页码 state 追平后才作废——rAF 里清除会与 React 提交竞态
  // (连按 PageDown 吃步,E2E 实证)。
  useEffect(() => {
    if (pendingPageRef.current !== null && pendingPageRef.current === currentPage) {
      pendingPageRef.current = null;
    }
  }, [currentPage]);

  const stepPage = useCallback(
    (dir: 1 | -1) => {
      const el = scrollerRef.current;
      if (!el || pageOffsets.length === 0) return;
      // 以未完成的目标页为基准:滚动动画期间连按不吃步(E2E 实证)。
      const base = pendingPageRef.current ?? currentPage;
      const target = Math.min(Math.max(base + dir, 0), pageOffsets.length - 1);
      pendingPageRef.current = target;
      setOffset(el, pageOffsets[target], 'smooth');
    },
    [currentPage, pageOffsets],
  );

  const stepColumn = useCallback(
    (dir: 1 | -1) => {
      const el = scrollerRef.current;
      if (!el || !result) return;
      const m = result.metricsScroll;
      const i = m.itemAtOffset(readOffset(el) + 0.5);
      setOffset(el, m.offsetOfItem(i + dir), 'smooth');
    },
    [result],
  );

  // ---- 点按分区(§7.3) -------------------------------------------------------
  const onTap = useCallback(
    (e: React.MouseEvent) => {
      if ((e.target as HTMLElement).closest('a, button, [data-vnav]')) return;
      if (mode === 'verticalScroll') {
        toggleChrome();
        return;
      }
      const el = scrollerRef.current;
      if (!el) return;
      const rect = el.getBoundingClientRect();
      const ratio = (e.clientX - rect.left) / rect.width;
      if (ratio < 0.25) stepPage(1); // 视觉左 = 前进(D1 镜像)
      else if (ratio > 0.75) stepPage(-1);
      else toggleChrome();
    },
    [mode, stepPage, toggleChrome],
  );

  // ---- 滚轮(§8.2:deltaY→水平前进;翻页整页步进,展卷跟手+落列) -------------
  useEffect(() => {
    const el = scrollerRef.current;
    if (!el || !result) return;
    let settle: ReturnType<typeof setTimeout> | null = null;
    let cooldownUntil = 0;
    const onWheel = (e: WheelEvent) => {
      if (Math.abs(e.deltaY) <= Math.abs(e.deltaX)) return; // 横向交给原生(rtl 方向天然正确)
      e.preventDefault();
      if (mode === 'verticalPaged') {
        const now = performance.now();
        if (now < cooldownUntil) return;
        cooldownUntil = now + 260;
        stepPage(e.deltaY > 0 ? 1 : -1);
        return;
      }
      el.scrollLeft -= e.deltaY; // 向下滚 = 前进 = offset 增大
      if (settle) clearTimeout(settle);
      settle = setTimeout(() => {
        const m = result.metricsScroll;
        const off = readOffset(el);
        const i = m.itemAtOffset(off);
        const a = m.offsetOfItem(i);
        const b = m.offsetOfItem(i + 1);
        setOffset(el, off - a <= b - off ? a : b, 'smooth'); // 就近落列边缘
      }, 140);
    };
    el.addEventListener('wheel', onWheel, { passive: false });
    return () => {
      el.removeEventListener('wheel', onWheel);
      if (settle) clearTimeout(settle);
    };
  }, [result, mode, stepPage]);

  // ---- 键盘(§8.2) -----------------------------------------------------------
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const el = scrollerRef.current;
      if (!el) return;
      switch (e.key) {
        case 'Escape':
          exit();
          break;
        case 'ArrowLeft': // 视觉左 = 前进
          e.preventDefault();
          if (mode === 'verticalPaged') stepPage(1);
          else stepColumn(1);
          break;
        case 'ArrowRight':
          e.preventDefault();
          if (mode === 'verticalPaged') stepPage(-1);
          else stepColumn(-1);
          break;
        case 'PageDown':
          e.preventDefault();
          stepPage(1);
          break;
        case 'PageUp':
          e.preventDefault();
          stepPage(-1);
          break;
        case 'Home':
          e.preventDefault();
          setOffset(el, 0, 'smooth');
          break;
        case 'End':
          e.preventDefault();
          setOffset(el, maxOffset(el), 'smooth');
          break;
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [mode, stepPage, stepColumn, exit]);

  // ---- 沉浸态:锁 body 滚动(W13) -------------------------------------------
  useEffect(() => {
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = prev;
    };
  }, []);

  // ---- 条目渲染 ---------------------------------------------------------------
  const items = useMemo(() => {
    if (!result) return null;
    const paged = mode === 'verticalPaged';
    const pageStartSet = paged ? new Set(result.pageStarts) : null;
    const ruleW = typeof devicePixelRatio === 'number' ? Math.max(0.5, 1 / devicePixelRatio) : 1;
    const nodes: React.ReactNode[] = [];
    let colSeq = 0;
    result.strip.forEach((item, idx) => {
      if (paged) {
        const sp = result.spacers.get(idx);
        if (sp !== undefined) {
          nodes.push(<div key={`sp-${idx}`} style={{ flex: '0 0 auto', width: sp }} />);
        }
      }
      if (item.kind === 'column') {
        const snap = paged ? pageStartSet!.has(idx) : true;
        nodes.push(
          <VerticalColumn
            key={idx}
            column={item.column}
            grid={result.grid}
            showRule={showRules && colSeq > 0}
            ruleWidthPx={ruleW}
            snap={snap}
          />,
        );
        colSeq++;
      } else if (item.kind === 'image') {
        nodes.push(
          <div
            key={idx}
            style={{
              flex: '0 0 auto',
              width: result.grid.contentW,
              height: '100%',
              direction: 'ltr',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              scrollSnapAlign: 'start',
            }}
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={item.imageUrl}
              alt="插图"
              style={{ maxWidth: '100%', maxHeight: '100%', objectFit: 'contain' }}
            />
          </div>,
        );
      } else {
        nodes.push(
          <div
            key={idx}
            data-vnav
            style={{
              flex: '0 0 auto',
              width: result.grid.contentW,
              height: '100%',
              direction: 'ltr',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 16,
              scrollSnapAlign: 'start',
            }}
          >
            {book.meta.nextBuId && (
              <a
                href={`/books/${book.meta.nextBuId}`}
                style={{ color: 'hsl(var(--foreground))', fontSize: 16 }}
              >
                下一部:{convertText(book.meta.nextBuName ?? book.meta.nextBuId)}
              </a>
            )}
            {book.meta.lastBuId && (
              <a
                href={`/books/${book.meta.lastBuId}`}
                style={{ color: 'hsl(var(--muted-foreground))', fontSize: 15 }}
              >
                上一部:{convertText(book.meta.lastBuName ?? book.meta.lastBuId)}
              </a>
            )}
            <button
              onClick={exit}
              style={{
                marginTop: 8,
                padding: '6px 16px',
                fontSize: 14,
                borderRadius: 6,
                border: '1px solid hsl(var(--foreground) / 0.3)',
                background: 'transparent',
                color: 'hsl(var(--foreground))',
                cursor: 'pointer',
              }}
            >
              退出竖排
            </button>
          </div>,
        );
      }
    });
    return nodes;
  }, [result, mode, showRules, book.meta, convertText, exit]);

  const progress = scrollState.max > 0 ? Math.min(scrollState.offset / scrollState.max, 1) : 0;

  return (
    <div
      ref={rootRef}
      data-vreader
      data-mode={mode}
      data-pages={result ? result.pages.length : 0}
      data-page={currentPage}
      data-block={
        result && metrics
          ? result.blockForStripItem(metrics.itemAtOffset(scrollState.offset + 0.5))
          : 0
      }
      data-colpitch={result ? result.grid.colPitch : 0}
      data-colsperpage={result ? result.grid.colsPerPage : 0}
      data-padtotal={padTotal}
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 50,
        background: 'hsl(var(--background))',
        color: 'hsl(var(--foreground))',
        fontFamily,
        overflow: 'hidden',
      }}
    >
      <div
        ref={scrollerRef}
        data-vscroller
        onClick={onTap}
        onScroll={onScroll}
        style={{
          direction: 'rtl',
          height: '100%',
          overflowX: 'auto',
          overflowY: 'hidden',
          scrollSnapType: 'x mandatory',
          scrollPaddingInline: padTotal,
          scrollbarWidth: 'none',
        }}
      >
        {result && (
          <div
            data-vstrip
            style={{
              display: 'flex',
              flexDirection: 'row',
              alignItems: 'center',
              height: '100%',
              width: 'max-content',
              paddingInline: padTotal,
            }}
          >
            {items}
          </div>
        )}
      </div>
      <VerticalChrome
        visible={chromeVisible || settingsOpen}
        title={convertText(book.meta.title)}
        mode={mode}
        page={currentPage}
        pageCount={result ? result.pages.length : 0}
        progress={progress}
        onExit={exit}
        onModeChange={switchMode}
        onToggleSettings={() => {
          setSettingsOpen((open) => {
            if (!open) {
              // 弹层期间挂起自动隐藏,关闭后恢复。
              if (hideTimer.current) clearTimeout(hideTimer.current);
              setChromeVisible(true);
            } else {
              showChrome(true);
            }
            return !open;
          });
        }}
      />
      {settingsOpen && (
        <VerticalSettingsPanel
          settings={settings}
          update={updateSettings}
          showFeedbackRow={mode === 'verticalScroll'}
          onClose={() => {
            setSettingsOpen(false);
            showChrome(true);
          }}
        />
      )}
    </div>
  );
}
