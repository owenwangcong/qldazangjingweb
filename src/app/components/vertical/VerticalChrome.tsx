'use client';

/**
 * 竖排 chrome(W13 沉浸态的顶/底栏):点按中部显隐,自动隐去。
 * 纯展示组件;设置弹层在 WS5 挂到底栏齿轮位。
 */
import React from 'react';
import type { ReadingMode } from './VerticalReaderOverlay';

export interface VerticalChromeProps {
  visible: boolean;
  title: string;
  mode: ReadingMode;
  /** 翻页预设显示页码(DS2:展卷不显示)。 */
  page: number;
  pageCount: number;
  /** 卷轴进度 0~1。 */
  progress: number;
  onExit: () => void;
  onModeChange: (mode: ReadingMode) => void;
}

const barBase: React.CSSProperties = {
  position: 'absolute',
  left: 0,
  right: 0,
  zIndex: 2,
  display: 'flex',
  alignItems: 'center',
  gap: 12,
  padding: '10px 16px',
  background: 'hsl(var(--background) / 0.92)',
  backdropFilter: 'blur(6px)',
  transition: 'opacity 200ms ease, transform 200ms ease',
};

const modeBtn = (active: boolean): React.CSSProperties => ({
  padding: '4px 10px',
  fontSize: 13,
  borderRadius: 6,
  border: '1px solid hsl(var(--border, 0 0% 80%))',
  background: active ? 'hsl(var(--foreground))' : 'transparent',
  color: active ? 'hsl(var(--background))' : 'hsl(var(--foreground))',
  cursor: 'pointer',
});

export default function VerticalChrome({
  visible,
  title,
  mode,
  page,
  pageCount,
  progress,
  onExit,
  onModeChange,
}: VerticalChromeProps) {
  const hidden: React.CSSProperties = visible
    ? {}
    : { opacity: 0, pointerEvents: 'none' };

  return (
    <div data-vchrome={visible ? 'visible' : 'hidden'}>
      <div
        style={{
          ...barBase,
          ...hidden,
          top: 0,
          transform: visible ? 'none' : 'translateY(-8px)',
        }}
      >
        <button
          data-vexit
          aria-label="退出竖排"
          onClick={onExit}
          style={{ ...modeBtn(false), fontSize: 16, lineHeight: 1 }}
        >
          ✕
        </button>
        <span
          style={{
            flex: 1,
            textAlign: 'center',
            fontSize: 15,
            color: 'hsl(var(--foreground))',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
        >
          {title}
        </span>
        <span style={{ width: 34 }} />
      </div>

      <div
        style={{
          ...barBase,
          ...hidden,
          bottom: 0,
          flexDirection: 'column',
          gap: 8,
          transform: visible ? 'none' : 'translateY(8px)',
        }}
      >
        <div
          aria-hidden="true"
          style={{
            width: '100%',
            height: 3,
            borderRadius: 2,
            background: 'hsl(var(--foreground) / 0.12)',
          }}
        >
          <div
            data-vprogress
            style={{
              width: `${Math.round(progress * 1000) / 10}%`,
              height: '100%',
              borderRadius: 2,
              background: 'hsl(var(--foreground) / 0.55)',
            }}
          />
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <button data-mode-exit style={modeBtn(false)} onClick={onExit}>
            横排
          </button>
          <button
            data-mode-paged
            style={modeBtn(mode === 'verticalPaged')}
            onClick={() => onModeChange('verticalPaged')}
          >
            竖排翻页
          </button>
          <button
            data-mode-scroll
            style={modeBtn(mode === 'verticalScroll')}
            onClick={() => onModeChange('verticalScroll')}
          >
            竖排展卷
          </button>
          {mode === 'verticalPaged' && pageCount > 0 && (
            <span
              data-vpage
              style={{ fontSize: 13, color: 'hsl(var(--muted-foreground))', marginLeft: 8 }}
            >
              {page + 1} / {pageCount}
            </span>
          )}
        </div>
      </div>
    </div>
  );
}
