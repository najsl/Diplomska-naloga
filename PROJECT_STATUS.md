# Project Status – Diplomska (Traffic Accident Analysis)

This document describes what is implemented, what remains to be done, and how to run and test the project.

---

## 1. What Is Already Done

### 1.1 Database and Infrastructure

| Component | Status | Description |
|-----------|--------|--------------|
| PostgreSQL + PostGIS | ✅ | Dockerized PostGIS 16-3.4 |
| Schemas | ✅ | `staging_raw`, `staging`, `core`, `etl` |
| Raw staging tables | ✅ | One table per CSV (e.g. `pn2009_2023`, `st_prebivalcev`, …) |
| Parsed staging tables | ✅ | `staging.accident_person`, `staging.holiday`, `staging.municipality_year_indicator_long` |
| Core dimensions | ✅ | `dim_date`, `dim_holiday`, `dim_time`, `dim_municipality` |
| Core fact tables | ✅ | `core.accident`, `core.accident_person`, `core.municipality_year_stats` |
| ETL extensions | ✅ | `etl.load_batch`, `core.municipality_name_mapping` |
| pgAdmin | ✅ | Optional UI for database access |

### 1.2 Data Loading

| Step | Status | Description |
|------|--------|--------------|
| Load raw CSVs | ✅ | `db/scripts/load_raw.sql` + `run_load.ps1` – COPY into `staging_raw.*` |
| Parse holidays | ✅ | `01_parse_holidays.sql` → `staging.holiday` |
| Parse accidents | ✅ | `05_parse_accidents.py` → `staging.accident_person` |
| Parse SURS demographics | ✅ | `07_parse_surs.sql` → `staging.municipality_year_indicator_long` |

### 1.3 Core ETL (Phase 1 + Phase 2)

| Step | Status | Description |
|------|--------|--------------|
| Date/holiday dimensions | ✅ | `02_dim_date_holiday.sql` – `dim_date` (2000–2030), `dim_holiday` |
| Time dimension | ✅ | `03_dim_time.sql` – 15‑minute buckets |
| Municipality dimension | ✅ | `04_dim_municipality.sql` – from SURS `st_prebivalcev` |
| Municipality name mapping | ✅ | `09_municipality_mapping.sql` – `admin_unit_name` → `municipality_id` |
| Core accident + participants | ✅ | `06_build_core_accident.sql` – geometry, date/time/holiday links, municipality via mapping |
| Municipality-year stats | ✅ | `08_municipality_stats.sql` – pivot from long indicators |

### 1.4 SURS Indicators (Phase 2)

All of the following are parsed and loaded into `core.municipality_year_stats`:

- `POP_TOTAL`, `POP_MALE`, `POP_FEMALE`
- `DENSITY`, `AREA_KM2`
- `CARS`, `DWELLINGS`, `AVG_DWELLING_M2`
- `SCHOOLS`, `KINDERGARTENS`
- `SHARE_AGE_0_14`, `EMPLOYMENT_RATE`

### 1.5 Derived Views and Indexes

| View | Status | Description |
|------|--------|-------------|
| `core.v_accident_enriched` | ✅ | Accident + aggregated participants + date/holiday/municipality + stats |
| `core.v_municipality_year_summary` | ✅ | Accidents per municipality/year, rate per 1000 capita |
| `core.v_accident_trends` | ✅ | YoY counts, rolling 3‑year average, rank by municipality |
| `core.v_accident_time_patterns` | ✅ | Accidents by hour, day of week, month |
| `core.v_municipality_rankings` | ✅ | Top municipalities by count, rate, density |
| Indexes | ✅ | `accident(year)`, `(classification)`, `(cause)`; `municipality_year_stats(year)`; GiST on `geom` |

### 1.6 Quality Checks

- `11_quality_checks.sql` – automated checks for row counts, uniqueness, referential integrity, date range, geometry bbox
- Integrated as final step in `run_all.ps1`
- Some checks emit NOTICE only (e.g. duplicate staging keys, points outside Slovenia bbox)

---

## 2. What Still Has to Be Completed

### 2.1 Deferred (Out of Scope per Plan)

| Item | Phase | Notes |
|------|-------|-------|
| Municipality geometry | – | Load polygons from GURS shapefile; `dim_municipality.geom` exists but is NULL |
| Spatial join | – | Use `ST_Within` to assign `municipality_id` from geometry instead of name mapping |
| Weather integration | Phase 3 | ARSO data, `dim_weather_station`, `weather_observation`, nearest-station matching |
| Settlement-level density | Phase 3 | `core.dim_settlement`, `Gostota poseljenosti.csv` (settlement) |
| ML feature matrices | Phase 4 | Replaced by SQL analytics views for now |

### 2.2 Optional / TODO

| Item | Description |
|------|-------------|
| `etl.load_batch` population | Table exists; ETL does not yet insert batch metadata after each step |
| `source_row_id` in staging | Traceability from `staging.accident_person` to `staging_raw.pn2009_2023.id` – deferred |
| Manual mapping overrides | Add rows to `core.municipality_name_mapping` for `admin_unit_name` values that do not auto-match |
| Data drift monitoring | Track yearly counts, severity, join coverage over time (QUALITY_CHECKS.md §11) |

### 2.3 Not Yet Implemented (NEXT_STEPS.md)

- **Step 2 TODO**: Record load metadata in `etl.load_batch` during raw load
- **Step 8**: Spatial join (blocked until municipality geometry is available)
- **Step 9 (weather)**: Phase 3
- **Step 12**: Phase 3–4 items (settlement density, weather, ML support)

---

## 3. How to Use and Test

### 3.1 Prerequisites

- **Docker Desktop** installed and running
- **PowerShell** (Windows) or compatible shell
- **Dataset folder** at project root: `Dataset/` with CSVs (see `Code/INVENTORY.md` for expected files)

### 3.2 Initial Setup

1. **Copy environment file** (if not already done):
   ```powershell
   Copy-Item .env.example .env
   # Edit .env if needed (defaults: diplomska/diplomska, port 5432)
   ```

2. **Start the database** (from project root):
   ```powershell
   docker compose -f db/docker-compose.yml up -d
   ```

3. **Verify PostGIS and schemas**:
   ```powershell
   docker exec -i postgres_db psql -U diplomska -d diplomska -c "SELECT PostGIS_Full_Version();"
   docker exec -i postgres_db psql -U diplomska -d diplomska -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('staging_raw','staging','core','etl') ORDER BY schema_name;"
   ```

### 3.3 Load Raw Data

**Important:** Raw CSVs must be loaded before running the ETL.

```powershell
.\db\scripts\run_load.ps1
```

This runs `db/scripts/load_raw.sql`, which `COPY`s CSVs from `/dataset/` (mounted from `Dataset/`) into `staging_raw.*` tables.

### 3.4 Run Full ETL Pipeline

From the project root:

```powershell
.\Code\etl\run_all.ps1
```

This executes, in order:

0. Schema extensions (`etl`, `load_batch`, `municipality_name_mapping`)
1. Parse holidays
2. Build `dim_date`, `dim_holiday`
3. Build `dim_time`
4. Build `dim_municipality`
5. Parse accidents (Python, requires Docker network)
9. Build municipality name mapping
6. Build `core.accident`, `core.accident_person`
7. Parse SURS demographics
8. Build `core.municipality_year_stats`
10. Create views and indexes
11. Run quality checks

### 3.5 Run Individual Steps

From project root:

```powershell
# Example: run only quality checks
Get-Content "Code\etl\11_quality_checks.sql" | docker exec -i postgres_db psql -U diplomska -d diplomska -q

# Example: run only views
Get-Content "Code\etl\10_views.sql" | docker exec -i postgres_db psql -U diplomska -d diplomska -q
```

See `Code/etl/README.md` for the full list of scripts and their order.

### 3.6 Query the Data

Connect via `psql` or pgAdmin and run analytical queries, for example:

```sql
-- Accident count by year
SELECT year, COUNT(*) FROM core.accident GROUP BY year ORDER BY year;

-- Top municipalities by accident count (recent years)
SELECT * FROM core.v_municipality_rankings ORDER BY rank_by_count LIMIT 20;

-- Accident trends with YoY change
SELECT municipality_name, year, accident_count, yoy_change, rolling_3yr_avg
FROM core.v_accident_trends
WHERE municipality_name = 'Ljubljana'
ORDER BY year;

-- Enriched accident sample
SELECT accident_id, accident_date, municipality_name, participant_count, severity_fatal, population_total
FROM core.v_accident_enriched
WHERE year = 2023
LIMIT 10;
```

### 3.7 pgAdmin (Optional)

```powershell
docker compose -f db/docker-compose.yml up -d postgres pgadmin
```

- URL: `http://localhost:5050` (or `${PGADMIN_PORT}`)
- Email: `admin@local.com` (or from `db/.env`)
- Password: `admin` (or from `db/.env`)
- Add server: Host `postgres`, Port `5432`, Database `diplomska`, User `diplomska`

### 3.8 Fresh Start

To reset the database and re-run everything:

```powershell
docker compose -f db/docker-compose.yml down -v
docker compose -f db/docker-compose.yml up -d
# Wait for healthcheck, then:
.\db\scripts\run_load.ps1
.\Code\etl\run_all.ps1
```

---

## 4. File Reference

| Path | Purpose |
|------|---------|
| `db/docker-compose.yml` | Postgres + pgAdmin, mounts `Dataset/` and `db/init/` |
| `db/init/01_init.sql` | Schemas, raw staging, parsed staging, core tables |
| `db/init/02_etl_extensions.sql` | `etl` schema, `load_batch`, `municipality_name_mapping` |
| `db/scripts/load_raw.sql` | COPY raw CSVs into `staging_raw.*` |
| `db/scripts/run_load.ps1` | Runs load_raw.sql |
| `Code/etl/run_all.ps1` | Full ETL pipeline (steps 0–11) |
| `Code/etl/01_parse_holidays.sql` … `11_quality_checks.sql` | Individual ETL steps |
| `Code/QUALITY_CHECKS.md` | Manual quality check queries |
| `Code/NEXT_STEPS.md` | ETL roadmap and phases |
| `Code/INVENTORY.md` | CSV inventory and column descriptions |
