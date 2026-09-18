param([string]$ModelSimBin = 'E:\QuartusII\modelsim_ase\win32aloem')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    if (!(Test-Path -LiteralPath 'work')) {
        & "$ModelSimBin\vlib.exe" work
        if ($LASTEXITCODE) { throw 'vlib failed' }
    }
    $sources = @('../src/adsr_envelope.v','../src/sine_rom.v','../src/note_table.v',
        '../src/synth_voice.v','../src/demo_events.v','../src/pt8211_tx.v',
        '../src/instrument_top.v','envelope_tb.v','core_tb.v','demo_render_tb.v','transport_tb.v')
    & "$ModelSimBin\vlog.exe" -vlog01compat -work work @sources
    if ($LASTEXITCODE) { throw 'vlog failed' }
    foreach ($bench in @('envelope_tb','core_tb','demo_render_tb','transport_tb')) {
        $result = & "$ModelSimBin\vsim.exe" -c -l "$bench.log" -lib work $bench -do run.do 2>&1
        $simExit = $LASTEXITCODE
        $result | Write-Output
        $simText = $result -join "`n"
        $pass = $bench.ToUpper() + '_PASS'
        if ($simExit -ne 0 -or $simText -match '\*\* (Fatal|Error)' -or $simText -notmatch $pass) {
            throw "$bench failed; inspect $bench.log"
        }
    }
    & python ../tools/analyze_demo.py
    if ($LASTEXITCODE) { throw 'Audio analysis failed' }
} finally { Pop-Location }
