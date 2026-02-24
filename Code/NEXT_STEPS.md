## ETL implementation roadmap

### 1. Foundations and environment
- **Set up database**:
  - Create PostgreSQL database with PostGIS enabled.
  - Apply `POSTGRES_SCHEMA_PLAN.sql` to create schemas and core tables.
- **Decide tooling**:
  - Choose ETL framework (e.g. pure SQL + Python scripts, or dbt for transformations).
  - Configure connections, secrets management, and version control for SQL/Python code.

### 2. Ingest raw CSVs into `staging_raw`
- **Implement load scripts** (idempotent):
  - For each CSV in `Dataset/`, `COPY` (or `\copy`) entire file into its corresponding `staging_raw.*` table (`raw_line`).
  - Record load metadata (batch id, timestamp) in a small control table (TODO).
- **Validate row counts** using queries from `QUALITY_CHECKS.md`.

### 3. Parse accidents file into typed staging
- **Parse header and columns**:
  - Split `raw_line` for `pn2009_2023` on commas, respecting quoted fields.
  - Map to columns specified in `staging.accident_person`.
- **Normalize basic types**:
  - Parse `DatumPN` to `DATE` (store as `accident_date_raw` plus derived date).
  - Store `UraPN` as raw text for now; add derived parsed time column later.
  - Cast numeric-looking fields (`GeoKoordinataX/Y`, ages, years) to numeric/integer where safe.
  - Clean localized numeric fields (`"1,56"`, `",00"`) into normalized `NUMERIC`.
- **Basic sanity checks**:
  - Verify uniqueness of (`accident_id_source`, `person_seq_source`).
  - Check date range and coordinate coverage.

### 4. Build core accident and accident_person tables
- **Derive accident-level fact**:
  - Aggregate over `staging.accident_person` by `accident_id_source`:
    - Choose representative row for location/road attributes (they are constant within an accident).
    - Deduplicate and insert into `core.accident`.
  - Parse `accident_time_raw` into `TIME`, handling `H.MM` and `HH.MM` formats.
  - Populate `year` from `accident_date`.
- **Populate participant fact**:
  - Insert one row per participant into `core.accident_person`, linking to `core.accident` via `source_accident_id`.
  - Normalize booleans (seat belt usage), alcohol values, and map codes to canonical labels where needed.

### 5. Date and holiday dimensions
- **Generate `core.dim_date`**:
  - Populate for full range 2000-01-01 – 2030-12-31.
  - Derive calendar attributes (year, month, day, week, weekday, weekend flag).
- **Parse holidays**:
  - Load `staging.holiday` from `staging_raw.seznampraznikovindelaprostihdni20002030`.
  - Convert `raw_date_text` to `DATE`, trim `'ne '` to `'ne'`.
  - Insert into `core.dim_holiday`.
- **Link dates to holidays**:
  - Update `core.dim_date.holiday_id` where `full_date = core.dim_holiday.holiday_date`.
  - Later, propagate `holiday_id` into `core.accident` via `dim_date`.

### 6. Municipality reference and geometry
- **Create `core.dim_municipality`**:
  - Import official municipality list (names + SURS codes) from external SURS/SiStat reference (not in current `Dataset/`).
  - Normalize naming to match SI-STAT exports (trim, case-fold, unify bilingual forms).
- **Import geometry**:
  - Load municipality polygons from official shapefile (e.g. GURS).
  - Assign consistent SRID (e.g. 3794 or 4326) and store as `geom`.
- **Reconcile with SI-STAT tables**:
  - Test joins between `dim_municipality.name_sl` and municipality names in SURS CSVs.
  - Build a mapping table for any discrepant names.

### 7. Demographic and contextual indicators
- **Parse SURS wide tables into staging**:
  - For each file (`st_prebivalcev`, `st_moskih`, `st_zensk`, `gostota_poseljenosti`, `povrsina_obcine`, `st_avtomobilov`, `st_stanovanj`, `povp_povrsina_stanovanj`, `st_sol`, `st_vrtcev`, `starost_prebivalcev`, `stopnja_delovne_aktivnosti`):
    - Skip metadata header/footer lines.
    - Split lines into `measure_label`, `municipality_name`, year columns.
    - Insert into corresponding `staging.*_wide` tables.
- **Unpivot to long form**:
  - For each wide table, transform into `staging.municipality_year_indicator_long`:
    - One row per (`municipality_name`, `year`, `indicator_code`, `value_numeric`).
    - Use consistent indicator codes across datasets.
- **Load core municipality stats**:
  - Join long indicators to `core.dim_municipality` using normalized names/codes.
  - Pivot into `core.municipality_year_stats` for key metrics (population, density, area, cars, etc.).
  - Optionally populate `core.municipality_indicator_long` for full indicator coverage.

### 8. Spatial enrichment and accident–municipality linkage
- **Build accident geometries**:
  - Convert `x_coord_raw`, `y_coord_raw` to `geometry(Point, <SRID_raw>)`, then `ST_Transform` to 4326.
  - Store raw coordinates plus transformed `geom` in `core.accident`.
- **Spatial join to municipalities**:
  - Use `ST_Within`/`ST_Contains` to assign `municipality_id` for valid points.
  - Implement tolerance-based fallback (`ST_DWithin`) for near-border cases.
  - For accidents with invalid coordinates, implement name-based fallback using `admin_unit_name` and mapping table.
- **Evaluate coverage**:
  - Compute % of accidents with assigned municipality and log unresolved cases for manual review.

### 9. Weather integration (future phase)
- **Acquire and stage weather data**:
  - Identify ARSO (or other) datasets: station metadata + time series (hourly/daily).
  - Create `staging_raw.weather_*` tables and corresponding parsed staging tables.
- **Build weather core tables**:
  - Populate `core.dim_weather_station` with geometry.
  - Populate `core.weather_observation` with time series.
- **Implement nearest-station matching**:
  - For each accident, find nearest station within radius; choose closest observation in time.
  - Store resulting `weather_observation_id` in `core.accident`.

### 10. Derived views and analytics layer
- **Create enriched views**:
  - `core.v_accident_enriched`:
    - Join `core.accident` with:
      - `core.accident_person` (aggregated participant stats),
      - `core.dim_date` and `core.dim_holiday`,
      - `core.dim_municipality` and `core.municipality_year_stats`.
  - Optional: `core.v_municipality_year_summary` with accident counts, rates per capita, etc.
- **Index tuning**:
  - Add B-tree indexes on:
    - `core.accident (year)`, `(classification)`, `(cause)`
    - `core.municipality_year_stats (year)`, `(population_density_per_km2)`
  - Verify GiST indexes exist on geometry columns.

### 11. Automated quality checks and tests
- **Implement SQL tests**:
  - Turn queries from `QUALITY_CHECKS.md` into automated checks (dbt tests, or stored SQL scripts).
  - Run tests after each ETL run; fail the pipeline on critical issues (e.g. key violations, extreme null rates).
- **Data drift monitoring**:
  - Track yearly accident counts, severity distributions, and join coverage over time.
  - Set thresholds/alerts for unexpected shifts (e.g. sudden drop in joinable municipalities).

### 12. What to do first vs later

- **Phase 1 – Must have (for descriptive & spatial analysis)**:
  - Implement schemas and raw loading for all CSVs.
  - Parse accidents into `staging.accident_person` and populate `core.accident` + `core.accident_person`.
  - Build `core.dim_date`, `core.dim_holiday`, and link accidents to holidays.
  - Build `core.dim_municipality` (without geometry at first) and basic `core.municipality_year_stats` (population, area, density).
  - Implement spatial join once municipality geometries are available.

- **Phase 2 – Enrichment (demographics & infra)**:
  - Fully parse SURS CSVs; unpivot and load demographic/socio-economic indicators.
  - Finalize `core.municipality_year_stats` and `core.municipality_indicator_long`.
  - Add age structure, employment rate, schools, kindergartens, cars, dwellings.

- **Phase 3 – Advanced spatial & weather context**:
  - Add settlement-level density and `core.dim_settlement`.
  - Integrate weather station data and `core.weather_observation`.
  - Refine hotspot analysis using high-resolution population/contextual data.

- **Phase 4 – Predictive modeling support**:
  - Create modeling-ready views/tables for Python (e.g. accident-level feature matrix).
  - Include lagged indicators, rolling statistics, and engineered features (time of day, seasonality, etc.).

