param([string]$ModelSimBin='E:/QuartusII/modelsim_ase/win32aloem',
      [string]$PythonExe='python', [string]$WorkLibrary='work', [string]$RunDirectory='',
      [switch]$FullPools,
      [string]$Benches='reference_tb,bank_tb,controls_tb,processing_tb,pluck_equivalence_tb,lifecycle_tb,multi_tb,transport_tb,render_tb,pitch_tb,pedal_render_tb')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    $sources=@(Get-ChildItem ../src/*.v | ForEach-Object {$_.FullName})
    $sources+=@('../../src/ec11_input.v','../../../system/src/stream_fifo.v',
        '../../../instrument/src/synth_voice.v','../../../instrument/src/adsr_envelope.v',
        '../../../instrument/src/sine_rom.v','../../../instrument/src/note_table.v',
        '../../../instrument/src/pt8211_tx.v','../../../experiments/delay/src/feedback_delay.v')
    $sources+=Get-ChildItem ../../../experiments/timbre/fm/src/*.v | ForEach-Object {$_.FullName}
    $sources+=Get-ChildItem ../../../experiments/timbre/pluck/src/*.v | ForEach-Object {$_.FullName}
    $sources+=Get-ChildItem *.v | ForEach-Object {$_.FullName}
    $sources=@($sources | ForEach-Object {(Resolve-Path -LiteralPath $_).Path})
    if($RunDirectory) {
        $taskRunPath=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot $RunDirectory))
        if(!$taskRunPath.StartsWith($PSScriptRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
            throw 'RunDirectory must be inside this sim directory'
        }
        New-Item -ItemType Directory -Force -Path $taskRunPath | Out-Null
        Set-Location -LiteralPath $taskRunPath
    }
    if(!(Test-Path $WorkLibrary)) {
        & "$ModelSimBin/vlib.exe" $WorkLibrary
        if($LASTEXITCODE){throw 'vlib failed'}
    }
    & "$ModelSimBin/vlog.exe" -vlog01compat -work $WorkLibrary @sources
    if($LASTEXITCODE){throw 'vlog failed'}
    foreach($bench in $Benches.Split(',')) {
        $benchOptions=@()
        if($FullPools -and $bench -eq 'render_tb') {$benchOptions=@('-gFULL_POOLS=1','-gIDLE_CYCLES=128')}
        $result=& "$ModelSimBin/vsim.exe" -c -l "$bench.log" -lib $WorkLibrary $bench @benchOptions -do (Join-Path $PSScriptRoot 'run.do') 2>&1
        $code=$LASTEXITCODE
        $result | Write-Output
        $body=$result -join "`n"
        if($code -ne 0 -or $body -match '\*\* (Fatal|Error)|FileWatch' -or
            $body -notmatch ($bench.ToUpper()+'_PASS')) {throw "Failed $bench"}
    }
} finally {Pop-Location}
