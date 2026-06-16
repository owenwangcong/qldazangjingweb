#version 460 core
// 宣纸纹理（docs/ink-design-plan.md §4.1 / P1.2）。
// 三层叠加：横向拉长的纤维噪声（宣纸帘纹方向）+ 低频云絮 + 稀疏纸点。
// 全部基于确定性 hash —— 同尺寸同 uniform 输出逐像素一致，golden 可锁定。
//
// 最大压暗幅度 = 0.12 * uIntensity（test/ink_tokens_test.dart 的对比度
// 最坏情况按此推导，改动幅度须同步改测试）。

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;        // 画布尺寸（逻辑像素）
uniform vec4 uTint;        // 纸色（InkTokens.paperTint）
uniform vec4 uInk;         // 墨色（InkTokens.inkStrong）
uniform float uIntensity;  // 纹理强度 0-1（InkTokens.textureIntensity）

out vec4 fragColor;

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
  vec2 uv = FlutterFragCoord().xy / uSize.y;

  // 纤维：x 向低频、y 向高频 → 横向拉长的丝缕感（两个倍频层）。
  float fiber = vnoise(vec2(uv.x * 90.0, uv.y * 240.0)) * 0.6
              + vnoise(vec2(uv.x * 200.0, uv.y * 520.0)) * 0.4;

  // 云絮：低频明暗起伏（帘纹/云母感）。
  float cloud = vnoise(uv * 8.0);

  // 纸点：~1.5% 像素簇出现的微小杂点。
  float fleck = step(0.985, hash(floor(FlutterFragCoord().xy / 2.0))) * 0.5;

  float n = clamp(fiber * 0.55 + cloud * 0.35 + fleck, 0.0, 1.0);
  vec3 rgb = mix(uTint.rgb, uInk.rgb, n * 0.12 * uIntensity);
  fragColor = vec4(rgb, 1.0);
}
