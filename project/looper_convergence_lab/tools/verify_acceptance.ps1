$ErrorActionPreference = 'Stop'
$acceptanceManifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
foreach ($imageRecord in $acceptanceManifest.files) {
    if ($imageRecord.file -notmatch '^[A-Za-z0-9_.-]+\.fs$') { throw 'Invalid package filename' }
    $imagePath = Join-Path $PSScriptRoot $imageRecord.file
    $imageDigest = (Get-FileHash -LiteralPath $imagePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($imageDigest -ne $imageRecord.sha256) { throw "Hash mismatch: $imagePath" }
    Write-Output "PASS $($imageRecord.file) / $($imageRecord.top) / SRAM"
}
foreach ($audioRecord in $acceptanceManifest.reference_audio) {
    if ($audioRecord.file -notmatch '^reference_audio/[A-Za-z0-9_-]+\.wav$') { throw 'Invalid audio filename' }
    $audioPath = Join-Path $PSScriptRoot $audioRecord.file
    $audioDigest = (Get-FileHash -LiteralPath $audioPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($audioDigest -ne $audioRecord.sha256) { throw "Hash mismatch: $audioPath" }
    Write-Output "PASS $($audioRecord.file) / RTL reference"
}
Write-Output 'ALL_PACKAGE_IMAGES_VERIFIED'
