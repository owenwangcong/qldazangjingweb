#version 460 core
// 宣纸纹理 shader —— P0.6 占位版（仅输出 tint，验证 impellerc 编译链路）。
// P1.2 将实现真正的纤维噪声纹理（fbm + 微米点），uniform 接口保持稳定：
//   uSize  画布尺寸（逻辑像素）
//   uTint  纸色（来自 InkTokens.paperTint）
//   uIntensity 纹理强度 0-1（来自 InkTokens.textureIntensity）

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform vec4 uTint;
uniform float uIntensity;

out vec4 fragColor;

void main() {
  fragColor = vec4(uTint.rgb, uTint.a);
}
