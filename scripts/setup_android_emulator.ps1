<#
.SYNOPSIS
    Create the `mausam_pixel` Android emulator (AVD) for the Mausam prototype - Windows.

.DESCRIPTION
    The emulator is OPTIONAL. Chrome (`flutter run -d chrome`) and a real phone over USB both
    work without it, and judges are given the APK. Use this only if you want a virtual device.

    What it does, in order:
      1. locates the Android SDK (ANDROID_HOME / ANDROID_SDK_ROOT, then D:\sdk\android),
      2. installs `platform-tools`, `emulator` and the system image with sdkmanager,
      3. accepts the SDK licences,
      4. creates the AVD `mausam_pixel` with avdmanager (skipped when it already exists).

    Then start it with scripts\run_emulator.ps1.

    DISK: the system image is ~1.5 GB and the emulator package another ~1 GB. Check free
    space before running this.

    ONE-TIME ADMIN STEP (hardware acceleration). x86_64 images need virtualization, which on
    Windows means the **Windows Hypervisor Platform** feature plus virtualization enabled in
    the BIOS/UEFI (Intel VT-x / AMD-V). Turning it on needs administrator rights ONCE:

        Windows Features -> tick "Windows Hypervisor Platform" (and "Hyper-V" if offered),
        reboot; or, from an elevated PowerShell:
        dism /online /Enable-Feature /FeatureName:HypervisorPlatform /All

        BIOS/UEFI -> Advanced/CPU -> enable "Intel (VMX) Virtualization Technology" or
        "AMD SVM Mode".

    Without it the emulator either refuses to boot or runs at software speed (unusably slow).
    Nothing else in this repo needs administrator rights.

.PARAMETER SdkRoot
    Android SDK root. Defaults to ANDROID_HOME, then ANDROID_SDK_ROOT, then D:\sdk\android.

.PARAMETER Image
    System-image package. Defaults to the x86_64 image for Intel/AMD hosts; on an ARM host
    (Windows on ARM) pass `-Image "system-images;android-35;google_apis;arm64-v8a"`.

.PARAMETER AvdName
    Name of the AVD to create. Default `mausam_pixel`.

.EXAMPLE
    .\scripts\setup_android_emulator.ps1
    .\scripts\setup_android_emulator.ps1 -SdkRoot 'D:\sdk\android'
#>
[CmdletBinding()]
param(
    [string] $SdkRoot = $(
        if ($env:ANDROID_HOME) { $env:ANDROID_HOME }
        elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT }
        else { 'D:\sdk\android' }
    ),
    [string] $Image = 'system-images;android-35;google_apis;x86_64',
    [string] $AvdName = 'mausam_pixel',
    [string] $Device = 'pixel_6'
)

$ErrorActionPreference = 'Stop'

function Write-Step($message) { Write-Host "==> $message" -ForegroundColor Cyan }
function Write-Note($message) { Write-Host "    $message" -ForegroundColor DarkGray }

Write-Step "Android SDK root: $SdkRoot"
if (-not (Test-Path $SdkRoot)) {
    throw "No Android SDK at '$SdkRoot'. Run scripts\setup_flutter_windows.ps1 first, or pass -SdkRoot."
}

$sdkmanager = Join-Path $SdkRoot 'cmdline-tools\latest\bin\sdkmanager.bat'
$avdmanager = Join-Path $SdkRoot 'cmdline-tools\latest\bin\avdmanager.bat'
foreach ($tool in @($sdkmanager, $avdmanager)) {
    if (-not (Test-Path $tool)) {
        throw "Missing $tool - install the Android command-line tools (see docs/SETUP_WINDOWS.md)."
    }
}

if (-not $env:JAVA_HOME) {
    $candidate = Join-Path (Split-Path $SdkRoot -Parent) 'jdk-17'
    if (Test-Path $candidate) {
        $env:JAVA_HOME = $candidate
        Write-Note "JAVA_HOME was not set; using $candidate"
    } else {
        throw 'JAVA_HOME is not set and no jdk-17 was found next to the SDK. Set JAVA_HOME to a JDK 17.'
    }
}

Write-Step "Installing platform-tools, emulator and $Image"
Write-Note 'First run downloads ~2 GB; this can take several minutes.'
& $sdkmanager "--sdk_root=$SdkRoot" 'platform-tools' 'emulator' $Image
if ($LASTEXITCODE -ne 0) { throw "sdkmanager failed with exit code $LASTEXITCODE" }

Write-Step 'Accepting SDK licences'
# sdkmanager --licenses asks one y/N question per unaccepted licence; feed it enough answers.
(1..30 | ForEach-Object { 'y' }) | & $sdkmanager "--sdk_root=$SdkRoot" '--licenses' | Out-Null

$existing = & $avdmanager 'list' 'avd' '-c'
if ($existing -contains $AvdName) {
    Write-Step "AVD '$AvdName' already exists - leaving it alone"
} else {
    Write-Step "Creating AVD '$AvdName' from $Image"
    'no' | & $avdmanager 'create' 'avd' '-n' $AvdName '-k' $Image '-d' $Device
    if ($LASTEXITCODE -ne 0) { throw "avdmanager failed with exit code $LASTEXITCODE" }
}

Write-Step 'Done'
Write-Note "Start it with:  .\scripts\run_emulator.ps1"
Write-Note "Then:           cd app; flutter run -d $AvdName"
Write-Note 'Backend URL inside the emulator is http://10.0.2.2:8000 (not localhost).'
Write-Note 'If the emulator will not boot, see the ONE-TIME ADMIN STEP in the header of this file.'
