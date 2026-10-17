param([string]$ModelSimBin='E:/QuartusII/modelsim_ase/win32aloem',
    [string]$PythonExe='python')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    & $PythonExe ../tools/generate_tables.py
    if($LASTEXITCODE) {throw 'Table generation failed'}
    if(!(Test-Path work)) {& "$ModelSimBin/vlib.exe" work;if($LASTEXITCODE){throw 'vlib failed'}}
    & "$ModelSimBin/vlog.exe" -vlog01compat -work work ../src/pluck_note_table.v ../src/pluck_voice.v pluck_tb.v
    if($LASTEXITCODE){throw 'vlog failed'}
    & "$ModelSimBin/vsim.exe" -c -l pluck_tb.log -lib work pluck_tb -do run.do
    $code=$LASTEXITCODE
    $body=Get-Content -LiteralPath pluck_tb.log -Raw
    if($code -ne 0 -or $body -match '\*\* (Fatal|Error)|FileWatch' -or $body -notmatch 'PLUCK_TB_PASS') {
        throw 'pluck_tb failed'
    }
    & $PythonExe ../tools/analyze.py
    if($LASTEXITCODE){throw 'Independent physical/model analysis failed'}
} finally {Pop-Location}
