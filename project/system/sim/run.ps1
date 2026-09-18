param([string]$ModelSimBin='E:/QuartusII/modelsim_ase/win32aloem',
    [string]$PythonExe='python',
    [string[]]$Benches=@('streams_tb','arbiter_tb','keys_tb','matrix_tb','encoder_tb',
        'pressure_tb','failsafe_tb','controls_v0_tb','observability_tb','telemetry_tb',
        'core_features_tb@16','core_features_tb@32','system_input_tb','transport_v0_tb',
        'capacity_transport_tb','input_render_tb','lab_tb','equivalence_tb'))
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    & $PythonExe ../tools/generate_input_vectors.py
    if($LASTEXITCODE) {throw 'Input oracle generation failed'}
    if(!(Test-Path work)) {& "$ModelSimBin/vlib.exe" work;if($LASTEXITCODE){throw 'vlib failed'}}
    $sources=@()
    foreach($dir in @('../../instrument/src','../../expression/src','../../expression_baseline/src','../../input/src','../../lab/src','../src','.')) {
        $sources+=Get-ChildItem "$dir/*.v" | ForEach-Object {$_.FullName}
    }
    & "$ModelSimBin/vlog.exe" -vlog01compat -work work @sources
    if($LASTEXITCODE){throw 'vlog failed'}
    foreach($job in $Benches) {
        $parts=$job.Split('@');$bench=$parts[0];$extra=@();$label=$bench
        if($parts.Length -gt 1){$extra=@("-gN=$($parts[1])");$label="${bench}_N$($parts[1])"}
        Set-Content -LiteralPath "$label.log" -Value ''
        & "$ModelSimBin/vsim.exe" -c -l "$label.log" -lib work $bench @extra -do run.do
        $code=$LASTEXITCODE
        $body=Get-Content -LiteralPath "$label.log" -Raw
        if($code -ne 0 -or $body -match '\*\* (Fatal|Error)|FileWatch' -or $body -notmatch ($bench.ToUpper()+'_PASS')) {
            throw "$bench failed"
        }
    }
} finally {Pop-Location}
