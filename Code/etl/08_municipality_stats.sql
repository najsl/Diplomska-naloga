-- Step 8: Build core.municipality_year_stats from staging.municipality_year_indicator_long
-- Pivot indicators and join to dim_municipality

TRUNCATE core.municipality_year_stats;

INSERT INTO core.municipality_year_stats (
    municipality_id,
    year,
    population_total,
    population_male,
    population_female,
    population_density_per_km2,
    area_km2,
    num_passenger_cars,
    num_dwellings,
    avg_dwelling_area_m2,
    num_schools,
    num_kindergartens,
    share_age_0_14,
    employment_rate
)
SELECT
    m.municipality_id,
    s.year,
    MAX(CASE WHEN s.indicator_code = 'POP_TOTAL' THEN s.value_numeric END)::BIGINT AS population_total,
    MAX(CASE WHEN s.indicator_code = 'POP_MALE' THEN s.value_numeric END)::BIGINT AS population_male,
    MAX(CASE WHEN s.indicator_code = 'POP_FEMALE' THEN s.value_numeric END)::BIGINT AS population_female,
    MAX(CASE WHEN s.indicator_code = 'DENSITY' THEN s.value_numeric END) AS population_density_per_km2,
    MAX(CASE WHEN s.indicator_code = 'AREA_KM2' THEN s.value_numeric END) AS area_km2,
    MAX(CASE WHEN s.indicator_code = 'CARS' THEN s.value_numeric END)::BIGINT AS num_passenger_cars,
    MAX(CASE WHEN s.indicator_code = 'DWELLINGS' THEN s.value_numeric END)::BIGINT AS num_dwellings,
    MAX(CASE WHEN s.indicator_code = 'AVG_DWELLING_M2' THEN s.value_numeric END) AS avg_dwelling_area_m2,
    MAX(CASE WHEN s.indicator_code = 'SCHOOLS' THEN s.value_numeric END)::INTEGER AS num_schools,
    MAX(CASE WHEN s.indicator_code = 'KINDERGARTENS' THEN s.value_numeric END)::INTEGER AS num_kindergartens,
    MAX(CASE WHEN s.indicator_code = 'SHARE_AGE_0_14' THEN s.value_numeric END) AS share_age_0_14,
    MAX(CASE WHEN s.indicator_code = 'EMPLOYMENT_RATE' THEN s.value_numeric END) AS employment_rate
FROM staging.municipality_year_indicator_long s
JOIN core.dim_municipality m ON LOWER(TRIM(m.name_sl)) = LOWER(TRIM(s.municipality_name))
GROUP BY m.municipality_id, s.year;
