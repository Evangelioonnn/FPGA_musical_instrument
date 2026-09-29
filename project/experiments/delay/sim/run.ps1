param([string]$ModelSimBin='E:/QuartusII/modelsim_ase/win32aloem',[string]$PythonExe='python')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    & $PythonExe ../tools/generate_vectors.py
    if($LASTEXITCODE){throw 'oracle failed'}
    if(!(Test-Path work)){& "$ModelSimBin/vlib.exe" work;if($LASTEXITCODE){throw 'vlib failed'}}
    & "$ModelSimBin/vlog.exe" -vlog01compat -work work ../src/feedback_delay.v feedback_delay_tb.v delay_render_tb.v
    if($LASTEXITCODE){throw 'vlog failed'}
    foreach($size in @(8,4096)){
        $log="delay$size.log"
        Set-Content -LiteralPath $log -Value ''
        & "$ModelSimBin/vsim.exe" -c -l $log -lib work feedback_delay_tb "-gD=$size" -do ../../../system/sim/run.do
        $body=Get-Content $log -Raw
        if($LASTEXITCODE -or $body -match '\*\* (Fatal|Error)' -or $body -notmatch 'FEEDBACK_DELAY_TB_PASS'){throw 'delay test failed'}
    }
    if(Test-Path '../../../system/sim/system_samples.txt'){
        & "$ModelSimBin/vsim.exe" -c -l delay_render.log -lib work delay_render_tb -do ../../../system/sim/run.do
        $body=Get-Content delay_render.log -Raw
        if($LASTEXITCODE -or $body -match '\*\* (Fatal|Error)' -or $body -notmatch 'DELAY_RENDER_TB_PASS'){throw 'delay render failed'}
    }
} finally {Pop-Location}
