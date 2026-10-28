param(
    [string]$ProjectDir = $PSScriptRoot
)

$source = Join-Path $ProjectDir "movement.asm"
$binOut = Join-Path $ProjectDir "movement.bin"
$rawOut = Join-Path $ProjectDir "movement.raw"
$disk = Join-Path $ProjectDir "movement.dsk"
$helloTxt = Join-Path $ProjectDir "hello-loader.txt"
$acJar = Join-Path $PSScriptRoot "..\..\..\tools\ac.jar"
$java = "C:\Program Files\Eclipse Adoptium\jre-25.0.4.101-hotspot\bin\java.exe"
# AppleCommander's -dos140 only writes a placeholder boot splash (no real DOS system
# code, for licensing reasons) - it can't auto-run a HELLO program. Start from AppleWin's
# bundled real DOS 3.3 System Master instead, which has genuine bootable system tracks.
$masterDisk = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\AppleWin.AppleWin_Microsoft.Winget.Source_8wekyb3d8bbwe\DOS 3.3 System Master - 680-0210-A.dsk"
$loadAddr = "0x6000"
$binName = "MOVEM4"

if (-not (Test-Path $source)) {
    throw "Source file not found at $source"
}

if (-not (Test-Path $masterDisk)) {
    throw "DOS 3.3 System Master not found at $masterDisk"
}

64tass -a -o $binOut $source
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# 64tass prepends a 2-byte little-endian load address; DOS 3.3 injection wants raw code only.
$bytes = [IO.File]::ReadAllBytes($binOut)
$raw = $bytes[2..($bytes.Length - 1)]
[IO.File]::WriteAllBytes($rawOut, $raw)

Copy-Item $masterDisk $disk -Force
# Force a plain local file: the OneDrive-synced master can carry a ReparsePoint/ReadOnly
# state that Copy-Item preserves, which then blocks Java from opening it for writing.
if (Test-Path $disk) {
    Set-ItemProperty -Path $disk -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
    $masterBytes = [IO.File]::ReadAllBytes($disk)
    Remove-Item $disk -Force
    [IO.File]::WriteAllBytes($disk, $masterBytes)
}

# The System Master ships with its own locked HELLO; unlock and remove it before replacing it.
& $java -jar $acJar -u $disk HELLO
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $java -jar $acJar -d $disk HELLO
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# PowerShell's object pipeline corrupts binary data, so use cmd's native stdin redirection instead.
cmd /c "`"$java`" -jar `"$acJar`" -p `"$disk`" $binName BIN $loadAddr < `"$rawOut`""
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# BRUN is a DOS command, not an Applesoft keyword - it must be sent via the Ctrl-D print trick.
Set-Content -Path $helloTxt -Value "10 D`$ = CHR`$(4)`r`n20 PRINT D`$;`"BRUN $binName`"`r`n" -NoNewline
cmd /c "`"$java`" -jar `"$acJar`" -bas `"$disk`" HELLO < `"$helloTxt`""
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Built: $binOut"
Write-Host "DOS 3.3 disk: $disk"
& $java -jar $acJar -l $disk
