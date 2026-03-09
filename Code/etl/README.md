# ETL Pipeline (NEXT_STEPS.md Phase 1 + plan extensions)

Run the full pipeline:

```powershell
.\Code\etl\run_all.ps1
```

Or run steps individually (from project root):

0. `db/init/02_etl_extensions.sql` – etl schema, load_batch, municipality_name_mapping
1. `01_parse_holidays.sql` – raw → staging.holiday
2. `02_dim_date_holiday.sql` – core.dim_holiday, core.dim_date
3. `03_dim_time.sql` – core.dim_time
4. `04_dim_municipality.sql` – core.dim_municipality (from SURS)
5. `05_parse_accidents.py` – raw → staging.accident_person (requires Docker)
9. `09_municipality_mapping.sql` – core.municipality_name_mapping (run before step 6)
6. `06_build_core_accident.sql` – core.accident, core.accident_person
7. `07_parse_surs.sql` – SURS raw → staging.municipality_year_indicator_long
8. `08_municipality_stats.sql` – core.municipality_year_stats
10. `10_views.sql` – enriched views, analytics views, indexes
11. `11_quality_checks.sql` – automated quality checks

**Prerequisites:** Docker running, `db/` containers up (`docker compose -f db/docker-compose.yml up -d`).
