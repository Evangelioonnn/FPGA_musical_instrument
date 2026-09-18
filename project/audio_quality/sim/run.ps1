param([string]$ModelSimBin = 'E:\QuartusII\modelsim_ase\win32aloem',
      [string]$PythonExe = 'python')
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
        '../../instrument/src/instrument_top.v','../../instrument/sim/transport_tb.v',
        '../src/quality_voice.v','../src/audio_quality_top.v',
        'quality_core_tb.v','quality_render_tb.v','quality_transport_tb.v')
    & "$ModelSimBin\vlog.exe" -vlog01compat -work work @sources
    if ($LASTEXITCODE) { throw 'vlog failed' }
    foreach ($bench in @('quality_core_tb','quality_render_tb','quality_transport_tb')) {
        $result = & "$ModelSimBin\vsim.exe" -c -l "$bench.log" -lib work $bench -do run.do 2>&1
        $simExit = $LASTEXITCODE
        $result | Write-Output
        $simText = $result -join "`n"
        $pass = $bench.ToUpper() + '_PASS'
        if ($simExit -ne 0 -or $simText -match '\*\* (Fatal|Error)' -or $simText -notmatch $pass) {
            throw "$bench failed; inspect $bench.log"
        }
    }
    & $PythonExe ../tools/analyze_quality.py
    if ($LASTEXITCODE) { throw 'A/B audio analysis failed (Python requires numpy)' }
} finally { Pop-Location }
