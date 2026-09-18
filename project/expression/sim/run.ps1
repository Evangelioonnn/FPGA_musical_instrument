param([string]$ModelSimBin='E:\QuartusII\modelsim_ase\win32aloem',[switch]$Quick,[switch]$Supplemental)
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    & python ../tools/generate_vectors.py
    if($LASTEXITCODE) {throw 'Oracle generation failed'}
    if(!(Test-Path work)) { & "$ModelSimBin/vlib.exe" work; if($LASTEXITCODE){throw 'vlib failed'} }
    $sources=@('../../instrument/src/adsr_envelope.v','../../instrument/src/sine_rom.v',
        '../../instrument/src/note_table.v','../../instrument/src/pt8211_tx.v')
    $sources+=Get-ChildItem ../src/*.v | ForEach-Object {$_.FullName}
    $sources+=Get-ChildItem ./*.v | ForEach-Object {$_.FullName}
    & "$ModelSimBin/vlog.exe" -vlog01compat -work work @sources
    if($LASTEXITCODE) {throw 'Verilog compilation failed'}
    $jobs=@(@('manager_tb','-gN=4'),@('manager_tb','-gN=8'),@('controls_tb'),@('mixer_meter_tb','-gN=4'),@('mixer_meter_tb','-gN=8'),@('voice_tb'),@('voice_numeric_tb'))
    if(!$Quick) {$jobs+=@(@('core_tb','-gN=4'),@('core_tb','-gN=8'),@('render_tb'),@('integration_tb'))}
    if($Supplemental) {$jobs=@(@('voice_numeric_tb'),@('mixer_meter_tb','-gN=4'),@('mixer_meter_tb','-gN=8'),@('core_tb','-gN=4'),@('core_tb','-gN=8'))}
    foreach($job in $jobs) {
        $bench=$job[0]; $extra=@();if($job.Length -gt 1){$extra=$job[1..($job.Length-1)]}
        $label=($job -join '_') -replace '[^a-zA-Z0-9_]',''
        $result=& "$ModelSimBin/vsim.exe" -c -l "$label.log" -lib work $bench @extra -do run.do 2>&1
        $code=$LASTEXITCODE; $result | Write-Output;$body=$result -join "`n"
        if($code -ne 0 -or $body -match '\*\* (Fatal|Error)' -or $body -notmatch ($bench.ToUpper()+'_PASS')) {
            throw "Failed $label"
        }
    }
    if(!$Quick -and !$Supplemental) {
        & python ../tools/analyze_audio.py
        if($LASTEXITCODE) {throw 'Audio analysis failed'}
    }
} finally {Pop-Location}
