param([string]$ModelSimBin='E:/QuartusII/modelsim_ase/win32aloem',
      [string]$WorkLibrary='work_final_dual',
      [string]$Benches='final_voice_tb,final_engine_tb')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    $sources=@(Get-ChildItem ../src/*.v | ForEach-Object {$_.FullName})
    $sources+=@(Get-ChildItem *.v | ForEach-Object {$_.FullName})
    if(Test-Path $WorkLibrary){Remove-Item -Recurse -Force $WorkLibrary}
    & "$ModelSimBin/vlib.exe" $WorkLibrary
    if($LASTEXITCODE){throw 'vlib failed'}
    & "$ModelSimBin/vlog.exe" -vlog01compat -work $WorkLibrary @sources
    if($LASTEXITCODE){throw 'vlog failed'}
    foreach($bench in $Benches.Split(',')) {
        $result=& "$ModelSimBin/vsim.exe" -c -lib $WorkLibrary $bench -do 'run -all; quit -f' 2>&1
        $result | Write-Output
        $body=$result -join "`n"
        if($LASTEXITCODE -or $body -match '\*\* (Fatal|Error)' -or
           $body -notmatch ($bench.ToUpper()+'_PASS')) {throw "Failed $bench"}
    }
} finally {Pop-Location}
