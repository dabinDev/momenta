$ErrorActionPreference = 'Stop'

$zip = Join-Path $PSScriptRoot 'memovideos.cn_nginx.zip'
$out = Join-Path $PSScriptRoot '.ssl-stage'

if (Test-Path $out) {
  Remove-Item $out -Recurse -Force
}

Expand-Archive -Path $zip -DestinationPath $out -Force
Get-ChildItem $out -Recurse -Force |
  Select-Object FullName, Length |
  Format-Table -AutoSize
