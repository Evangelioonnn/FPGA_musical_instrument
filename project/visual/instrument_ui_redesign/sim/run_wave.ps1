param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin',
      [string[]]$Tests=@('av_wave_units_tb','av_wave_auto_tb','av_wave_video_tb'))
$ErrorActionPreference='Stop'
$projectDir=Split-Path $PSScriptRoot -Parent
$workDir=Join-Path $projectDir 'impl/sim_wave'
New-Item -ItemType Directory -Force $workDir | Out-Null
$sources=@('av_navigation','av_pcm_window','av_wave_capture','av_frame_ram','av_timing','av_font','av_labels','av_page_writer','av_renderer','av_wave_labels','av_wave_renderer','av_display') | ForEach-Object {Join-Path $projectDir "src/rtl/$_.v"}
$sources+=Join-Path $projectDir '../../final_dual_timbre/src/playable_button.v'
$sources+=@('av_wave_units_tb','av_wave_auto_tb','av_wave_video_tb') | ForEach-Object {Join-Path $PSScriptRoot "$_.v"}
Push-Location $workDir
try {
 & (Join-Path $VivadoBin 'xvlog.bat') @sources
 if($LASTEXITCODE -ne 0){throw 'RTL compile failed'}
 "run all`nquit`n" | Set-Content run.tcl
 foreach($test in $Tests){
   & (Join-Path $VivadoBin 'xelab.bat') $test -s $test -timescale 1ns/1ps
   if($LASTEXITCODE -ne 0){throw "Elaboration failed: $test"}
   & (Join-Path $VivadoBin 'xsim.bat') $test -tclbatch run.tcl -log "$test.log"
   if($LASTEXITCODE -ne 0 -or !(Select-String -Path "$test.log" -Pattern ($test.ToUpper()+'_PASS') -Quiet)){throw "Simulation failed: $test"}
 }
}finally{Pop-Location}
