## Data quality checks

### 1. Row counts and completeness

- **CSV → staging_raw**:
  - After each `COPY` into `staging_raw.*`, verify row counts against expectations from inventory:
    - `SELECT COUNT(*) FROM staging_raw.pn2009_2023;` ≈ 522 385
    - `SELECT COUNT(*) FROM staging_raw.seznampraznikovindelaprostihdni20002030;` ≈ 573
    - Similar checks for each SURS table.
- **staging_raw → staging parsed**:
  - Number of parsed data rows should match number of *data* lines (excluding metadata/footer) in raw:
    - Example:  
      `SELECT COUNT(*) FROM staging.accident_person;`  
      should be close to `COUNT(*) FROM staging_raw.pn2009_2023` minus header/footer lines.

### 2. Uniqueness and key integrity

- **Accident natural keys**:
  - Check uniqueness of accident-person combination:
    - `SELECT COUNT(*) - COUNT(DISTINCT (accident_id_source, person_seq_source)) FROM staging.accident_person;` → should be 0.
  - After building `core.accident`:
    - `SELECT COUNT(*) - COUNT(DISTINCT source_accident_id) FROM core.accident;` → should be 0.
- **Municipality dimension**:
  - Ensure unique SURS codes and names:
    - `SELECT surs_municipality_code, COUNT(*) FROM core.dim_municipality GROUP BY 1 HAVING COUNT(*) > 1;`
    - `SELECT LOWER(name_sl), COUNT(*) FROM core.dim_municipality GROUP BY 1 HAVING COUNT(*) > 1;`
- **Municipality-year stats**:
  - `SELECT municipality_id, year, COUNT(*) FROM core.municipality_year_stats GROUP BY 1,2 HAVING COUNT(*) > 1;` → expect none.

### 3. Referential integrity

- **Accident → municipality**:
  - Orphan check:
    - `SELECT COUNT(*) FROM core.accident a LEFT JOIN core.dim_municipality m ON a.municipality_id = m.municipality_id WHERE a.municipality_id IS NOT NULL AND m.municipality_id IS NULL;`
- **Accident → date / time**:
  - `SELECT COUNT(*) FROM core.accident WHERE date_id IS NULL OR time_id IS NULL;`  
    - Expect 0 (or very low, if some times unparseable; track separately).
- **Accident → holiday**:
  - Accident rows with non-null `holiday_id` must have matching entry:
    - enforced by FK; additionally, check share of accidents on holidays vs all:
      - `SELECT COUNT(*) FILTER (WHERE holiday_id IS NOT NULL) * 1.0 / COUNT(*) FROM core.accident;`
- **Accident → demographics**:
  - When joining accidents to `core.municipality_year_stats`, measure coverage:
    - `SELECT COUNT(*) AS accidents, COUNT(stats.*) AS accidents_with_stats FROM core.accident a LEFT JOIN core.municipality_year_stats s ON (a.municipality_id = s.municipality_id AND a.year = s.year);`

### 4. Null rates and missingness

- **Coordinates**:
  - `SELECT COUNT(*) AS total, COUNT(*) FILTER (WHERE x_coord_raw IS NULL OR y_coord_raw IS NULL OR x_coord_raw = 0 OR y_coord_raw = 0) AS invalid_coords FROM core.accident;`
  - Track percentage of accidents requiring non-spatial fallback to municipality mapping.
- **Key analytical dimensions**:
  - Severity, cause, type, weather, road conditions:
    - Example:
      - `SELECT 'cause' AS field, COUNT(*) FILTER (WHERE cause IS NULL OR cause = '') * 1.0 / COUNT(*) AS null_rate FROM core.accident;`
      - Repeat for `classification`, `weather_raw`, `road_surface_condition`, etc.
- **Demographic indicators**:
  - For each metric in `core.municipality_year_stats`, compute null share:
    - `SELECT year, COUNT(*) FILTER (WHERE population_total IS NULL) AS missing_pop, COUNT(*) AS total FROM core.municipality_year_stats GROUP BY year ORDER BY year;`

### 5. Value range and plausibility checks

- **Dates and times**:
  - Accident dates:
    - `SELECT MIN(accident_date), MAX(accident_date) FROM core.accident;`  
      - Expected range: 2009-01-01 to 2023-12-31 (per project scope).  
      - Flag any dates outside this interval.
  - Times:
    - Check parsing logic does not produce invalid times:
      - `SELECT COUNT(*) FROM core.accident WHERE accident_time IS NULL;` (after parsing).
- **Ages**:
  - Reasonable range (e.g. 0–100):
    - `SELECT MIN(age_years), MAX(age_years) FROM core.accident_person;`
    - Investigate ages < 0, > 100.
- **Alcohol values**:
  - After normalization:
    - `SELECT MIN(breath_test_value), MAX(breath_test_value) FROM core.accident_person;`
    - Flag values outside a plausible range (e.g. 0–4 ‰).
- **Geometry sanity**:
  - Ensure accident points fall within Slovenia’s bounding box (in 4326):
    - `SELECT COUNT(*) FROM core.accident WHERE ST_X(geom) NOT BETWEEN 13 AND 17 OR ST_Y(geom) NOT BETWEEN 45 AND 47;`

### 6. Join coverage / match rates

- **Accidents → municipalities**:
  - `SELECT COUNT(*) FILTER (WHERE municipality_id IS NULL) * 1.0 / COUNT(*) AS share_without_municipality FROM core.accident;`
  - Aim for near 0%; any non-zero should be investigated (likely coordinate or geometry issues).
- **Accidents → demographics**:
  - `SELECT COUNT(*) FILTER (WHERE s.municipality_id IS NULL) * 1.0 / COUNT(*) AS share_without_stats FROM core.accident a LEFT JOIN core.municipality_year_stats s ON (a.municipality_id = s.municipality_id AND a.year = s.year);`
- **Accidents → holidays**:
  - `SELECT COUNT(*) FILTER (WHERE holiday_id IS NOT NULL) AS on_holiday, COUNT(*) AS total FROM core.accident;`
  - Use as a basic sense-check (should be small fraction but non-zero).

### 7. Outlier and distribution checks

- **Accident counts over time**:
  - Yearly:
    - `SELECT year, COUNT(*) AS accidents FROM core.accident GROUP BY year ORDER BY year;`
    - Look for sudden drops/spikes inconsistent with known trends (e.g. COVID-19 dip around 2020).
  - By month / weekday:
    - `SELECT EXTRACT(MONTH FROM accident_date) AS month, COUNT(*) FROM core.accident GROUP BY month ORDER BY month;`
    - `SELECT day_of_week_name, COUNT(*) FROM core.dim_date d JOIN core.accident a ON a.date_id = d.date_id GROUP BY day_of_week_name;`
- **Spatial hotspots sanity**:
  - Quick check that some clusters exist but not all points collapsed:
    - `SELECT municipality_id, COUNT(*) AS accidents FROM core.accident GROUP BY municipality_id ORDER BY accidents DESC LIMIT 10;`
- **Indicator distributions**:
  - Compare per-capita accident rates vs population:
    - `SELECT s.year, m.name_sl, COUNT(a.*) AS accidents, s.population_total, COUNT(a.*)::NUMERIC / NULLIF(s.population_total,0) AS accidents_per_capita FROM core.accident a JOIN core.municipality_year_stats s ON (a.municipality_id = s.municipality_id AND a.year = s.year) JOIN core.dim_municipality m ON m.municipality_id = s.municipality_id LIMIT 100;`

### 8. Auditability and lineage

- **Raw → parsed traceability**:
  - Every row in `staging.accident_person` should be traceable back to `staging_raw.pn2009_2023.id` via a technical key in ETL metadata (e.g. `source_row_id` column).  
  - **TODO:** extend staging tables with `source_row_id` and `load_batch_id` to allow replay and debugging.
- **No destructive updates in core**:
  - Design ETL as **insert-only** into core, with:
    - separate “refresh” strategies (truncate-reload by year, or slowly changing dimensions) clearly documented.

### 9. Validation of derived geometry joins

- **Accident → municipality spatial join quality**:
  - After assigning municipalities by geometry, cross-check with administrative unit name:
    - `SELECT a.admin_unit_name, m.name_sl, COUNT(*) FROM core.accident a LEFT JOIN core.dim_municipality m ON a.municipality_id = m.municipality_id GROUP BY a.admin_unit_name, m.name_sl ORDER BY COUNT(*) DESC;`
  - Investigate cases where `admin_unit_name` and `m.name_sl` are systematically misaligned.

### 10. Reconciliation between related indicators

- **Population vs male + female**:
  - `SELECT year, municipality_id, population_total, population_male + population_female AS sum_sex FROM core.municipality_year_stats WHERE population_total IS NOT NULL AND population_male IS NOT NULL AND population_female IS NOT NULL AND population_total <> population_male + population_female;`
- **Density vs population / area**:
  - `SELECT year, municipality_id FROM core.municipality_year_stats WHERE population_density_per_km2 IS NOT NULL AND area_km2 IS NOT NULL AND population_total IS NOT NULL AND ABS(population_density_per_km2 - population_total::NUMERIC / NULLIF(area_km2,0)) > 1;`
  - Large discrepancies indicate either unit issues or mismatched reference dates.

**Note**: These checks are intended as a starting suite; they should be automated as part of the ETL pipeline (e.g. in a dbt test suite or custom SQL harness) and extended as new data sources (especially weather) are integrated.

