$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$targets = @(
  'cylonai.cn_nginx.zip',
  'api.cylonai.cn_nginx.zip',
  'file.cylonai.cn_nginx.zip'
)

$stage = Join-Path $root '.ssl-stage-all'
if (Test-Path $stage) {
  Remove-Item $stage -Recurse -Force
}
New-Item -ItemType Directory -Force $stage | Out-Null

foreach ($zipName in $targets) {
  $zipPath = Join-Path $root $zipName
  $folderName = [System.IO.Path]::GetFileNameWithoutExtension($zipName)
  $dest = Join-Path $stage $folderName
  Expand-Archive -Path $zipPath -DestinationPath $dest -Force
}

Get-ChildItem $stage -Recurse -Force |
  Select-Object FullName, Length |
  Format-Table -AutoSize
