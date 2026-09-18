param([string]$ModelSimBin='E:\QuartusII\modelsim_ase\win32aloem',
    [string]$PythonExe='python',[switch]$Quick)
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    if(!(Test-Path work)) { & "$ModelSimBin/vlib.exe" work; if($LASTEXITCODE){throw 'vlib failed'} }
    $sources=@('../../instrument/src/adsr_envelope.v','../../instrument/src/sine_rom.v',
        '../../instrument/src/note_table.v','../../instrument/src/pt8211_tx.v',
        '../../expression/src/expression_controls.v','../../expression/src/performance_manager.v',
        '../../instrument/src/synth_voice.v','../src/baseline_core.v',
        '../src/baseline_demo.v','../src/expression_baseline_top.v','./baseline_tb.v',
        './baseline_voice_tb.v','./baseline_mixer_tb.v','./baseline_render_tb.v')
    & "$ModelSimBin/vlog.exe" -vlog01compat -work work @sources
    if($LASTEXITCODE){throw 'vlog failed'}
    $benches=@('baseline_voice_tb','baseline_mixer_tb','baseline_tb')
    if(!$Quick) {$benches+='baseline_render_tb'}
    foreach($bench in $benches) {
        # Stream output and inspect the fresh log, not just the exit code:
        # ModelSim 10.1d can return zero after a FileWatch startup failure.
        Set-Content -LiteralPath "$bench.log" -Value ''
        & "$ModelSimBin/vsim.exe" -c -l "$bench.log" -lib work $bench -do run.do
        $code=$LASTEXITCODE
        $body=Get-Content -LiteralPath "$bench.log" -Raw
        if($code -ne 0 -or $body -match '\*\* (Fatal|Error)|FileWatch' -or
            $body -notmatch ($bench.ToUpper()+'_PASS')) {throw "$bench failed"}
    }
    if(!$Quick) {
        & $PythonExe ../tools/analyze_baseline.py
        if($LASTEXITCODE){throw 'Baseline audio analysis failed'}
    }
} finally {Pop-Location}
