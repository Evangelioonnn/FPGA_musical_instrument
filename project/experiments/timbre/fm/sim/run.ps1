param([string]$ModelSimBin='E:/QuartusII/modelsim_ase/win32aloem',
    [string]$PythonExe='python')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    & $PythonExe ../tools/verify.py prepare
    if($LASTEXITCODE) {throw 'FM independent vectors failed'}
    if(!(Test-Path work)) {& "$ModelSimBin/vlib.exe" work;if($LASTEXITCODE){throw 'vlib failed'}}
    $sources=Get-ChildItem ../src/*.v,./*.v | ForEach-Object {$_.FullName}
    & "$ModelSimBin/vlog.exe" -vlog01compat -work work @sources
    if($LASTEXITCODE){throw 'FM vlog failed'}
    foreach($bench in @('fm_control_tb','fm_numeric_tb')) {
        Set-Content -LiteralPath "$bench.log" -Value ''
        & "$ModelSimBin/vsim.exe" -c -l "$bench.log" -lib work $bench -do run.do
        $code=$LASTEXITCODE
        $body=Get-Content -LiteralPath "$bench.log" -Raw
        if($code -ne 0 -or $body -match '\*\* (Fatal|Error)|FileWatch' -or $body -notmatch ($bench.ToUpper()+'_PASS')) {
            throw "$bench failed"
        }
    }
    & $PythonExe ../tools/verify.py analyze
    if($LASTEXITCODE) {throw 'FM mathematical acceptance failed'}
} finally {Pop-Location}
