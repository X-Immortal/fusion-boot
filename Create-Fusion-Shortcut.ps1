[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$runtime=Join-Path $PSScriptRoot 'release-final'
$program=Join-Path $runtime 'Start-Codex-Fusion.exe'
if(-not (Test-Path -LiteralPath $program -PathType Leaf)){throw '找不到融合版启动程序。'}
$icon=Join-Path $runtime 'Codex.ico'
if(-not (Test-Path -LiteralPath $icon -PathType Leaf)){throw '找不到融合版快捷方式图标。'}
$desktop=[Environment]::GetFolderPath('DesktopDirectory')
$shortcutPath=Join-Path $desktop 'GPT 龙娘融合 · Dream Skin Codex.lnk'
if(Test-Path -LiteralPath $shortcutPath){throw "融合版快捷方式已存在：$shortcutPath"}
$shell=New-Object -ComObject WScript.Shell
$shortcut=$shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath=$program
$shortcut.WorkingDirectory=$runtime
$shortcut.Description='第一套完整视频、第二套三段动画与 Dream Skin Codex'
$shortcut.IconLocation=$icon+',0'
$shortcut.Save()
Write-Output $shortcutPath
