-- Step 10: Derived views and index tuning
-- v_accident_enriched, v_municipality_year_summary, analytics views, B-tree indexes

-- ============================================================================
-- 1. Index tuning (per NEXT_STEPS)
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_accident_year ON core.accident (year);
CREATE INDEX IF NOT EXISTS idx_accident_classification ON core.accident (classification);
CREATE INDEX IF NOT EXISTS idx_accident_cause ON core.accident (cause);
CREATE INDEX IF NOT EXISTS idx_munic_year_stats_year ON core.municipality_year_stats (year);
-- idx_munic_year_stats_density already exists; idx_accident_geom (GiST) already exists

-- ============================================================================
-- 2. v_accident_enriched – accident + aggregated participants + dimensions + stats
-- ============================================================================

CREATE OR REPLACE VIEW core.v_accident_enriched AS
SELECT
    a.accident_id,
    a.source_accident_id,
    a.classification,
    a.admin_unit_name,
    a.accident_date,
    a.accident_time,
    a.date_id,
    a.time_id,
    a.in_settlement_flag,
    a.location_context,
    a.road_type,
    a.cause,
    a.type,
    a.weather_raw,
    a.geom,
    a.municipality_id,
    a.holiday_id,
    a.year,
    d.day_of_week,
    d.day_of_week_name,
    d.is_weekend,
    h.holiday_name,
    h.is_public_holiday,
    m.name_sl AS municipality_name,
    s.population_total,
    s.population_density_per_km2,
    s.num_passenger_cars,
    p.participant_count,
    p.severity_fatal,
    p.severity_serious,
    p.severity_light,
    p.avg_age,
    p.seat_belt_used_count,
    p.seat_belt_total
FROM core.accident a
LEFT JOIN core.dim_date d ON d.date_id = a.date_id
LEFT JOIN core.dim_holiday h ON h.holiday_id = a.holiday_id
LEFT JOIN core.dim_municipality m ON m.municipality_id = a.municipality_id
LEFT JOIN core.municipality_year_stats s ON s.municipality_id = a.municipality_id AND s.year = a.year
LEFT JOIN (
    SELECT
        accident_id,
        COUNT(*) AS participant_count,
        COUNT(*) FILTER (WHERE injury_severity ILIKE '%smrt%' OR injury_severity ILIKE '%umrl%') AS severity_fatal,
        COUNT(*) FILTER (WHERE injury_severity ILIKE '%težka%' OR injury_severity ILIKE '%hudo%') AS severity_serious,
        COUNT(*) FILTER (WHERE injury_severity ILIKE '%lahka%' OR injury_severity ILIKE '%brez%') AS severity_light,
        ROUND(AVG(age_years), 1) AS avg_age,
        COUNT(*) FILTER (WHERE seat_belt_used = TRUE) AS seat_belt_used_count,
        COUNT(*) FILTER (WHERE seat_belt_used IS NOT NULL) AS seat_belt_total
    FROM core.accident_person
    GROUP BY accident_id
) p ON p.accident_id = a.accident_id;

-- ============================================================================
-- 3. v_municipality_year_summary – accidents per municipality/year, rate per capita
-- ============================================================================

CREATE OR REPLACE VIEW core.v_municipality_year_summary AS
SELECT
    m.municipality_id,
    m.name_sl AS municipality_name,
    s.year,
    s.population_total,
    s.population_density_per_km2,
    COUNT(a.accident_id) AS accident_count,
    ROUND(COUNT(a.accident_id)::NUMERIC / NULLIF(s.population_total, 0) * 1000, 2) AS accidents_per_1000_capita
FROM core.dim_municipality m
JOIN core.municipality_year_stats s ON s.municipality_id = m.municipality_id
LEFT JOIN core.accident a ON a.municipality_id = m.municipality_id AND a.year = s.year
GROUP BY m.municipality_id, m.name_sl, s.year, s.population_total, s.population_density_per_km2;

-- ============================================================================
-- 4. v_accident_trends – YoY counts, rolling 3-year average, rank by municipality
-- ============================================================================

CREATE OR REPLACE VIEW core.v_accident_trends AS
WITH yearly AS (
    SELECT
        municipality_id,
        year,
        COUNT(*) AS accident_count
    FROM core.accident
    WHERE municipality_id IS NOT NULL
    GROUP BY municipality_id, year
),
with_prev AS (
    SELECT
        y.*,
        LAG(y.accident_count) OVER (PARTITION BY municipality_id ORDER BY year) AS prev_year_count,
        AVG(y.accident_count) OVER (
            PARTITION BY municipality_id
            ORDER BY year
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_3yr_avg
    FROM yearly y
)
SELECT
    m.municipality_id,
    m.name_sl AS municipality_name,
    w.year,
    w.accident_count,
    w.prev_year_count,
    w.accident_count - w.prev_year_count AS yoy_change,
    ROUND(w.rolling_3yr_avg, 1) AS rolling_3yr_avg,
    RANK() OVER (PARTITION BY w.year ORDER BY w.accident_count DESC) AS rank_by_count
FROM with_prev w
JOIN core.dim_municipality m ON m.municipality_id = w.municipality_id;

-- ============================================================================
-- 5. v_accident_time_patterns – by hour, day of week, month
-- ============================================================================

CREATE OR REPLACE VIEW core.v_accident_time_patterns AS
SELECT
    d.year,
    d.month,
    d.day_of_week,
    d.day_of_week_name,
    t.hour,
    t.time_bucket,
    COUNT(a.accident_id) AS accident_count
FROM core.accident a
JOIN core.dim_date d ON d.date_id = a.date_id
LEFT JOIN core.dim_time t ON t.time_id = a.time_id
GROUP BY d.year, d.month, d.day_of_week, d.day_of_week_name, t.hour, t.time_bucket;

-- ============================================================================
-- 6. v_municipality_rankings – top municipalities by count, rate, density
-- ============================================================================

CREATE OR REPLACE VIEW core.v_municipality_rankings AS
WITH totals AS (
    SELECT
        municipality_id,
        SUM(accident_count) AS total_accidents,
        AVG(accidents_per_1000_capita) AS avg_rate_per_1000
    FROM core.v_municipality_year_summary
    WHERE year BETWEEN 2015 AND 2023  -- recent period
    GROUP BY municipality_id
)
SELECT
    m.municipality_id,
    m.name_sl AS municipality_name,
    s.population_density_per_km2,
    t.total_accidents,
    ROUND(t.avg_rate_per_1000, 2) AS avg_accidents_per_1000_capita,
    RANK() OVER (ORDER BY t.total_accidents DESC NULLS LAST) AS rank_by_count,
    RANK() OVER (ORDER BY t.avg_rate_per_1000 DESC NULLS LAST) AS rank_by_rate,
    RANK() OVER (ORDER BY s.population_density_per_km2 DESC NULLS LAST) AS rank_by_density
FROM core.dim_municipality m
LEFT JOIN totals t ON t.municipality_id = m.municipality_id
LEFT JOIN (
    SELECT municipality_id,
           AVG(population_density_per_km2) AS population_density_per_km2
    FROM core.municipality_year_stats
    WHERE year BETWEEN 2015 AND 2023
    GROUP BY municipality_id
) s ON s.municipality_id = m.municipality_id;
