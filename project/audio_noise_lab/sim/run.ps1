param([string]$ModelSimBin='E:/QuartusII/modelsim_ase/win32aloem',
      [string]$WorkLibrary='work_noise_lab',
      [string]$Benches='gain_tb,tx_rate_tb,tx_format_tb,upsampler2_tb,upsampler4_tb,activity_gate_tb,buttons_tb,keys_tb,bank_tb,matrix_all_tb,board_tb')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    [xml]$project=Get-Content ../audio_noise_lab.gprj
    $projectRoot=(Resolve-Path ..).Path
    $sources=@($project.Project.FileList.File | Where-Object {$_.type -eq 'file.verilog'} |
        ForEach-Object {(Resolve-Path (Join-Path $projectRoot $_.path)).Path})
    $sources+=@(Get-ChildItem *.v | ForEach-Object {$_.FullName})
    if(!(Test-Path $WorkLibrary)) {
        & "$ModelSimBin/vlib.exe" $WorkLibrary
        if($LASTEXITCODE){throw 'vlib failed'}
    }
    & "$ModelSimBin/vlog.exe" -vlog01compat -work $WorkLibrary @sources
    if($LASTEXITCODE){throw 'vlog failed'}
    foreach($bench in $Benches.Split(',')) {
        $result=& "$ModelSimBin/vsim.exe" -c -l "$bench.log" -lib $WorkLibrary $bench -do run.do 2>&1
        $code=$LASTEXITCODE
        $result | Write-Output
        $body=$result -join "`n"
        if($code -ne 0 -or $body -match '\*\* (Fatal|Error)|FileWatch' -or
            $body -notmatch ($bench.ToUpper()+'_PASS')) {throw "Failed $bench"}
    }
} finally {Pop-Location}
