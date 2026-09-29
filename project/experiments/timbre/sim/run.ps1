param([string]$ModelSimBin='E:/QuartusII/modelsim_ase/win32aloem')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    if(!(Test-Path work)) {& "$ModelSimBin/vlib.exe" work;if($LASTEXITCODE){throw 'vlib failed'}}
    $sources=@()
    foreach($dir in @('../fm/src','../pluck/src','../shared')) {
        $sources+=Get-ChildItem "$dir/*.v" | ForEach-Object {$_.FullName}
    }
    $sources+=@('../../../instrument/src/note_table.v',
        '../../../instrument/src/pt8211_tx.v',
        '../../../instrument/sim/transport_tb.v','probe_tb.v','demo_tb.v')
    & "$ModelSimBin/vlog.exe" -vlog01compat -work work @sources
    if($LASTEXITCODE){throw 'vlog failed'}
    foreach($bench in @('demo_tb','probe_tb')) {
        & "$ModelSimBin/vsim.exe" -c -l "$bench.log" -lib work $bench -do run.do
        $result=$LASTEXITCODE
        $body=Get-Content "$bench.log" -Raw
        if($result -ne 0 -or $body -match '\*\* (Fatal|Error)|FileWatch' -or $body -notmatch ($bench.ToUpper()+'_PASS')) {
            throw "$bench failed"
        }
    }
} finally {Pop-Location}
