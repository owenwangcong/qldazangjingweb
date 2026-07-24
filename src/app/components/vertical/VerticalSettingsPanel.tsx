'use client';

/**
 * 竖排设置弹层(W12,chrome 底栏齿轮开合;验收 CW10)。
 * 字号/字间/行间 → 进分页键重排;乌丝栏 → 仅重绘;白文 → 重排;
 * 展卷反馈 → 仅监听开关(展卷模式才显示)。
 */
import React from 'react';
import type { VerticalSettings } from './verticalSettings';

export interface VerticalSettingsPanelProps {
  settings: VerticalSettings;
  update: (partial: Partial<VerticalSettings>) => void;
  showFeedbackRow: boolean;
  onClose: () => void;
}

const row: React.CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  gap: 12,
  fontSize: 14,
};

export default function VerticalSettingsPanel({
  settings,
  update,
  showFeedbackRow,
  onClose,
}: VerticalSettingsPanelProps) {
  return (
    <div
      data-vsettings
      style={{
        position: 'absolute',
        right: 16,
        bottom: 96,
        zIndex: 3,
        width: 260,
        display: 'flex',
        flexDirection: 'column',
        gap: 12,
        padding: 16,
        borderRadius: 10,
        background: 'hsl(var(--background) / 0.96)',
        color: 'hsl(var(--foreground))',
        boxShadow: '0 6px 24px rgba(0,0,0,0.18)',
        backdropFilter: 'blur(8px)',
      }}
    >
      <div style={{ ...row, fontWeight: 600 }}>
        <span>竖排设置</span>
        <button
          data-vsettings-close
          onClick={onClose}
          aria-label="关闭设置"
          style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'inherit' }}
        >
          ✕
        </button>
      </div>
      <label style={row}>
        <span>字号 {settings.fontSize}</span>
        <input
          data-set-fontsize
          type="range"
          min={18}
          max={40}
          step={1}
          value={settings.fontSize}
          onChange={(e) => update({ fontSize: Number(e.target.value) })}
        />
      </label>
      <label style={row}>
        <span>字间 {settings.charGapEm.toFixed(2)}</span>
        <input
          data-set-chargap
          type="range"
          min={0}
          max={0.4}
          step={0.05}
          value={settings.charGapEm}
          onChange={(e) => update({ charGapEm: Number(e.target.value) })}
        />
      </label>
      <label style={row}>
        <span>行间 {settings.linePitch.toFixed(2)}</span>
        <input
          data-set-linepitch
          type="range"
          min={1.35}
          max={3}
          step={0.05}
          value={settings.linePitch}
          onChange={(e) => update({ linePitch: Number(e.target.value) })}
        />
      </label>
      <label style={row}>
        <span>版面宽度 {settings.widthPct}%</span>
        <input
          data-set-widthpct
          type="range"
          min={50}
          max={100}
          step={5}
          value={settings.widthPct}
          onChange={(e) => update({ widthPct: Number(e.target.value) })}
        />
      </label>
      <label style={row}>
        <span>乌丝栏</span>
        <input
          data-set-rules
          type="checkbox"
          checked={settings.showRules}
          onChange={(e) => update({ showRules: e.target.checked })}
        />
      </label>
      <label style={row}>
        <span>白文(去句读)</span>
        <input
          data-set-baiwen
          type="checkbox"
          checked={settings.baiwen}
          onChange={(e) => update({ baiwen: e.target.checked })}
        />
      </label>
      {showFeedbackRow && (
        <label style={row}>
          <span>展卷反馈</span>
          <input
            data-set-feedback
            type="checkbox"
            checked={settings.scrollFeedback}
            onChange={(e) => update({ scrollFeedback: e.target.checked })}
          />
        </label>
      )}
    </div>
  );
}
