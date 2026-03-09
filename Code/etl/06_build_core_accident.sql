-- Step 6: Build core.accident and core.accident_person from staging.accident_person
-- Parse accident_time_raw (H.MM) to TIME, clean alcohol values, link to dim_date/dim_time/dim_holiday/municipality

-- Helper: parse alcohol from ",77" or "1,56" to numeric
CREATE OR REPLACE FUNCTION staging.parse_alcohol(val TEXT) RETURNS NUMERIC AS $$
BEGIN
    IF val IS NULL OR TRIM(val) IN ('', '-', '...') THEN
        RETURN NULL;
    END IF;
    RETURN NULLIF(TRIM(REPLACE(TRIM(BOTH '"' FROM val), ',', '.'))::NUMERIC, 0);
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Helper: parse UraPN (3.45 = 03:45, 21.39 = 21:39) - H.MM means hours.minutes
CREATE OR REPLACE FUNCTION staging.parse_ura_pn(val TEXT) RETURNS TIME AS $$
DECLARE
    parts TEXT[];
    h INT;
    m INT;
BEGIN
    IF val IS NULL OR TRIM(val) = '' THEN
        RETURN NULL;
    END IF;
    parts := string_to_array(TRIM(val), '.');
    h := COALESCE(NULLIF(parts[1], '')::INTEGER, 0);
    m := CASE WHEN array_length(parts, 1) >= 2 THEN COALESCE(NULLIF(parts[2], '')::INTEGER, 0) ELSE 0 END;
    IF h < 0 OR h > 23 OR m < 0 OR m > 59 THEN
        RETURN NULL;
    END IF;
    RETURN make_time(h, m, 0);
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 6.1 Build core.accident (one row per accident, take first participant's attributes)
TRUNCATE core.accident_person CASCADE;
TRUNCATE core.accident CASCADE;

INSERT INTO core.accident (
    source_accident_id,
    classification,
    admin_unit_name,
    accident_date,
    accident_time,
    date_id,
    time_id,
    in_settlement_flag,
    location_context,
    road_type,
    road_code,
    road_name,
    road_section_code,
    road_section_name,
    stationing,
    cause,
    type,
    weather_raw,
    traffic_flow,
    road_surface_condition,
    road_surface_type,
    x_coord_raw,
    y_coord_raw,
    geom,
    municipality_id,
    holiday_id,
    year
)
SELECT DISTINCT ON (accident_id_source)
    accident_id_source AS source_accident_id,
    s.classification,
    s.admin_unit_name,
    s.accident_date_raw::DATE AS accident_date,
    staging.parse_ura_pn(s.accident_time_raw) AS accident_time,
    TO_CHAR(s.accident_date_raw::DATE, 'YYYYMMDD')::INTEGER AS date_id,
    (SELECT time_id FROM core.dim_time
     WHERE time_of_day = staging.parse_ura_pn(s.accident_time_raw)
     LIMIT 1) AS time_id,
    CASE WHEN UPPER(TRIM(s.in_settlement_flag_raw)) = 'DA' THEN TRUE
         WHEN UPPER(TRIM(s.in_settlement_flag_raw)) = 'NE' THEN FALSE
         ELSE NULL END AS in_settlement_flag,
    s.location AS location_context,
    s.road_type,
    s.road_code,
    s.road_name,
    s.road_section_code,
    s.road_section_name,
    s.stationing_raw AS stationing,
    s.cause_raw AS cause,
    s.type_raw AS type,
    s.weather_raw,
    s.traffic_flow_raw AS traffic_flow,
    s.road_surface_condition_raw AS road_surface_condition,
    s.road_surface_type_raw AS road_surface_type,
    s.x_coord_raw,
    s.y_coord_raw,
    CASE WHEN s.x_coord_raw IS NOT NULL AND s.y_coord_raw IS NOT NULL
          AND s.x_coord_raw <> 0 AND s.y_coord_raw <> 0
         THEN ST_Transform(ST_SetSRID(ST_MakePoint(s.x_coord_raw, s.y_coord_raw), 3794), 4326)
         ELSE NULL END AS geom,
    m.municipality_id,
    h.holiday_id,
    s.year_raw AS year
FROM staging.accident_person s
LEFT JOIN core.municipality_name_mapping mm ON mm.admin_unit_name = s.admin_unit_name
LEFT JOIN core.dim_municipality m ON m.municipality_id = mm.municipality_id
    OR (mm.admin_unit_name IS NULL AND LOWER(TRIM(m.name_sl)) = LOWER(TRIM(s.admin_unit_name)))
LEFT JOIN core.dim_holiday h ON h.holiday_date = s.accident_date_raw::DATE
WHERE s.accident_date_raw ~ '^\d{4}-\d{2}-\d{2}$'  -- skip header/invalid rows
ORDER BY s.accident_id_source, s.person_seq_source;

-- 6.2 Build core.accident_person (one row per participant, deduplicate on natural key)
INSERT INTO core.accident_person (
    accident_id,
    person_seq,
    role_in_event,
    age_years,
    sex,
    residence_admin_unit,
    nationality,
    injury_severity,
    participant_type,
    seat_belt_used,
    driving_experience_years,
    driving_experience_months,
    breath_test_value,
    blood_alcohol_value
)
SELECT DISTINCT ON (a.accident_id, s.person_seq_source)
    a.accident_id,
    s.person_seq_source AS person_seq,
    s.role_in_event_raw AS role_in_event,
    s.age_years,
    s.sex_raw AS sex,
    s.residence_admin_unit,
    s.nationality,
    s.injury_severity_raw AS injury_severity,
    s.participant_type_raw AS participant_type,
    CASE WHEN UPPER(TRIM(s.seat_belt_used_raw)) = 'DA' THEN TRUE
         WHEN UPPER(TRIM(s.seat_belt_used_raw)) = 'NE' THEN FALSE
         ELSE NULL END AS seat_belt_used,
    s.driving_experience_years,
    s.driving_experience_months,
    staging.parse_alcohol(s.breath_test_raw) AS breath_test_value,
    staging.parse_alcohol(s.blood_alcohol_raw) AS blood_alcohol_value
FROM staging.accident_person s
JOIN core.accident a ON a.source_accident_id = s.accident_id_source
WHERE s.accident_date_raw ~ '^\d{4}-\d{2}-\d{2}$'
ORDER BY a.accident_id, s.person_seq_source, s.age_years NULLS LAST;
