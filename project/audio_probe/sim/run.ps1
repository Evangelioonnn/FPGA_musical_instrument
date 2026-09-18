param([string]$ModelSimBin = 'E:\QuartusII\modelsim_ase\win32aloem')
$ErrorActionPreference = 'Stop'
$simDir = $PSScriptRoot
Push-Location $simDir
try {
    if (!(Test-Path -LiteralPath 'work')) {
        & "$ModelSimBin\vlib.exe" work
        if ($LASTEXITCODE) { throw 'vlib failed' }
    }
    & "$ModelSimBin\vlog.exe" -vlog01compat -work work audio_probe_tb.v ../src/audio_probe_top.v
    if ($LASTEXITCODE) { throw 'vlog failed' }
    $simResult = & "$ModelSimBin\vsim.exe" -c -l simulation.log -lib work audio_probe_tb -do 'onerror {quit -code 1 -f}; run -all; quit -f' 2>&1
    $simExit = $LASTEXITCODE
    $simResult | Write-Output
    $simText = $simResult -join "`n"
    if ($simExit -ne 0 -or $simText -match '\*\* (Fatal|Error)' -or
        $simText -notmatch 'AUDIO_PROBE_TB_PASS' -or
        $simText -notmatch 'TONE_CHECK_PASS' -or $simText -notmatch 'PATTERN_CHECK_PASS') {
        throw 'Audio simulation did not pass; inspect simulation.log'
    }
} finally {
    Pop-Location
}
