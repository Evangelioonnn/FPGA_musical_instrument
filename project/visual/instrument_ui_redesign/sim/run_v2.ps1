param([string]$VivadoBin='D:\Xilinx\Vivado\2018.3\bin',
      [string[]]$Tests=@('av_units_tb','av_video_tb','tmds_pipeline_tb'))
$ErrorActionPreference='Stop'
$projectDir=Split-Path $PSScriptRoot -Parent
$repoDir=(Resolve-Path (Join-Path $projectDir '../../..')).Path
$workDir=Join-Path $projectDir 'impl/sim_v2'
New-Item -ItemType Directory -Force $workDir | Out-Null
$reference=Get-Content (Join-Path $repoDir 'project/visual/dvi_colorbar_probe/src/rtl/dvi-tx/dvi_tx_tmds_enc.v') -Raw
[IO.File]::WriteAllText((Join-Path $workDir 'reference_tmds_enc.v'),$reference.Replace('module dvi_tx_tmds_enc','module reference_tmds_enc'))
[IO.File]::WriteAllText((Join-Path $workDir 'run.tcl'),"run all`nquit`n")
$sources=@('av_frame_ram','av_timing','av_page_writer','av_font','av_labels','av_renderer','dvi_tx_tmds_enc') | ForEach-Object {Join-Path $projectDir "src/rtl/$_.v"}
$sources+=Join-Path $workDir 'reference_tmds_enc.v'
$sources+=@('av_units_tb','av_video_tb','tmds_pipeline_tb') | ForEach-Object {Join-Path $PSScriptRoot "$_.v"}
Push-Location $workDir
try {
 & (Join-Path $VivadoBin 'xvlog.bat') @sources
 if($LASTEXITCODE -ne 0){throw 'RTL compilation failed'}
 foreach($test in $Tests){
  & (Join-Path $VivadoBin 'xelab.bat') $test -s $test -timescale 1ns/1ps
  if($LASTEXITCODE -ne 0){throw "Elaboration failed: $test"}
  & (Join-Path $VivadoBin 'xsim.bat') $test -tclbatch run.tcl -log "$test.log"
  if($LASTEXITCODE -ne 0 -or !(Select-String -Path "$test.log" -Pattern ($test.ToUpper()+'_PASS') -Quiet)){throw "Simulation failed: $test"}
 }
}finally{Pop-Location}
