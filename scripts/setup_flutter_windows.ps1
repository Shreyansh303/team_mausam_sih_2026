<#
.SYNOPSIS
    Team Mausam (SIH 2026) - idempotent, user-space Flutter toolchain installer for Windows.

.DESCRIPTION
    Installs, WITHOUT admin rights and WITHOUT UAC prompts, everything needed to run
    `flutter build web` and `flutter build apk --debug`:

        <SdkRoot>\flutter                          Flutter SDK (current stable)
        <SdkRoot>\jdk-17                           Eclipse Temurin JDK 17 (HotSpot, zip)
        <SdkRoot>\android                          Android SDK (ANDROID_HOME)
        <SdkRoot>\android\cmdline-tools\latest     Android command-line tools
        <SdkRoot>\_downloads                       cached installer zips (safe to delete)

    Then it sets the user environment variables FLUTTER_HOME / JAVA_HOME / ANDROID_HOME /
    ANDROID_SDK_ROOT, appends the four bin directories to the *user* PATH (only if missing),
    accepts the Android SDK licenses non-interactively and prints `flutter doctor -v`.

    Every step is skipped when its output already exists, so the script is safe to re-run.
    Use -Force to re-download and re-extract everything.

.NOTES
    * PowerShell 5.1 compatible: no `&&`, no `||`, no ternary, no `??`.
    * `setx` (and any env change) does NOT affect the shell that is already running.
      Open a NEW terminal afterwards, or dot-source scripts\flutter_env.ps1.
    * Downloads are ~2.3 GB in total (Flutter 1.9 GB + JDK 190 MB + cmdline-tools 155 MB)
      plus ~600 MB of Android SDK packages. Budget 20-60 min on a first run.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\setup_flutter_windows.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\setup_flutter_windows.ps1 -SdkRoot E:\sdk -Force
#>
[CmdletBinding()]
param(
    # Root of every user-space toolchain. Must be on a drive with >= 15 GB free.
    [string] $SdkRoot = 'D:\sdk',

    # Android platform / build-tools requested from sdkmanager (see docs/06_MOBILE_SPEC.md).
    [string[]] $AndroidPlatforms  = @('android-36', 'android-35'),
    [string[]] $AndroidBuildTools = @('36.0.0', '35.0.0'),

    # Android command-line tools build. Current build is listed on
    # https://developer.android.com/studio#command-line-tools-only
    [string] $CmdlineToolsBuild = '15859902',

    # Flutter release channel to read out of releases_windows.json.
    [string] $FlutterChannel = 'stable',

    # Re-download + re-extract even when the target directory already exists.
    [switch] $Force,

    # Skip the (slow) `flutter doctor -v` at the end.
    [switch] $SkipDoctor
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# --------------------------------------------------------------------------------------
# tiny logging helpers
# --------------------------------------------------------------------------------------
$script:StepNo = 0
function Write-Step {
    param([string] $Message)
    $script:StepNo = $script:StepNo + 1
    Write-Host ''
    Write-Host ("=== [{0}] {1} " -f $script:StepNo, $Message).PadRight(86, '=') -ForegroundColor Cyan
}
function Write-Info { param([string] $Message) Write-Host "    $Message" -ForegroundColor Gray }
function Write-Ok   { param([string] $Message) Write-Host "    OK   $Message" -ForegroundColor Green }
function Write-Skip { param([string] $Message) Write-Host "    SKIP $Message" -ForegroundColor DarkGray }
function Write-Note { param([string] $Message) Write-Host "    NOTE $Message" -ForegroundColor Yellow }

function New-Dir {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

# --------------------------------------------------------------------------------------
# download / extract helpers (curl.exe + tar.exe are shipped with Windows 10/11)
# --------------------------------------------------------------------------------------
function Get-RemoteFile {
    param(
        [Parameter(Mandatory = $true)] [string] $Url,
        [Parameter(Mandatory = $true)] [string] $Destination,
        [int] $MinimumBytes = 1048576
    )

    if (Test-Path -LiteralPath $Destination) {
        $existing = (Get-Item -LiteralPath $Destination).Length
        if ($existing -ge $MinimumBytes) {
            Write-Skip ("cached download {0} ({1} MB)" -f (Split-Path $Destination -Leaf), [math]::Round($existing / 1MB, 1))
            return
        }
        Write-Info 'cached file looks truncated - re-downloading'
        Remove-Item -LiteralPath $Destination -Force
    }

    $partial = "$Destination.part"
    if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Force }

    Write-Info "downloading $Url"
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($null -ne $curl) {
        & curl.exe -L --fail --retry 3 --retry-delay 5 --connect-timeout 30 --progress-bar -o $partial $Url
        if ($LASTEXITCODE -ne 0) { throw "curl.exe exited with $LASTEXITCODE while downloading $Url" }
    }
    else {
        Invoke-WebRequest -Uri $Url -OutFile $partial -UseBasicParsing
    }

    $got = (Get-Item -LiteralPath $partial).Length
    if ($got -lt $MinimumBytes) { throw "download of $Url produced only $got bytes" }
    Move-Item -LiteralPath $partial -Destination $Destination -Force
    Write-Ok ("downloaded {0} ({1} MB)" -f (Split-Path $Destination -Leaf), [math]::Round($got / 1MB, 1))
}

function Expand-ZipTo {
    param(
        [Parameter(Mandatory = $true)] [string] $ZipPath,
        [Parameter(Mandatory = $true)] [string] $Destination
    )
    New-Dir $Destination
    Write-Info "extracting $(Split-Path $ZipPath -Leaf) -> $Destination"
    # bsdtar (tar.exe) understands zip and is ~5x faster than Expand-Archive on a 1.9 GB zip.
    $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
    if ($null -ne $tar) {
        & tar.exe -x -f $ZipPath -C $Destination
        if ($LASTEXITCODE -ne 0) { throw "tar.exe exited with $LASTEXITCODE while extracting $ZipPath" }
    }
    else {
        Expand-Archive -LiteralPath $ZipPath -DestinationPath $Destination -Force
    }
}

function Remove-Dir {
    param([string] $Path)
    if (Test-Path -LiteralPath $Path) {
        Write-Info "removing $Path"
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

# --------------------------------------------------------------------------------------
# environment helpers
# --------------------------------------------------------------------------------------
function Set-UserEnvVar {
    param([string] $Name, [string] $Value)
    $current = [Environment]::GetEnvironmentVariable($Name, 'User')
    if ($current -eq $Value) {
        Write-Skip "$Name already = $Value"
    }
    else {
        # setx as required by docs/06_MOBILE_SPEC.md; values here are far below the 1024-char limit.
        & setx.exe $Name $Value | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "setx $Name failed with $LASTEXITCODE" }
        Write-Ok "$Name = $Value"
    }
    Set-Item -Path ("Env:" + $Name) -Value $Value
}

function Add-UserPathEntries {
    param([string[]] $Entries)

    $current = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ($null -eq $current) { $current = '' }
    $parts = @($current -split ';' | Where-Object { $_.Trim() -ne '' })

    $added = @()
    foreach ($entry in $Entries) {
        $needle = $entry.TrimEnd('\')
        $hit = $parts | Where-Object { $_.TrimEnd('\') -ieq $needle }
        if ($null -eq $hit -or $hit.Count -eq 0) {
            $parts += $entry
            $added += $entry
        }
    }

    if ($added.Count -eq 0) {
        Write-Skip 'user PATH already contains every toolchain bin directory'
    }
    else {
        $newPath = ($parts -join ';')
        # NOT setx: setx silently TRUNCATES values at 1024 characters and PATH grows past that
        # on most machines. SetEnvironmentVariable('PATH', ..., 'User') writes the same
        # HKCU\Environment value and broadcasts WM_SETTINGCHANGE, with no length limit.
        [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
        foreach ($a in $added) { Write-Ok "user PATH += $a" }
        Write-Note 'PATH changes apply to NEW terminals only (or dot-source scripts\flutter_env.ps1).'
    }

    # make the tools usable inside THIS script run
    foreach ($entry in $Entries) {
        if (($env:PATH -split ';') -notcontains $entry) { $env:PATH = "$entry;$env:PATH" }
    }
}

function Invoke-WithYes {
    param(
        [Parameter(Mandatory = $true)] [string] $Exe,
        [string[]] $Arguments = @(),
        [int] $Answers = 80
    )
    # Non-interactive "yes |" equivalent for PowerShell 5.1.
    $yes = ((1..$Answers | ForEach-Object { 'y' }) -join "`r`n") + "`r`n"
    $yes | & $Exe @Arguments
}

# ======================================================================================
Write-Host ''
Write-Host '  Team Mausam - Flutter / JDK / Android SDK setup (user space, no admin)' -ForegroundColor White
Write-Host "  SdkRoot: $SdkRoot" -ForegroundColor White

$flutterDir  = Join-Path $SdkRoot 'flutter'
$jdkDir      = Join-Path $SdkRoot 'jdk-17'
$androidDir  = Join-Path $SdkRoot 'android'
$cmdlineDir  = Join-Path $androidDir 'cmdline-tools\latest'
$downloadDir = Join-Path $SdkRoot '_downloads'

$flutterBin  = Join-Path $flutterDir 'bin'
$flutterExe  = Join-Path $flutterBin 'flutter.bat'
$javaExe     = Join-Path $jdkDir 'bin\java.exe'
$sdkManager  = Join-Path $cmdlineDir 'bin\sdkmanager.bat'
$platformTools = Join-Path $androidDir 'platform-tools'

# --------------------------------------------------------------------------------------
Write-Step 'Preflight'
# --------------------------------------------------------------------------------------
$rootDrive = (Split-Path -Qualifier $SdkRoot)
$driveInfo = Get-PSDrive -Name $rootDrive.TrimEnd(':') -ErrorAction SilentlyContinue
if ($null -eq $driveInfo) { throw "drive $rootDrive does not exist" }
$freeGb = [math]::Round($driveInfo.Free / 1GB, 1)
Write-Info "free space on $rootDrive $freeGb GB"
if ($freeGb -lt 15) { throw "need at least 15 GB free on $rootDrive, found $freeGb GB" }

if ($null -eq (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    throw 'git.exe is not on PATH - Flutter requires git. Install Git for Windows (user-space installer) first.'
}
Write-Ok "git: $((Get-Command git.exe).Source)"

New-Dir $SdkRoot
New-Dir $downloadDir

# --------------------------------------------------------------------------------------
Write-Step "Flutter SDK ($FlutterChannel) -> $flutterDir"
# --------------------------------------------------------------------------------------
if ($Force) { Remove-Dir $flutterDir }

if (Test-Path -LiteralPath $flutterExe) {
    Write-Skip "flutter already installed at $flutterDir"
}
else {
    Write-Info 'reading releases_windows.json'
    $releases = Invoke-RestMethod -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json' -UseBasicParsing
    $hash = $releases.current_release.$FlutterChannel
    if ([string]::IsNullOrEmpty($hash)) { throw "no current_release for channel '$FlutterChannel'" }
    $release = $releases.releases | Where-Object { $_.hash -eq $hash -and $_.channel -eq $FlutterChannel } | Select-Object -First 1
    if ($null -eq $release) { throw "could not resolve release $hash in releases_windows.json" }

    $flutterUrl = "$($releases.base_url)/$($release.archive)"
    Write-Info "flutter $($release.version) (dart $($release.dart_sdk_version))"
    $flutterZip = Join-Path $downloadDir (Split-Path $release.archive -Leaf)
    Get-RemoteFile -Url $flutterUrl -Destination $flutterZip -MinimumBytes 500MB

    # the archive already contains a top-level "flutter\" directory
    Expand-ZipTo -ZipPath $flutterZip -Destination $SdkRoot
    if (-not (Test-Path -LiteralPath $flutterExe)) { throw "extraction finished but $flutterExe is missing" }
    Write-Ok "flutter $($release.version) installed"
}

# --------------------------------------------------------------------------------------
Write-Step "Eclipse Temurin JDK 17 -> $jdkDir"
# --------------------------------------------------------------------------------------
if ($Force) { Remove-Dir $jdkDir }

if (Test-Path -LiteralPath $javaExe) {
    Write-Skip "jdk already installed at $jdkDir"
}
else {
    $jdkUrl = 'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk'
    $jdkZip = Join-Path $downloadDir 'OpenJDK17U-jdk_x64_windows_hotspot.zip'
    Get-RemoteFile -Url $jdkUrl -Destination $jdkZip -MinimumBytes 100MB

    $stage = Join-Path $downloadDir '_jdk_stage'
    Remove-Dir $stage
    Expand-ZipTo -ZipPath $jdkZip -Destination $stage

    # the archive contains a versioned folder such as "jdk-17.0.20.1+1" - flatten it
    $inner = Get-ChildItem -LiteralPath $stage -Directory | Select-Object -First 1
    if ($null -eq $inner) { throw "unexpected JDK archive layout under $stage" }
    Remove-Dir $jdkDir
    Move-Item -LiteralPath $inner.FullName -Destination $jdkDir -Force
    Remove-Dir $stage

    if (-not (Test-Path -LiteralPath $javaExe)) { throw "extraction finished but $javaExe is missing" }
    Write-Ok "jdk installed ($($inner.Name))"
}

$env:JAVA_HOME = $jdkDir
# NOTE: `java -version` prints to stderr. Do NOT write `& $javaExe -version 2>&1` here:
# in PowerShell 5.1 redirecting a native command's stderr wraps each line in an ErrorRecord
# (NativeCommandError) which, with $ErrorActionPreference = 'Stop', aborts the whole script.
# Letting cmd.exe do the merge keeps the text on PowerShell's stdout stream.
$jdkVersionLine = @(& cmd.exe /c "`"$javaExe`" -version 2>&1")[0]
Write-Info "java: $jdkVersionLine"

# --------------------------------------------------------------------------------------
Write-Step "Android command-line tools -> $cmdlineDir"
# --------------------------------------------------------------------------------------
if ($Force) { Remove-Dir (Join-Path $androidDir 'cmdline-tools') }

if (Test-Path -LiteralPath $sdkManager) {
    Write-Skip "cmdline-tools already installed at $cmdlineDir"
}
else {
    $ctUrl = "https://dl.google.com/android/repository/commandlinetools-win-$($CmdlineToolsBuild)_latest.zip"
    $ctZip = Join-Path $downloadDir "commandlinetools-win-$($CmdlineToolsBuild)_latest.zip"
    Get-RemoteFile -Url $ctUrl -Destination $ctZip -MinimumBytes 50MB

    $stage = Join-Path $downloadDir '_cmdline_stage'
    Remove-Dir $stage
    Expand-ZipTo -ZipPath $ctZip -Destination $stage

    # archive layout: cmdline-tools\<bin,lib,...> ; sdkmanager insists on being in ...\latest\
    $inner = Join-Path $stage 'cmdline-tools'
    if (-not (Test-Path -LiteralPath $inner)) { throw "unexpected cmdline-tools archive layout under $stage" }
    New-Dir (Join-Path $androidDir 'cmdline-tools')
    Remove-Dir $cmdlineDir
    Move-Item -LiteralPath $inner -Destination $cmdlineDir -Force
    Remove-Dir $stage

    if (-not (Test-Path -LiteralPath $sdkManager)) { throw "extraction finished but $sdkManager is missing" }
    Write-Ok 'cmdline-tools installed'
}

# --------------------------------------------------------------------------------------
Write-Step 'Environment variables + user PATH'
# --------------------------------------------------------------------------------------
Set-UserEnvVar -Name 'FLUTTER_HOME'     -Value $flutterDir
Set-UserEnvVar -Name 'JAVA_HOME'        -Value $jdkDir
Set-UserEnvVar -Name 'ANDROID_HOME'     -Value $androidDir
Set-UserEnvVar -Name 'ANDROID_SDK_ROOT' -Value $androidDir

Add-UserPathEntries -Entries @(
    $flutterBin,
    (Join-Path $jdkDir 'bin'),
    $platformTools,
    (Join-Path $cmdlineDir 'bin')
)

# --------------------------------------------------------------------------------------
Write-Step 'Android SDK packages'
# --------------------------------------------------------------------------------------
$wanted = @('platform-tools')
foreach ($p in $AndroidPlatforms)  { $wanted += "platforms;$p" }
foreach ($b in $AndroidBuildTools) { $wanted += "build-tools;$b" }

$missing = @()
foreach ($pkg in $wanted) {
    $relative = $pkg -replace ';', '\'
    $target = Join-Path $androidDir $relative
    if (Test-Path -LiteralPath $target) { Write-Skip "$pkg present" }
    else { $missing += $pkg }
}

if ($missing.Count -eq 0) {
    Write-Skip 'all requested Android SDK packages are installed'
}
else {
    Write-Info ("installing: " + ($missing -join ', '))
    $sdkArgs = @("--sdk_root=$androidDir")
    $sdkArgs += $missing
    Invoke-WithYes -Exe $sdkManager -Arguments $sdkArgs -Answers 20
    if ($LASTEXITCODE -ne 0) { throw "sdkmanager failed with exit code $LASTEXITCODE" }
    Write-Ok 'Android SDK packages installed'
}

# --------------------------------------------------------------------------------------
Write-Step 'Accept Android SDK licenses'
# --------------------------------------------------------------------------------------
$licenseDir = Join-Path $androidDir 'licenses'
$licenseCount = 0
if (Test-Path -LiteralPath $licenseDir) {
    $licenseCount = (Get-ChildItem -LiteralPath $licenseDir -File -ErrorAction SilentlyContinue | Measure-Object).Count
}
if ($licenseCount -ge 5 -and -not $Force) {
    Write-Skip "$licenseCount license files already accepted in $licenseDir"
}
else {
    Invoke-WithYes -Exe $sdkManager -Arguments @("--sdk_root=$androidDir", '--licenses') -Answers 80
    Write-Ok 'sdkmanager --licenses done'
}

# --------------------------------------------------------------------------------------
Write-Step 'Wire Flutter to the Android SDK / JDK'
# --------------------------------------------------------------------------------------
& $flutterExe config --no-analytics | Out-Null
& $flutterExe config --android-sdk $androidDir
& $flutterExe config --jdk-dir $jdkDir
Write-Ok "flutter config --android-sdk $androidDir --jdk-dir $jdkDir"

Write-Info 'flutter doctor --android-licenses (non-interactive)'
Invoke-WithYes -Exe $flutterExe -Arguments @('doctor', '--android-licenses') -Answers 80

# --------------------------------------------------------------------------------------
if ($SkipDoctor) {
    Write-Step 'flutter doctor -v (skipped)'
}
else {
    Write-Step 'flutter doctor -v'
    & $flutterExe doctor -v
}

Write-Host ''
Write-Host '  Setup complete.' -ForegroundColor Green
Write-Host '  Open a NEW terminal (env vars are not visible in this one), or run:' -ForegroundColor Green
Write-Host '      . .\scripts\flutter_env.ps1        # PowerShell' -ForegroundColor Green
Write-Host '      source scripts/flutter_env.sh      # Git Bash' -ForegroundColor Green
Write-Host ''
