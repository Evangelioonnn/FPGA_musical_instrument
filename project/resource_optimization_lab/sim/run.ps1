param([string]$ModelSimBin='E:/QuartusII/modelsim_ase/win32aloem',
      [string]$WorkLibrary='work_resource_opt',
      [string]$Benches='resource_sine_tb,resource_pruned_tb,resource_mult_tb,resource_shared_sine_tb,resource_shared_sine_compare_tb')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    if(Test-Path $WorkLibrary){Remove-Item -Recurse -Force $WorkLibrary}
    & "$ModelSimBin/vlib.exe" $WorkLibrary
    if($LASTEXITCODE){throw 'vlib failed'}
    $root=(Resolve-Path ../..).Path
    $sources=@(
        (Resolve-Path ../../instrument/src/sine_rom.v).Path,
        (Resolve-Path ../../instrument/src/adsr_envelope.v).Path,
        (Resolve-Path ../../instrument/src/note_table.v).Path,
        (Resolve-Path ../../instrument/src/pt8211_tx.v).Path,
        (Resolve-Path ../../input/knob_suite/src/knob_reference_voice.v).Path,
        (Resolve-Path ../../input/knob_suite/src/knob_gain.v).Path,
        (Resolve-Path ../../input/matrix_playable/src/playable_button.v).Path,
        (Resolve-Path ../../input/matrix_playable/src/playable_controls.v).Path,
        (Resolve-Path ../../input/matrix_playable/src/playable_keys.v).Path,
        (Resolve-Path ../../system/src/stream_fifo.v).Path,
        (Resolve-Path ../src/resource_sine_probe.v).Path,
        (Resolve-Path ../src/resource_mult_probe.v).Path,
        (Resolve-Path ../src/resource_shared_sine_bank.v).Path,
        (Resolve-Path ../src/resource_pruned_slot.v).Path,
        (Resolve-Path ../src/resource_pruned_bank.v).Path,
        (Resolve-Path resource_sine_tb.v).Path,
        (Resolve-Path resource_pruned_tb.v).Path,
        (Resolve-Path resource_mult_tb.v).Path,
        (Resolve-Path resource_shared_sine_tb.v).Path
        ,(Resolve-Path resource_shared_sine_compare_tb.v).Path
    )
    & "$ModelSimBin/vlog.exe" -vlog01compat -work $WorkLibrary @sources
    if($LASTEXITCODE){throw 'vlog failed'}
    foreach($bench in $Benches.Split(',')) {
        $result=& "$ModelSimBin/vsim.exe" -c -lib $WorkLibrary $bench -do "run -all; quit -f" 2>&1
        $result | Write-Output
        $body=$result -join "`n"
        $marker = if($bench -eq 'resource_sine_tb') {'RESOURCE_SHARED_SINE_TB_PASS'} elseif($bench -eq 'resource_mult_tb') {'RESOURCE_SHARED_MULT_TB_PASS'} elseif($bench -eq 'resource_shared_sine_tb') {'RESOURCE_SHARED_SINE_TB_PASS'} elseif($bench -eq 'resource_shared_sine_compare_tb') {'SHARED_SINE_COMPARE_PASS'} else {'RESOURCE_PRUNED_TB_PASS'}
        if($LASTEXITCODE -or $body -match '\*\* (Fatal|Error)' -or $body -notmatch $marker) {throw "Failed $bench"}
    }
} finally {Pop-Location}
