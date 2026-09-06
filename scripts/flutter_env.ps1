<#
.SYNOPSIS
    Put the Team Mausam Flutter toolchain on PATH for the CURRENT PowerShell session.

.DESCRIPTION
    scripts\setup_flutter_windows.ps1 writes the user environment with setx, which only
    affects terminals started afterwards. Dot-source this file to fix up a shell that is
    already running:

        . .\scripts\flutter_env.ps1

    (The leading dot + space matters - without it the variables are set in a child scope
    and thrown away.)

.PARAMETER SdkRoot
    Toolchain root. Defaults to $env:MAUSAM_SDK_ROOT, then D:\sdk.
#>
param(
    [string] $SdkRoot = $(if ($env:MAUSAM_SDK_ROOT) { $env:MAUSAM_SDK_ROOT } else { 'D:\sdk' })
)

$flutterHome = Join-Path $SdkRoot 'flutter'
$javaHome    = Join-Path $SdkRoot 'jdk-17'
$androidHome = Join-Path $SdkRoot 'android'

$env:FLUTTER_HOME     = $flutterHome
$env:JAVA_HOME        = $javaHome
$env:ANDROID_HOME     = $androidHome
$env:ANDROID_SDK_ROOT = $androidHome

$binDirs = @(
    (Join-Path $flutterHome 'bin'),
    (Join-Path $javaHome 'bin'),
    (Join-Path $androidHome 'platform-tools'),
    (Join-Path $androidHome 'cmdline-tools\latest\bin')
)

$existing = @($env:PATH -split ';' | Where-Object { $_.Trim() -ne '' })
foreach ($dir in $binDirs) {
    $needle = $dir.TrimEnd('\')
    $hit = $existing | Where-Object { $_.TrimEnd('\') -ieq $needle }
    if ($null -eq $hit -or $hit.Count -eq 0) { $env:PATH = "$dir;$env:PATH" }
}

$missing = @($binDirs | Where-Object { -not (Test-Path -LiteralPath $_) })
if ($missing.Count -gt 0) {
    Write-Host "flutter_env: these directories do not exist yet -" -ForegroundColor Yellow
    foreach ($m in $missing) { Write-Host "  $m" -ForegroundColor Yellow }
    Write-Host "Run: powershell -ExecutionPolicy Bypass -File scripts\setup_flutter_windows.ps1" -ForegroundColor Yellow
}
else {
    Write-Host "flutter_env: FLUTTER_HOME=$flutterHome  JAVA_HOME=$javaHome  ANDROID_HOME=$androidHome" -ForegroundColor Green
}
