'use client';

/**
 * 展卷跨列反馈(W6/W14,§7.5;对齐 Flutter ColumnCrossFeedback):
 * lead 列计数单调前进时触发,40ms 节流(快速惯性滑动不机枪式连响);
 * Android = 振动 + 短嗒,iOS Safari 无振动 API → 仅短嗒(Web Audio 合成,
 * 无资源文件);AudioContext 需用户手势解锁(overlay 首次 pointerdown)。
 */

const THROTTLE_MS = 40;

export class ScrollFeedback {
  private ctx: AudioContext | null = null;
  private lastAt = 0;
  private lastLead = 0;

  /** 用户手势内调用(自动播放策略)。幂等。 */
  unlock(): void {
    if (typeof window === 'undefined') return;
    const AC =
      window.AudioContext ??
      (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!AC) return;
    if (!this.ctx) this.ctx = new AC();
    if (this.ctx.state === 'suspended') void this.ctx.resume();
  }

  /** 不触发地对齐计数(模式切换/反馈关闭/后退时防重入连响)。 */
  rebase(lead: number): void {
    this.lastLead = lead;
  }

  /** 展现新列(lead 单调前进)→ 触觉+听觉各一次;跨图只计 1 次由计数口径保证。 */
  onLead(lead: number): void {
    if (lead <= this.lastLead) {
      this.lastLead = lead; // 后退 rebase,不响
      return;
    }
    this.lastLead = lead;
    const now = performance.now();
    if (now - this.lastAt < THROTTLE_MS) return;
    this.lastAt = now;
    if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
      navigator.vibrate(8);
    }
    this.tick();
  }

  /** 干脆短嗒:方波 1.8kHz,20ms 指数衰减(镜像 Flutter 默认音效口感)。 */
  private tick(): void {
    const ctx = this.ctx;
    if (!ctx || ctx.state !== 'running') return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    const t0 = ctx.currentTime;
    osc.type = 'square';
    osc.frequency.value = 1800;
    gain.gain.setValueAtTime(0.08, t0);
    gain.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.02);
    osc.connect(gain).connect(ctx.destination);
    osc.start(t0);
    osc.stop(t0 + 0.03);
  }

  dispose(): void {
    void this.ctx?.close();
    this.ctx = null;
  }
}
