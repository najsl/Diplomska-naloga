# Run full ETL pipeline (NEXT_STEPS.md Phase 1 + plan extensions)
# Execute from project root. Requires: Docker running, psycopg2 (pip install psycopg2-binary)

$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot | Split-Path -Parent | Split-Path -Parent

Write-Host "=== ETL Pipeline ===" -ForegroundColor Cyan

# 0. Apply schema extensions (etl schema, load_batch, municipality_name_mapping)
Write-Host "0. Apply schema extensions..." -ForegroundColor Yellow
Get-Content "$projectRoot\db\init\02_etl_extensions.sql" | docker exec -i postgres_db psql -U diplomska -d diplomska -q

# 1. Parse holidays
Write-Host "1. Parse holidays..." -ForegroundColor Yellow
Get-Content "$projectRoot\Code\etl\01_parse_holidays.sql" | docker exec -i postgres_db psql -U diplomska -d diplomska -q

# 2. Dim date + holiday
Write-Host "2. Build dim_date, dim_holiday..." -ForegroundColor Yellow
Get-Content "$projectRoot\Code\etl\02_dim_date_holiday.sql" | docker exec -i postgres_db psql -U diplomska -d diplomska -q

# 3. Dim time
Write-Host "3. Build dim_time..." -ForegroundColor Yellow
Get-Content "$projectRoot\Code\etl\03_dim_time.sql" | docker exec -i postgres_db psql -U diplomska -d diplomska -q

# 4. Dim municipality
Write-Host "4. Build dim_municipality..." -ForegroundColor Yellow
Get-Content "$projectRoot\Code\etl\04_dim_municipality.sql" | docker exec -i postgres_db psql -U diplomska -d diplomska -q

# 5. Parse accidents (Python - runs in Docker for DB connectivity)
Write-Host "5. Parse accidents..." -ForegroundColor Yellow
docker run --rm --network db_db_network -v "${projectRoot}:/app" -w /app `
  -e DB_HOST=postgres -e DB_PORT=5432 -e DB_NAME=diplomska -e DB_USER=diplomska -e DB_PASSWORD=diplomska `
  python:3.11-slim bash -c "pip install -q psycopg2-binary && python Code/etl/05_parse_accidents.py"

# 9. Municipality name mapping (must run before step 6)
Write-Host "9. Build municipality name mapping..." -ForegroundColor Yellow
Get-Content "$projectRoot\Code\etl\09_municipality_mapping.sql" | docker exec -i postgres_db psql -U diplomska -d diplomska -q

# 6. Build core accident + accident_person
Write-Host "6. Build core.accident, core.accident_person..." -ForegroundColor Yellow
Get-Content "$projectRoot\Code\etl\06_build_core_accident.sql" | docker exec -i postgres_db psql -U diplomska -d diplomska -q

# 7. Parse SURS demographics
Write-Host "7. Parse SURS demographics..." -ForegroundColor Yellow
Get-Content "$projectRoot\Code\etl\07_parse_surs.sql" | docker exec -i postgres_db psql -U diplomska -d diplomska -q

# 8. Build municipality_year_stats
Write-Host "8. Build municipality_year_stats..." -ForegroundColor Yellow
Get-Content "$projectRoot\Code\etl\08_municipality_stats.sql" | docker exec -i postgres_db psql -U diplomska -d diplomska -q

# 10. Views and indexes
Write-Host "10. Build views and indexes..." -ForegroundColor Yellow
Get-Content "$projectRoot\Code\etl\10_views.sql" | docker exec -i postgres_db psql -U diplomska -d diplomska -q

# 11. Quality checks
Write-Host "11. Run quality checks..." -ForegroundColor Yellow
Get-Content "$projectRoot\Code\etl\11_quality_checks.sql" | docker exec -i postgres_db psql -U diplomska -d diplomska -q

Write-Host "=== Done ===" -ForegroundColor Green
