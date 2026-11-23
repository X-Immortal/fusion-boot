[CmdletBinding()]
param([string]$OutputDirectory)

$ErrorActionPreference = 'Stop'
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $PSScriptRoot 'release-final' }
$target = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
if (Test-Path -LiteralPath $target) {
    throw "Build destination already exists: $target. Choose another -OutputDirectory."
}
$parent = [IO.Path]::GetDirectoryName($target)
[IO.Directory]::CreateDirectory($parent) | Out-Null
$work = Join-Path $parent ('.fusion-build-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($work) | Out-Null

function Get-VerifiedFile($Uri, $Path, $Sha256) {
    & curl.exe --fail --location --silent --show-error --retry 3 --connect-timeout 30 --output $Path $Uri
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Uri" }
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Sha256) {
        throw "Unexpected SHA-256 for $Uri"
    }
}

try {
    $prelude = Join-Path $work 'startup.mp4'
    $archive = Join-Path $work 'community.zip'
    Write-Host 'Downloading the opening film and community R16 assets...'
    Get-VerifiedFile 'https://raw.githubusercontent.com/yushua0808-cpu/dragon-codex-boot/c63a203e5857e85fb3c8a9891eddb570e7a27b54/media/startup.mp4' $prelude 'a322c9947e6486c887cdc0ba913bbe57476b230abf45d85d95d86bce3898cfcd'
    Get-VerifiedFile 'https://github.com/HanwenZhang-George/codex-startup-animation/releases/download/community-v34-r5/CodexDragon-V34-Portable-Windows-x64-r5.zip' $archive '23243e01a53a80c7b73e5a970160d46556b7a0d727fb7991e5693eaa4268c3ff'
    $unpacked = Join-Path $work 'community'
    Expand-Archive -LiteralPath $archive -DestinationPath $unpacked
    $impact = @(Get-ChildItem -LiteralPath $unpacked -Filter 'handoff-impact.png' -File -Recurse)
    if ($impact.Count -ne 1) { throw 'Expected one handoff-impact.png in the community release.' }
    $result = Join-Path $work 'runtime'
    & (Join-Path $PSScriptRoot 'source\Build-Dream-Skin.ps1') -MediaRoot $impact[0].Directory.Parent.FullName -PreludeFile $prelude -OutputDirectory $result
    [IO.Directory]::Move($result, $target)
    Write-Host "Launcher ready: $target\Start-Codex-Fusion.exe"
} finally {
    $resolvedWork = (Resolve-Path -LiteralPath $work).ProviderPath
    if ([IO.Path]::GetDirectoryName($resolvedWork) -eq $parent -and [IO.Path]::GetFileName($resolvedWork) -match '^\.fusion-build-[0-9a-f]{32}$') {
        Remove-Item -LiteralPath $resolvedWork -Recurse -Force
    }
}
