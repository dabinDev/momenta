$ErrorActionPreference = 'Stop'

$stageRoot = Join-Path $PSScriptRoot '.deploy-stage'
if (Test-Path $stageRoot) {
  Remove-Item $stageRoot -Recurse -Force
}

New-Item -ItemType Directory -Force $stageRoot | Out-Null
New-Item -ItemType Directory -Force (Join-Path $stageRoot 'admin') | Out-Null

Copy-Item (Join-Path $PSScriptRoot 'backend') (Join-Path $stageRoot 'backend') -Recurse -Force
Copy-Item (Join-Path $PSScriptRoot 'elderly-video-app') (Join-Path $stageRoot 'elderly-video-app') -Recurse -Force
Copy-Item (Join-Path $PSScriptRoot 'frontend\dist\*') (Join-Path $stageRoot 'admin') -Recurse -Force

$backendRoot = Join-Path $stageRoot 'backend'
$h5Root = Join-Path $stageRoot 'elderly-video-app'

Remove-Item (Join-Path $backendRoot '.venv') -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $backendRoot 'media') -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $backendRoot '.env') -Force -ErrorAction SilentlyContinue

Get-ChildItem $backendRoot -Recurse -Directory -Force |
  Where-Object { $_.Name -eq '__pycache__' } |
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Get-ChildItem $backendRoot -Recurse -File -Force |
  Where-Object {
    $_.Extension -eq '.pyc' -or
    $_.Name -like '*.log' -or
    $_.Name -like '*.stdout.log' -or
    $_.Name -like '*.stderr.log'
  } |
  Remove-Item -Force -ErrorAction SilentlyContinue

Remove-Item (Join-Path $h5Root 'node_modules') -Recurse -Force -ErrorAction SilentlyContinue

Write-Host 'deploy stage ready:'
Get-ChildItem $stageRoot -Force | Select-Object Name, Mode
