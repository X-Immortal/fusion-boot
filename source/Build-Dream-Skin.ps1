[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$MediaRoot,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [string]$PreludeFile
)
$ErrorActionPreference='Stop'
$source=$PSScriptRoot
if (-not $PreludeFile) { $PreludeFile = Join-Path $source '..\media\startup.mp4' }
$media=[IO.Path]::GetFullPath($MediaRoot)
$output=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $output){throw 'Build output already exists. Choose a new directory.'}
$framework=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$compiler=Join-Path $framework 'csc.exe'
if(-not (Test-Path -LiteralPath $compiler)){throw '.NET Framework 4.8 compiler is missing.'}
$manifest=Get-Content -LiteralPath (Join-Path $source 'media-manifest.json') -Raw -Encoding UTF8|ConvertFrom-Json
$required=@(
    'output/codex-startup-2k-144fps-crf16.mp4',
    'output/versions/startup-living-v6/startup-intro.mp4',
    'output/versions/startup-living-v6/startup-idle.mp4',
    'output/versions/startup-living-v6/startup-finale.mp4',
    'output/handoff-impact.png',
    'assets/dragon-master-open-cutout-v1.png',
    'assets/dragon-master-closed-cutout-v1.png'
)
foreach($relative in $required){
    $record=@($manifest.files|Where-Object {$_.path -ceq $relative})
    if($record.Count -ne 1){throw "Missing media manifest entry: $relative"}
    $inputFile=Join-Path $media ($relative.Replace('/','\'))
    if(-not (Test-Path -LiteralPath $inputFile -PathType Leaf) -or (Get-Item -LiteralPath $inputFile).Length -ne $record[0].bytes){
        throw "Incomplete original media: $relative"
    }
    $sha=[Security.Cryptography.SHA256]::Create()
    $stream=[IO.File]::OpenRead($inputFile)
    try{$hash=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}
    finally{$stream.Dispose();$sha.Dispose()}
    if($hash -cne $record[0].sha256){throw "Media hash mismatch: $relative"}
}
[IO.Directory]::CreateDirectory($output)|Out-Null
$launcherSources=@('DragonLauncher.cs','ExistingClientStartup.cs','CinematicScene.cs','StrokeTrace.cs','FilmSplash.cs','FilmSplashV2.cs','NativeHandoff.cs','PulseReveal.cs','EyeRig.cs','BridgeActivation.cs','StartupReliability.cs','NativeRestoreGuard.cs','OfficialIdentity.cs','DreamSkinIntegration.cs')
$references=@('mscorlib.dll','System.dll','System.Core.dll','System.Configuration.dll','System.Drawing.dll','System.Management.dll','System.Runtime.Serialization.dll','System.Security.dll','System.Web.Extensions.dll','System.Windows.Forms.dll','System.Xaml.dll','System.Xml.dll','System.Xml.Linq.dll','WPF\PresentationCore.dll','WPF\PresentationFramework.dll','WPF\WindowsBase.dll')
$arguments=@('/nologo','/noconfig','/nostdlib+','/target:winexe','/platform:x64','/optimize+','/codepage:65001','/warn:4','/warnaserror+',('/out:'+(Join-Path $output 'Start-Codex-Fusion.exe')),'/main:DragonLauncher.Program',('/win32manifest:'+(Join-Path $source 'build-inputs\Runtime.manifest')),('/win32icon:'+(Join-Path $source 'build-inputs\Codex.ico')))
$arguments+=@($references|ForEach-Object {'/r:'+(Join-Path $framework $_)})
$arguments+=(Join-Path $source 'build-inputs\RuntimeMetadata.cs')
$arguments+=@($launcherSources|ForEach-Object {Join-Path $source ('src\'+$_)})
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=$compiler
$start.Arguments=(@($arguments|ForEach-Object {'"'+$_+'"'}) -join ' ')
$start.WorkingDirectory=$source
$start.UseShellExecute=$false
$start.CreateNoWindow=$true
$start.RedirectStandardOutput=$true
$start.RedirectStandardError=$true
$process=[Diagnostics.Process]::Start($start)
try {
    $stdout=$process.StandardOutput.ReadToEndAsync()
    $stderr=$process.StandardError.ReadToEndAsync()
    if(-not $process.WaitForExit(60000)){throw 'Compiler timed out.'}
    $messages=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()
    if($process.ExitCode -ne 0){throw "Compilation failed:`n$messages"}
}finally{$process.Dispose()}
[xml]$config = Get-Content -LiteralPath (Join-Path $source 'launcher.config.xml') -Raw -Encoding UTF8
foreach ($element in $config.launcher.ChildNodes) {
    if ($element -is [System.Xml.XmlElement]) {
        $element.InnerText = [Environment]::ExpandEnvironmentVariables($element.InnerText)
    }
}
$config.Save((Join-Path $output 'launcher.config.xml'))
Copy-Item -LiteralPath (Join-Path $source 'build-inputs\Codex.ico') -Destination $output
foreach($document in @('README.md','FIRST-LAUNCHER-LICENSE.txt','FIRST-LAUNCHER-THIRD-PARTY-NOTICES.md')){
    $inputFile=Join-Path (Split-Path -Parent $source) $document
    if(Test-Path -LiteralPath $inputFile -PathType Leaf){Copy-Item -LiteralPath $inputFile -Destination $output}
}
[IO.Directory]::CreateDirectory((Join-Path $output 'media'))|Out-Null
Copy-Item -LiteralPath (Join-Path $source '..\media\MEDIA_NOTICE.md') -Destination (Join-Path $output 'media')
Copy-Item -LiteralPath $PreludeFile -Destination (Join-Path $output 'media\startup.mp4')
Copy-Item -LiteralPath (Join-Path $source 'FONT-LICENSE.txt') -Destination $output
Copy-Item -LiteralPath (Join-Path $source 'SOURCE-PROVENANCE.txt') -Destination $output
Copy-Item -LiteralPath (Join-Path $media 'assets') -Destination $output -Recurse
foreach($relative in $required){
    $destination=Join-Path $output ($relative.Replace('/','\'))
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))|Out-Null
    Copy-Item -LiteralPath (Join-Path $media ($relative.Replace('/','\'))) -Destination $destination
}
Write-Output "Built Dream Skin startup runtime: $output"
