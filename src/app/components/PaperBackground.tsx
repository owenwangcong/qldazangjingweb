'use client';

import React, { useEffect, useLayoutEffect, useRef } from 'react';
import { useTheme, Theme } from '../context/ThemeContext';

/**
 * 宣纸纹理背景（与 flutter-app/shaders/paper.frag 对标）。
 *
 * 把 Flutter 的片元着色器 1:1 移植到一张铺满视口的 WebGL canvas 上：
 * 三层叠加 —— 横向拉长的纤维噪声（宣纸帘纹）+ 低频云絮 + 稀疏纸点，
 * 最大压暗幅度 = 0.12 * intensity，纸色/墨色/强度全部取自当前主题的 InkTokens。
 *
 * 因为是程序化整屏绘制（非贴图平铺），不存在任何拼接缝。
 * 静态绘制：仅在主题切换、视口尺寸变化时重画，滚动时画面固定（fixed）。
 */

type InkToken = {
  /** 宣纸底色（HSL，与 flutter-app InkTokens.paperTint 同源） */
  tint: [number, number, number];
  /** 焦浓墨（HSL，InkTokens.inkStrong） */
  ink: [number, number, number];
  /** 纹理强度 0–1（InkTokens.textureIntensity） */
  intensity: number;
};

// 色值与墨阶与 flutter-app/lib/core/ink/tokens/ink_tokens.dart 逐一对齐。
const INK_TOKENS: Record<Theme, InkToken> = {
  lianchichanyun: { tint: [85, 14, 96], ink: [85, 14, 20], intensity: 0.42 },
  zhulinyoujing: { tint: [140, 18, 96], ink: [140, 18, 19], intensity: 0.42 },
  yueyingqinghui: { tint: [220, 8, 96], ink: [220, 8, 18], intensity: 0.45 },
  hupochangguang: { tint: [36, 32, 96], ink: [30, 45, 18], intensity: 0.48 },
  guchayese: { tint: [220, 19, 16], ink: [220, 18, 88], intensity: 0.28 },
  fagufanyin: { tint: [20, 24, 16], ink: [24, 22, 88], intensity: 0.28 },
};

/** HSL（h:0-360, s/l:0-100）→ 线性顺序的 RGB（0–1）。 */
function hslToRgb(h: number, s: number, l: number): [number, number, number] {
  const sN = s / 100;
  const lN = l / 100;
  const c = (1 - Math.abs(2 * lN - 1)) * sN;
  const hp = h / 60;
  const x = c * (1 - Math.abs((hp % 2) - 1));
  let r = 0;
  let g = 0;
  let b = 0;
  if (hp >= 0 && hp < 1) [r, g, b] = [c, x, 0];
  else if (hp < 2) [r, g, b] = [x, c, 0];
  else if (hp < 3) [r, g, b] = [0, c, x];
  else if (hp < 4) [r, g, b] = [0, x, c];
  else if (hp < 5) [r, g, b] = [x, 0, c];
  else [r, g, b] = [c, 0, x];
  const m = lN - c / 2;
  return [r + m, g + m, b + m];
}

function rgbToCss([r, g, b]: [number, number, number]): string {
  const to255 = (v: number) => Math.round(v * 255);
  return `rgb(${to255(r)}, ${to255(g)}, ${to255(b)})`;
}

const VERT_SRC = `
attribute vec2 aPos;
void main() {
  gl_Position = vec4(aPos, 0.0, 1.0);
}`;

// paper.frag 的 WebGL1 移植；逻辑与桌面版逐行一致。
const FRAG_SRC = `
precision highp float;

uniform vec2 uSize;       // 绘制缓冲尺寸（物理像素）
uniform vec3 uTint;       // 纸色
uniform vec3 uInk;        // 墨色
uniform float uIntensity; // 纹理强度 0-1
uniform float uDpr;       // devicePixelRatio（保持纸点的 CSS 尺寸恒定）

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void main() {
  // 以高度归一化，保证不同宽高比下纹理密度一致。
  vec2 uv = gl_FragCoord.xy / uSize.y;

  // 纤维：x 向低频、y 向高频 → 横向拉长的丝缕感（两个倍频层）。
  float fiber = vnoise(vec2(uv.x * 90.0, uv.y * 240.0)) * 0.6
              + vnoise(vec2(uv.x * 200.0, uv.y * 520.0)) * 0.4;

  // 云絮：低频明暗起伏（帘纹/云母感）。
  float cloud = vnoise(uv * 8.0);

  // 纸点：~1.5% 像素簇出现的微小杂点（除以 dpr 保持 CSS 尺寸恒定）。
  float fleck = step(0.985, hash(floor(gl_FragCoord.xy / (2.0 * uDpr)))) * 0.5;

  float n = clamp(fiber * 0.55 + cloud * 0.35 + fleck, 0.0, 1.0);
  vec3 rgb = mix(uTint, uInk, n * 0.12 * uIntensity);
  gl_FragColor = vec4(rgb, 1.0);
}`;

function compile(gl: WebGLRenderingContext, type: number, src: string): WebGLShader | null {
  const shader = gl.createShader(type);
  if (!shader) return null;
  gl.shaderSource(shader, src);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    console.warn('PaperBackground shader compile failed:', gl.getShaderInfoLog(shader));
    gl.deleteShader(shader);
    return null;
  }
  return shader;
}

interface GLState {
  gl: WebGLRenderingContext;
  program: WebGLProgram;
  uSize: WebGLUniformLocation | null;
  uTint: WebGLUniformLocation | null;
  uInk: WebGLUniformLocation | null;
  uIntensity: WebGLUniformLocation | null;
  uDpr: WebGLUniformLocation | null;
}

const PaperBackground: React.FC = () => {
  const { theme } = useTheme();
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const stateRef = useRef<GLState | null>(null);
  const drawRef = useRef<(() => void) | null>(null);
  const themeRef = useRef<Theme>(theme);
  themeRef.current = theme;

  // 同步兜底色：WebGL 尚未绘制 / 不可用时，整屏即纯纸色，避免白闪。
  useLayoutEffect(() => {
    const token = INK_TOKENS[theme] ?? INK_TOKENS.hupochangguang;
    const css = rgbToCss(hslToRgb(token.tint[0], token.tint[1], token.tint[2]));
    if (canvasRef.current) canvasRef.current.style.backgroundColor = css;
    document.documentElement.style.backgroundColor = css;
  }, [theme]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const gl =
      (canvas.getContext('webgl', { antialias: false, alpha: false, depth: false }) as
        | WebGLRenderingContext
        | null) ||
      (canvas.getContext('experimental-webgl') as WebGLRenderingContext | null);
    if (!gl) return; // WebGL 不可用 → 保留 CSS 兜底纯纸色。

    const vert = compile(gl, gl.VERTEX_SHADER, VERT_SRC);
    const frag = compile(gl, gl.FRAGMENT_SHADER, FRAG_SRC);
    if (!vert || !frag) return;

    const program = gl.createProgram();
    if (!program) return;
    gl.attachShader(program, vert);
    gl.attachShader(program, frag);
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      console.warn('PaperBackground program link failed:', gl.getProgramInfoLog(program));
      return;
    }
    gl.useProgram(program);

    // 全屏三角形（覆盖整个裁剪空间）。
    const buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
    const aPos = gl.getAttribLocation(program, 'aPos');
    gl.enableVertexAttribArray(aPos);
    gl.vertexAttribPointer(aPos, 2, gl.FLOAT, false, 0, 0);

    const state: GLState = {
      gl,
      program,
      uSize: gl.getUniformLocation(program, 'uSize'),
      uTint: gl.getUniformLocation(program, 'uTint'),
      uInk: gl.getUniformLocation(program, 'uInk'),
      uIntensity: gl.getUniformLocation(program, 'uIntensity'),
      uDpr: gl.getUniformLocation(program, 'uDpr'),
    };
    stateRef.current = state;

    const draw = () => {
      const s = stateRef.current;
      if (!s) return;
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const w = Math.max(1, Math.floor(window.innerWidth * dpr));
      const h = Math.max(1, Math.floor(window.innerHeight * dpr));
      if (canvas.width !== w || canvas.height !== h) {
        canvas.width = w;
        canvas.height = h;
      }
      const token = INK_TOKENS[themeRef.current] ?? INK_TOKENS.hupochangguang;
      const tint = hslToRgb(token.tint[0], token.tint[1], token.tint[2]);
      const ink = hslToRgb(token.ink[0], token.ink[1], token.ink[2]);
      s.gl.viewport(0, 0, w, h);
      s.gl.useProgram(s.program);
      s.gl.uniform2f(s.uSize, w, h);
      s.gl.uniform3f(s.uTint, tint[0], tint[1], tint[2]);
      s.gl.uniform3f(s.uInk, ink[0], ink[1], ink[2]);
      s.gl.uniform1f(s.uIntensity, token.intensity);
      s.gl.uniform1f(s.uDpr, dpr);
      s.gl.drawArrays(s.gl.TRIANGLES, 0, 3);
    };

    drawRef.current = draw;
    draw();

    // 视口尺寸变化时重画（debounce 到下一帧，避免连续 resize 抖动）。
    let raf = 0;
    const onResize = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(draw);
    };
    window.addEventListener('resize', onResize);

    // WebGL 上下文丢失/恢复处理。
    const onLost = (e: Event) => e.preventDefault();
    const onRestored = () => draw();
    canvas.addEventListener('webglcontextlost', onLost, false);
    canvas.addEventListener('webglcontextrestored', onRestored, false);

    return () => {
      window.removeEventListener('resize', onResize);
      canvas.removeEventListener('webglcontextlost', onLost);
      canvas.removeEventListener('webglcontextrestored', onRestored);
      cancelAnimationFrame(raf);
      gl.deleteBuffer(buffer);
      gl.deleteProgram(program);
      gl.deleteShader(vert);
      gl.deleteShader(frag);
      stateRef.current = null;
      drawRef.current = null;
    };
  }, []);

  // 主题切换 → 重画（颜色/强度变化）。
  useEffect(() => {
    drawRef.current?.();
  }, [theme]);

  return (
    <canvas
      ref={canvasRef}
      aria-hidden="true"
      style={{
        position: 'fixed',
        inset: 0,
        width: '100%',
        height: '100%',
        zIndex: -1,
        pointerEvents: 'none',
        display: 'block',
      }}
    />
  );
};

export default PaperBackground;
