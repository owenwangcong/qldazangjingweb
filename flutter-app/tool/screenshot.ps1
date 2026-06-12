# UI 巡检截图：深链直达指定路由/主题，截屏拉回本机。
# 用法示例：
#   .\tool\screenshot.ps1 -Route /settings -Theme guchayese -Name settings_guchayese
#   .\tool\screenshot.ps1 -Route "/book/0001-01" -Name reader -WaitMs 6000
# 注意：截图必须「设备落盘再 pull」，PowerShell 重定向 exec-out 会损坏 PNG（见 ink-design-plan.md §6.4）。
param(
  [string]$Route = "/",
  [string]$Theme = "",
  [Parameter(Mandatory = $true)][string]$Name,
  [string]$OutDir = "$PSScriptRoot\..\docs\ink-design\screenshots",
  [int]$WaitMs = 2500
)

$ErrorActionPreference = "Stop"
$adb = "D:\Apps\Android\AndroidSDK\platform-tools\adb.exe"

# 熄屏时 screencap 只会得到纯黑 PNG（已实测踩坑）——先唤醒并解锁。
& $adb shell input keyevent KEYCODE_WAKEUP | Out-Null
& $adb shell wm dismiss-keyguard | Out-Null
Start-Sleep -Milliseconds 300

$uri = "qldzj://app$Route"
if ($Theme) {
  $sep = "?"; if ($Route.Contains("?")) { $sep = "&" }
  $uri = "$uri$sep" + "theme=$Theme"
}

# URI 里可能有 & / ?，整条命令交给远端 shell，URI 用单引号保护。
& $adb shell "am start -W -a android.intent.action.VIEW -d '$uri' com.aeonlectron.dazangjing" | Out-Null
Start-Sleep -Milliseconds $WaitMs

New-Item -ItemType Directory -Force $OutDir | Out-Null
$dest = Join-Path $OutDir "$Name.png"
& $adb shell screencap -p /sdcard/_shot.png | Out-Null
& $adb pull /sdcard/_shot.png $dest | Out-Null
& $adb shell rm /sdcard/_shot.png | Out-Null

$size = (Get-Item $dest).Length
if ($size -lt 51200) { Write-Warning "$dest 仅 $size 字节，疑似黑屏/白屏" }
Write-Output $dest
