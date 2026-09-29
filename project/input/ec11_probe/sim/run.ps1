param([string]$ModelSimBin = 'E:\QuartusII\modelsim_ase\win32aloem')
$ErrorActionPreference = 'Stop'
$simDir = $PSScriptRoot
Push-Location $simDir
try {
    if (!(Test-Path -LiteralPath 'work')) {
        & "$ModelSimBin\vlib.exe" work
        if ($LASTEXITCODE) { throw 'vlib failed' }
    }
    & "$ModelSimBin\vlog.exe" -vlog01compat -work work `
        ec11_probe_tb.v `
        ../src/ec11_audio_probe_top.v `
        ../../src/ec11_input.v `
        ../../../instrument/src/synth_voice.v `
        ../../../instrument/src/adsr_envelope.v `
        ../../../instrument/src/sine_rom.v `
        ../../../instrument/src/note_table.v `
        ../../../instrument/src/pt8211_tx.v
    if ($LASTEXITCODE) { throw 'vlog failed' }
    Set-Content -LiteralPath simulation.log -Value ''
    $simResult = & "$ModelSimBin\vsim.exe" -c -l simulation.log -lib work ec11_probe_tb -do run.do 2>&1
    $simExit = $LASTEXITCODE
    $simResult | Write-Output
    $simText = $simResult -join "`n"
    if ($simExit -ne 0 -or $simText -match '\*\* (Fatal|Error)|FileWatch' -or
        $simText -notmatch 'EC11_PROBE_TB_PASS') {
        throw 'EC11 probe simulation did not pass; inspect simulation.log'
    }
} finally {
    Pop-Location
}
