# Load CSVs into staging_raw
# Run from project root (parent of db/)

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path "$projectRoot\Dataset")) {
    Write-Error "Dataset folder not found at $projectRoot\Dataset"
    exit 1
}

Write-Host "Loading CSV files into staging_raw..." -ForegroundColor Cyan
Get-Content "$projectRoot\db\scripts\load_raw.sql" | docker exec -i postgres_db psql -U diplomska -d diplomska
if ($LASTEXITCODE -eq 0) { Write-Host "Load complete." -ForegroundColor Green } else { exit 1 }
