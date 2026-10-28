param(
    [string]$AppleWinPath = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\AppleWin.AppleWin_Microsoft.Winget.Source_8wekyb3d8bbwe\AppleWin.exe",
    [string]$DiskImage = "$PSScriptRoot\hires.dsk"
)

if (-not (Test-Path $AppleWinPath)) {
    throw "AppleWin not found at $AppleWinPath"
}

if (-not (Test-Path $DiskImage)) {
    throw "Disk not found at $DiskImage. Run build.ps1 first."
}

Start-Process -FilePath $AppleWinPath -ArgumentList @(
    '-model', 'apple2p',
    '-d1', "`"$DiskImage`"",
    '-s7', 'empty',
    '-power-on'
)

Write-Host "Launched AppleWin with $DiskImage"
