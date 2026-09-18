param([string]$ModelSimBin = 'E:\QuartusII\modelsim_ase\win32aloem')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    & python ../tools/manager_vectors.py
    if ($LASTEXITCODE) { throw 'Manager oracle failed' }
    if (!(Test-Path -LiteralPath 'work')) {
        & "$ModelSimBin\vlib.exe" work
        if ($LASTEXITCODE) { throw 'vlib failed' }
    }
    $sources = @('../../instrument/src/adsr_envelope.v','../../instrument/src/sine_rom.v',
        '../../instrument/src/note_table.v','../../instrument/src/synth_voice.v',
        '../../instrument/src/demo_events.v','../../instrument/src/pt8211_tx.v',
        '../../instrument/src/instrument_top.v','../../instrument/sim/transport_tb.v',
        '../src/voice_manager4.v','../src/mixer4.v','../src/poly_synth4.v',
        '../src/poly_demo_events.v','../src/polyphony_top.v',
        'manager_tb.v','mixer_tb.v','poly_events_tb.v','poly_render_tb.v','poly_transport_tb.v')
    & "$ModelSimBin\vlog.exe" -vlog01compat -work work @sources
    if ($LASTEXITCODE) { throw 'vlog failed' }
    foreach ($bench in @('manager_tb','mixer_tb','poly_events_tb','poly_render_tb','poly_transport_tb')) {
        $result = & "$ModelSimBin\vsim.exe" -c -l "$bench.log" -lib work $bench -do run.do 2>&1
        $simExit = $LASTEXITCODE
        $result | Write-Output
        $simText = $result -join "`n"
        $pass = $bench.ToUpper() + '_PASS'
        if ($simExit -ne 0 -or $simText -match '\*\* (Fatal|Error)' -or $simText -notmatch $pass) {
            throw "$bench failed; inspect $bench.log"
        }
    }
    & python ../tools/analyze_poly.py
    if ($LASTEXITCODE) { throw 'Polyphony analysis failed' }
} finally { Pop-Location }
