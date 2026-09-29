param([string]$ModelSimBin='E:/QuartusII/modelsim_ase/win32aloem',
      [string]$PythonExe='python',[string]$WorkLibrary='work',
      [string]$Benches='buttons_tb,keys_tb,numeric_tb,bank_tb,matrix_all_tb,input_phase_tb,event_phase_tb,board_tb,led_tb,render_reference_tb,render_pluck_tb,render_fm_tb')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    [xml]$project=Get-Content ../matrix_playable.gprj
    $sources=@($project.Project.FileList.File | Where-Object {$_.type -eq 'file.verilog'} | ForEach-Object {(Resolve-Path (Join-Path '..' $_.path)).Path})
    $sources+=(Resolve-Path ../../../experiments/timbre/fm/src/fm_voice.v).Path
    $sources+=@(Get-ChildItem *.v | ForEach-Object {$_.FullName})
    if(!(Test-Path $WorkLibrary)) { & "$ModelSimBin/vlib.exe" $WorkLibrary; if($LASTEXITCODE){throw 'vlib failed'} }
    & "$ModelSimBin/vlog.exe" -vlog01compat -work $WorkLibrary @sources
    if($LASTEXITCODE){throw 'vlog failed'}
    if($Benches.Split(',') -contains 'matrix_all_tb') {
        & $PythonExe ../tools/matrix_oracle.py
        if($LASTEXITCODE){throw 'matrix oracle failed'}
    }
    foreach($bench in $Benches.Split(',')) {
        $result=& "$ModelSimBin/vsim.exe" -c -l "$bench.log" -lib $WorkLibrary $bench -do run.do 2>&1
        $code=$LASTEXITCODE
        $result | Write-Output
        $body=$result -join "`n"
        if($code -ne 0 -or $body -match '\*\* (Fatal|Error)|FileWatch' -or
            $body -notmatch ($bench.ToUpper()+'_PASS')) {throw "Failed $bench"}
    }
} finally {Pop-Location}
