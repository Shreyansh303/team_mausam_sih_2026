<#
.SYNOPSIS
    Start the `mausam_pixel` Android emulator and wait until it has booted - Windows.

.DESCRIPTION
    Run scripts\setup_android_emulator.ps1 once first. This script:
      1. starts the AVD detached (the emulator window stays open after the script returns),
      2. waits for adb to report the device,
      3. waits for `sys.boot_completed`,
      4. prints the `flutter run` line to use.

    Nothing here needs administrator rights - but the emulator itself needs the one-time
    Windows Hypervisor Platform / BIOS virtualization step described in
    scripts\setup_android_emulator.ps1.

.PARAMETER AvdName
    AVD to boot. Default `mausam_pixel`.

.PARAMETER SdkRoot
    Android SDK root. Defaults to ANDROID_HOME, then ANDROID_SDK_ROOT, then D:\sdk\android.

.PARAMETER ColdBoot
    Ignore the saved snapshot and boot from scratch (use after an emulator upgrade).

.PARAMETER TimeoutSeconds
    How long to wait for the boot to finish. Default 300.

.EXAMPLE
    .\scripts\run_emulator.ps1
    .\scripts\run_emulator.ps1 -ColdBoot
#>
[CmdletBinding()]
param(
    [string] $AvdName = 'mausam_pixel',
    [string] $SdkRoot = $(
        if ($env:ANDROID_HOME) { $env:ANDROID_HOME }
        elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT }
        else { 'D:\sdk\android' }
    ),
    [switch] $ColdBoot,
    [int] $TimeoutSeconds = 300
)

$ErrorActionPreference = 'Stop'

function Write-Step($message) { Write-Host "==> $message" -ForegroundColor Cyan }
function Write-Note($message) { Write-Host "    $message" -ForegroundColor DarkGray }

$emulator = Join-Path $SdkRoot 'emulator\emulator.exe'
$adb = Join-Path $SdkRoot 'platform-tools\adb.exe'
foreach ($tool in @($emulator, $adb)) {
    if (-not (Test-Path $tool)) {
        throw "Missing $tool - run scripts\setup_android_emulator.ps1 first."
    }
}

$avds = & $emulator '-list-avds'
if ($avds -notcontains $AvdName) {
    throw "No AVD called '$AvdName'. Run scripts\setup_android_emulator.ps1 (found: $($avds -join ', '))."
}

$emulatorArgs = @('-avd', $AvdName, '-netdelay', 'none', '-netspeed', 'full')
if ($ColdBoot) { $emulatorArgs += '-no-snapshot-load' }

Write-Step "Starting $AvdName"
Start-Process -FilePath $emulator -ArgumentList $emulatorArgs -WindowStyle Normal | Out-Null

Write-Step 'Waiting for the device (adb wait-for-device)'
& $adb 'start-server' | Out-Null
& $adb 'wait-for-device'

Write-Step 'Waiting for the boot to complete'
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while ((Get-Date) -lt $deadline) {
    $booted = (& $adb 'shell' 'getprop' 'sys.boot_completed' 2>$null | Out-String).Trim()
    if ($booted -eq '1') {
        $serial = (& $adb 'devices' | Select-String 'emulator-' | ForEach-Object { ($_ -split '\s+')[0] } | Select-Object -First 1)
        Write-Step "Booted: $serial"
        Write-Note "cd app; flutter run -d $serial"
        Write-Note 'In the app, set Settings -> Backend URL to http://10.0.2.2:8000'
        Write-Note '(10.0.2.2 is the emulator alias for the host machine; localhost is the emulator itself.)'
        exit 0
    }
    Start-Sleep -Seconds 3
}

throw "The emulator did not finish booting within $TimeoutSeconds s. Try -ColdBoot, or check that Windows Hypervisor Platform / BIOS virtualization is enabled (see scripts\setup_android_emulator.ps1)."
