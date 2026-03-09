-- Step 11: Automated quality checks (from QUALITY_CHECKS.md)
-- Run with \set ON_ERROR_STOP on - fails pipeline on first violation
-- Integrate as final step in run_all.ps1

\set ON_ERROR_STOP on

DO $$
DECLARE
    cnt BIGINT;
    r RECORD;
BEGIN
    -- 1. Row count: pn2009_2023 (allow 100k-2M for different dataset versions)
    SELECT COUNT(*) INTO cnt FROM staging_raw.pn2009_2023;
    IF cnt < 100000 OR cnt > 2000000 THEN
        RAISE EXCEPTION 'QC1: pn2009_2023 row count % outside expected 100k-2M', cnt;
    END IF;

    -- 2. Uniqueness: (accident_id_source, person_seq_source) in staging.accident_person
    -- Note: Source data may have duplicates; ETL uses DISTINCT ON to deduplicate. Warn only.
    SELECT COUNT(*) - COUNT(DISTINCT (accident_id_source, person_seq_source)) INTO cnt
    FROM staging.accident_person;
    IF cnt > 0 THEN
        RAISE NOTICE 'QC2: % duplicate (accident_id_source, person_seq_source) in staging.accident_person (ETL deduplicates)', cnt;
    END IF;

    -- 3. Uniqueness: source_accident_id in core.accident
    SELECT COUNT(*) - COUNT(DISTINCT source_accident_id) INTO cnt FROM core.accident;
    IF cnt <> 0 THEN
        RAISE EXCEPTION 'QC3: Duplicate source_accident_id in core.accident. Violations: %', cnt;
    END IF;

    -- 4. Referential integrity: no orphan municipality_id
    SELECT COUNT(*) INTO cnt
    FROM core.accident a
    LEFT JOIN core.dim_municipality m ON a.municipality_id = m.municipality_id
    WHERE a.municipality_id IS NOT NULL AND m.municipality_id IS NULL;
    IF cnt > 0 THEN
        RAISE EXCEPTION 'QC4: Orphan municipality_id in core.accident. Count: %', cnt;
    END IF;

    -- 5. Referential integrity: no orphan date_id
    SELECT COUNT(*) INTO cnt
    FROM core.accident a
    LEFT JOIN core.dim_date d ON a.date_id = d.date_id
    WHERE a.date_id IS NOT NULL AND d.date_id IS NULL;
    IF cnt > 0 THEN
        RAISE EXCEPTION 'QC5: Orphan date_id in core.accident. Count: %', cnt;
    END IF;

    -- 6. Referential integrity: no orphan time_id (allow some NULL time_id for unparseable times)
    SELECT COUNT(*) INTO cnt
    FROM core.accident a
    LEFT JOIN core.dim_time t ON a.time_id = t.time_id
    WHERE a.time_id IS NOT NULL AND t.time_id IS NULL;
    IF cnt > 0 THEN
        RAISE EXCEPTION 'QC6: Orphan time_id in core.accident. Count: %', cnt;
    END IF;

    -- 7. Date range: 2009-01-01 to 2023-12-31
    SELECT COUNT(*) INTO cnt
    FROM core.accident
    WHERE accident_date < '2009-01-01' OR accident_date > '2023-12-31';
    IF cnt > 0 THEN
        RAISE EXCEPTION 'QC7: Accident dates outside 2009-2023. Count: %', cnt;
    END IF;

    -- 8. Geometry within Slovenia bbox (13-17 lon, 45-47 lat) - warn only; some coords may be invalid
    SELECT COUNT(*) INTO cnt
    FROM core.accident
    WHERE geom IS NOT NULL
      AND (ST_X(geom) NOT BETWEEN 13 AND 17 OR ST_Y(geom) NOT BETWEEN 45 AND 47);
    IF cnt > 0 THEN
        RAISE NOTICE 'QC8: % accident points outside Slovenia bbox (13-17 lon, 45-47 lat)', cnt;
    END IF;

    -- 9. Municipality-year stats uniqueness
    SELECT COUNT(*) INTO cnt
    FROM (
        SELECT municipality_id, year, COUNT(*) AS c
        FROM core.municipality_year_stats
        GROUP BY municipality_id, year
        HAVING COUNT(*) > 1
    ) x;
    IF cnt > 0 THEN
        RAISE EXCEPTION 'QC9: Duplicate (municipality_id, year) in core.municipality_year_stats';
    END IF;

    -- 10. dim_municipality unique names
    SELECT COUNT(*) INTO cnt
    FROM (
        SELECT LOWER(name_sl), COUNT(*)
        FROM core.dim_municipality
        GROUP BY LOWER(name_sl)
        HAVING COUNT(*) > 1
    ) x;
    IF cnt > 0 THEN
        RAISE EXCEPTION 'QC10: Duplicate LOWER(name_sl) in core.dim_municipality';
    END IF;

    RAISE NOTICE 'All quality checks passed.';
END $$;
