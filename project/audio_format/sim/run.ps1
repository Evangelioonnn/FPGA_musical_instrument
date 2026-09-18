param([string]$ModelSimBin = 'E:\QuartusII\modelsim_ase\win32aloem')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    if (!(Test-Path -LiteralPath 'work')) {
        & "$ModelSimBin\vlib.exe" work
        if ($LASTEXITCODE) { throw 'vlib failed' }
    }
    $sources = @('../../instrument/src/adsr_envelope.v','../../instrument/src/sine_rom.v',
        '../../instrument/src/note_table.v','../../instrument/src/synth_voice.v',
        '../../instrument/src/demo_events.v','../../instrument/src/pt8211_tx.v',
        '../../instrument/src/instrument_top.v','../src/pt8211_format_tx.v',
        '../src/audio_format_top.v','format_checker.v','format_tx_tb.v','format_integration_tb.v')
    & "$ModelSimBin\vlog.exe" -vlog01compat -work work @sources
    if ($LASTEXITCODE) { throw 'vlog failed' }
    foreach ($bench in @('format_tx_tb','format_integration_tb')) {
        $result = & "$ModelSimBin\vsim.exe" -c -l "$bench.log" -lib work $bench -do run.do 2>&1
        $simExit = $LASTEXITCODE
        $result | Write-Output
        $simText = $result -join "`n"
        $pass = $bench.ToUpper() + '_PASS'
        if ($simExit -ne 0 -or $simText -match '\*\* (Fatal|Error)' -or $simText -notmatch $pass) {
            throw "$bench failed; inspect $bench.log"
        }
    }
} finally { Pop-Location }
