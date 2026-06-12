# 滚动性能采样（docs/ink-design-plan.md §6.1 唯一口径）：
# 跑 N 轮 flutter drive（profile + integration_test traceAction），归档每轮
# timeline_summary，输出关键指标的中位数。基线（P0.5）与终测（P5.2）同用本脚本。
#
# 注意：dumpsys gfxinfo 对 Flutter 自绘管线无效（Total frames=0，已实测），不要走回头路。
#
# 用法：.\tool\perf.ps1            # 3 轮
#       .\tool\perf.ps1 -Runs 1   # 冒烟
param(
  [int]$Runs = 3,
  [string]$DeviceId = "R52W809056B",
  [string]$Label = "perf"
)

$ErrorActionPreference = "Stop"
$appDir = Split-Path $PSScriptRoot -Parent
$outRoot = Join-Path $appDir "build\perf"

$adb = "D:\Apps\Android\AndroidSDK\platform-tools\adb.exe"
& $adb shell input keyevent KEYCODE_WAKEUP | Out-Null
& $adb shell wm dismiss-keyguard | Out-Null

$keys = @("home_scroll", "reader_scroll")
$collected = @{}
foreach ($k in $keys) { $collected[$k] = @() }

for ($i = 1; $i -le $Runs; $i++) {
  Write-Output ">>> run $i/$Runs"
  Push-Location $appDir
  try {
    # --no-dds 必须：app 内 traceAction 要直连自身 VM Service，DDS 在宿主机上会让
    # 设备侧 localhost 连接被拒（Connection refused，已实测）。
    flutter drive --no-dds --driver=test_driver/perf_driver.dart `
      --target=integration_test/scroll_perf_test.dart --profile -d $DeviceId
    if ($LASTEXITCODE -ne 0) { throw "flutter drive run $i failed (exit $LASTEXITCODE)" }
  } finally { Pop-Location }

  $runDir = Join-Path $outRoot "$Label-run$i"
  New-Item -ItemType Directory -Force $runDir | Out-Null
  foreach ($k in $keys) {
    $src = Join-Path $outRoot "$k.timeline_summary.json"
    Copy-Item $src (Join-Path $runDir "$k.timeline_summary.json") -Force
    $collected[$k] += , (Get-Content $src -Raw -Encoding utf8 | ConvertFrom-Json)
  }
}

function Median($values) {
  $sorted = $values | Sort-Object
  return $sorted[[math]::Floor(($sorted.Count - 1) / 2)]
}

Write-Output ""
Write-Output ("=" * 72)
foreach ($k in $keys) {
  $s = $collected[$k]
  $frames = Median ($s | ForEach-Object { $_.frame_count })
  $jankB = Median ($s | ForEach-Object { [math]::Round(100 * $_.missed_frame_build_budget_count / $_.frame_count, 2) })
  $jankR = Median ($s | ForEach-Object { [math]::Round(100 * $_.missed_frame_rasterizer_budget_count / $_.frame_count, 2) })
  $b90 = Median ($s | ForEach-Object { $_.'90th_percentile_frame_build_time_millis' })
  $b99 = Median ($s | ForEach-Object { $_.'99th_percentile_frame_build_time_millis' })
  $r90 = Median ($s | ForEach-Object { $_.'90th_percentile_frame_rasterizer_time_millis' })
  $r99 = Median ($s | ForEach-Object { $_.'99th_percentile_frame_rasterizer_time_millis' })
  Write-Output "[$k] (median of $Runs runs)"
  Write-Output "  frames=$frames  jank_build=$jankB%  jank_raster=$jankR%"
  Write-Output "  build p90/p99 = $b90 / $b99 ms   raster p90/p99 = $r90 / $r99 ms"
}
Write-Output ("=" * 72)
