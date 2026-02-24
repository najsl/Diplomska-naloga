-- Postgres / PostGIS schema plan (DDL skeleton)
-- Target: PostgreSQL + PostGIS

-- ============================================================================
-- 1. Schemas
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS staging_raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS core;

-- Enable PostGIS (run once per database)
-- TODO: run only if extension not yet installed.
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================================
-- 2. Raw staging tables (1:1 with source CSV rows)
--    - All columns kept as a single raw line for reproducibility.
--    - Parsed/typed staging tables live in schema "staging".
-- ============================================================================

-- 2.1 Accidents / participants (pn2009_2023.csv)

CREATE TABLE IF NOT EXISTS staging_raw.pn2009_2023 (
    id           BIGSERIAL PRIMARY KEY,
    raw_line     TEXT NOT NULL
    -- TODO: optional: source_file_name, load_timestamp
);

-- 2.2 Holidays (seznampraznikovindelaprostihdni20002030.csv)

CREATE TABLE IF NOT EXISTS staging_raw.seznampraznikovindelaprostihdni20002030 (
    id           BIGSERIAL PRIMARY KEY,
    raw_line     TEXT NOT NULL
);

-- 2.3 Demographic and contextual SI-STAT exports

CREATE TABLE IF NOT EXISTS staging_raw.gostota_poseljenosti_municipality (
    id           BIGSERIAL PRIMARY KEY,
    raw_line     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS staging_raw.gostota_poseljenosti_settlement (
    id           BIGSERIAL PRIMARY KEY,
    raw_line     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS staging_raw.povrsina_obcine (
    id           BIGSERIAL PRIMARY KEY,
    raw_line     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS staging_raw.st_prebivalcev (
    id           BIGSERIAL PRIMARY KEY,
    raw_line     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS staging_raw.st_moskih (
    id           BIGSERIAL PRIMARY KEY,
    raw_line     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS staging_raw.st_zensk (
    id           BIGSERIAL PRIMARY KEY,
    raw_line     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS staging_raw.st_avtomobilov (
    id           BIGSERIAL PRIMARY KEY,
    raw_line     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS staging_raw.st_stanovanj (
    id           BIGSERIAL PRIMARY KEY,
    raw_line     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS staging_raw.povp_povrsina_stanovanj (
    id           BIGSERIAL PRIMARY KEY,
    raw_line     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS staging_raw.st_sol (
    id           BIGSERIAL PRIMARY KEY,
    raw_line     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS staging_raw.st_vrtcev (
    id           BIGSERIAL PRIMARY KEY,
    raw_line     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS staging_raw.starost_prebivalcev (
    id           BIGSERIAL PRIMARY KEY,
    raw_line     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS staging_raw.stopnja_delovne_aktivnosti (
    id           BIGSERIAL PRIMARY KEY,
    raw_line     TEXT NOT NULL
);

-- ============================================================================
-- 3. Parsed staging tables (typed) – best-effort
--    - Downstream ETL will populate these from staging_raw.*
--    - These are closer to the final analytical model but still preserve
--      source-level semantics.
-- ============================================================================

-- 3.1 Accident participants (parsed from pn2009_2023.csv)

CREATE TABLE IF NOT EXISTS staging.accident_person (
    accident_id_source        INTEGER,          -- ZaporednaStevilkaPN
    classification            TEXT,             -- KlasifikacijaNesrece
    admin_unit_name           TEXT,             -- UpravnaEnotaStoritve
    accident_date_raw         TEXT,             -- DatumPN (raw string)
    accident_time_raw         TEXT,             -- UraPN (raw string)
    in_settlement_flag_raw    TEXT,             -- VNaselju
    location                  TEXT,             -- Lokacija
    road_type                 TEXT,             -- VrstaCesteNaselja
    road_code                 TEXT,             -- SifraCesteNaselja
    road_name                 TEXT,             -- TekstCesteNaselja
    road_section_code         TEXT,             -- SifraOdsekaUlice
    road_section_name         TEXT,             -- TekstOdsekaUlice
    stationing_raw            TEXT,             -- StacionazaDogodka
    place_description         TEXT,             -- OpisKraja
    cause_raw                 TEXT,             -- VzrokNesrece
    type_raw                  TEXT,             -- TipNesrece
    weather_raw               TEXT,             -- VremenskeOkoliscine
    traffic_flow_raw          TEXT,             -- StanjePrometa
    road_surface_condition_raw TEXT,           -- StanjeVozisca
    road_surface_type_raw     TEXT,             -- VrstaVozisca
    x_coord_raw               NUMERIC,          -- GeoKoordinataX
    y_coord_raw               NUMERIC,          -- GeoKoordinataY
    person_seq_source         INTEGER,          -- ZaporednaStevilkaOsebeVPN
    role_in_event_raw         TEXT,             -- Povzrocitelj
    age_years                 INTEGER,          -- Starost
    sex_raw                   TEXT,             -- Spol
    residence_admin_unit      TEXT,             -- UEStalnegaPrebivalisca
    nationality               TEXT,             -- Drzavljanstvo
    injury_severity_raw       TEXT,             -- PoskodbaUdelezenca
    participant_type_raw      TEXT,             -- VrstaUdelezenca
    seat_belt_used_raw        TEXT,             -- UporabaVarnostnegaPasu
    driving_experience_years  INTEGER,          -- VozniskiStazVLetih
    driving_experience_months INTEGER,          -- VozniskiStazVMesecih
    breath_test_raw           TEXT,             -- VrednostAlkotesta
    blood_alcohol_raw         TEXT,             -- VrednostStrokovnegaPregleda
    year_raw                  INTEGER           -- Leto
    -- TODO: add load metadata (ingestion batch id, timestamps)
);

CREATE INDEX IF NOT EXISTS idx_staging_accident_person_accident
    ON staging.accident_person (accident_id_source);

-- 3.2 Holidays (parsed)

CREATE TABLE IF NOT EXISTS staging.holiday (
    raw_date_text     TEXT,   -- DATUM (e.g. '1.01.2009')
    holiday_name      TEXT,   -- IME_PRAZNIKA
    weekday_name      TEXT,   -- DAN_V_TEDNU
    is_public_holiday_raw TEXT, -- DELA_PROST_DAN ('da'/'ne')
    day               INTEGER, -- DAN
    month             INTEGER, -- MESEC
    year              INTEGER  -- LETO
);

CREATE INDEX IF NOT EXISTS idx_staging_holiday_date_year
    ON staging.holiday (year, month, day);

-- 3.3 Generic SURS municipality/year wide tables (example for population)
-- NOTE: other SURS tables will follow the same pattern.

CREATE TABLE IF NOT EXISTS staging.population_total_wide (
    measure_label     TEXT,    -- e.g. 'Število prebivalcev - 1. julij'
    municipality_name TEXT,
    y2009             BIGINT,
    y2010             BIGINT,
    y2011             BIGINT,
    y2012             BIGINT,
    y2013             BIGINT,
    y2014             BIGINT,
    y2015             BIGINT,
    y2016             BIGINT,
    y2017             BIGINT,
    y2018             BIGINT,
    y2019             BIGINT,
    y2020             BIGINT,
    y2021             BIGINT,
    y2022             BIGINT,
    y2023             BIGINT
);

-- TODO: define analogous wide tables for:
--   - population_male_wide, population_female_wide
--   - population_density_wide
--   - area_wide
--   - cars_wide, dwellings_wide, avg_dwelling_area_wide
--   - num_schools_wide, num_kindergartens_wide
--   - age_structure_wide, employment_rate_wide

-- 3.4 Long/tidy demographic table (intermediate)

CREATE TABLE IF NOT EXISTS staging.municipality_year_indicator_long (
    municipality_name TEXT,
    year              INTEGER,
    indicator_code    TEXT,     -- e.g. 'POP_TOTAL', 'DENSITY', 'CARS', 'AGE_0_14_SHARE'
    value_numeric     NUMERIC,
    source_table      TEXT,
    source_measure    TEXT
);

CREATE INDEX IF NOT EXISTS idx_staging_munic_year_indicator
    ON staging.municipality_year_indicator_long (municipality_name, year, indicator_code);

-- ============================================================================
-- 4. Core dimensions
-- ============================================================================

-- 4.1 Municipality dimension

CREATE TABLE IF NOT EXISTS core.dim_municipality (
    municipality_id        SERIAL PRIMARY KEY,
    surs_municipality_code TEXT UNIQUE,       -- official code, if available
    name_sl                TEXT NOT NULL,
    name_bilingual         TEXT,
    statistical_region     TEXT,
    nuts3_code             TEXT,
    area_km2               NUMERIC,
    geom                   geometry(MultiPolygon, 4326)  -- TODO: confirm SRID
);

CREATE INDEX IF NOT EXISTS idx_dim_municipality_geom
    ON core.dim_municipality
    USING GIST (geom);

CREATE UNIQUE INDEX IF NOT EXISTS idx_dim_municipality_name
    ON core.dim_municipality (LOWER(name_sl));

-- 4.2 Date dimension

CREATE TABLE IF NOT EXISTS core.dim_date (
    date_id        INTEGER PRIMARY KEY,  -- e.g. 20090104
    full_date      DATE NOT NULL UNIQUE,
    year           INTEGER NOT NULL,
    quarter        INTEGER NOT NULL,
    month          INTEGER NOT NULL,
    day            INTEGER NOT NULL,
    week_of_year   INTEGER,
    day_of_week    INTEGER,             -- 1=Monday..7=Sunday
    day_of_week_name TEXT,
    is_weekend     BOOLEAN,
    holiday_id     INTEGER REFERENCES core.dim_holiday(holiday_id)
);

CREATE INDEX IF NOT EXISTS idx_dim_date_year_month
    ON core.dim_date (year, month);

-- 4.3 Time dimension

CREATE TABLE IF NOT EXISTS core.dim_time (
    time_id            SERIAL PRIMARY KEY,
    time_of_day        TIME NOT NULL,
    hour               INTEGER NOT NULL,
    minute             INTEGER NOT NULL,
    time_bucket        TEXT          -- e.g. 'night', 'morning_peak', ...
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_dim_time_unique
    ON core.dim_time (time_of_day);

-- 4.4 Holiday dimension

CREATE TABLE IF NOT EXISTS core.dim_holiday (
    holiday_id         SERIAL PRIMARY KEY,
    holiday_date       DATE NOT NULL UNIQUE,
    holiday_name       TEXT NOT NULL,
    is_public_holiday  BOOLEAN NOT NULL,
    is_school_holiday  BOOLEAN,        -- TODO: derive if needed
    day_of_week        INTEGER,
    day_of_week_name   TEXT,
    year               INTEGER,
    month              INTEGER,
    day                INTEGER
);

CREATE INDEX IF NOT EXISTS idx_dim_holiday_year
    ON core.dim_holiday (year, month);

-- 4.5 Weather station dimension (future)

CREATE TABLE IF NOT EXISTS core.dim_weather_station (
    station_id     SERIAL PRIMARY KEY,
    provider_code  TEXT UNIQUE,      -- ARSO code, etc.
    station_name   TEXT NOT NULL,
    elevation_m    NUMERIC,
    geom           geometry(Point, 4326)  -- TODO: confirm SRID of station dataset
);

CREATE INDEX IF NOT EXISTS idx_dim_weather_station_geom
    ON core.dim_weather_station
    USING GIST (geom);

-- ============================================================================
-- 5. Core fact tables
-- ============================================================================

-- 5.1 Accident fact

CREATE TABLE IF NOT EXISTS core.accident (
    accident_id            SERIAL PRIMARY KEY,
    source_accident_id     INTEGER NOT NULL,              -- ZaporednaStevilkaPN
    classification         TEXT,
    admin_unit_name        TEXT,
    accident_date          DATE NOT NULL,
    accident_time          TIME,
    date_id                INTEGER REFERENCES core.dim_date(date_id),
    time_id                INTEGER REFERENCES core.dim_time(time_id),
    in_settlement_flag     BOOLEAN,
    location_context       TEXT,
    road_type              TEXT,
    road_code              TEXT,
    road_name              TEXT,
    road_section_code      TEXT,
    road_section_name      TEXT,
    stationing             TEXT,
    cause                  TEXT,
    type                   TEXT,
    weather_raw            TEXT,
    traffic_flow           TEXT,
    road_surface_condition TEXT,
    road_surface_type      TEXT,
    x_coord_raw            NUMERIC,
    y_coord_raw            NUMERIC,
    geom                   geometry(Point, 4326),          -- derived from raw coords
    municipality_id        INTEGER REFERENCES core.dim_municipality(municipality_id),
    holiday_id             INTEGER REFERENCES core.dim_holiday(holiday_id),
    weather_observation_id INTEGER REFERENCES core.weather_observation(observation_id),
    year                   INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_accident_geom
    ON core.accident
    USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_accident_date
    ON core.accident (accident_date);

CREATE INDEX IF NOT EXISTS idx_accident_municipality_year
    ON core.accident (municipality_id, year);

-- 5.2 Accident participants fact

CREATE TABLE IF NOT EXISTS core.accident_person (
    accident_person_id     SERIAL PRIMARY KEY,
    accident_id            INTEGER NOT NULL REFERENCES core.accident(accident_id) ON DELETE CASCADE,
    person_seq             INTEGER,         -- from ZaporednaStevilkaOsebeVPN
    role_in_event          TEXT,            -- Povzrocitelj (normalized)
    age_years              INTEGER,
    sex                    TEXT,
    residence_admin_unit   TEXT,
    nationality            TEXT,
    injury_severity        TEXT,
    participant_type       TEXT,
    seat_belt_used         BOOLEAN,
    driving_experience_years  INTEGER,
    driving_experience_months INTEGER,
    breath_test_value      NUMERIC,
    blood_alcohol_value    NUMERIC
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_accident_person_natural
    ON core.accident_person (accident_id, person_seq);

-- 5.3 Municipality-year stats fact (wide metrics)

CREATE TABLE IF NOT EXISTS core.municipality_year_stats (
    municipality_id            INTEGER NOT NULL REFERENCES core.dim_municipality(municipality_id),
    year                       INTEGER NOT NULL,
    population_total           BIGINT,
    population_male            BIGINT,
    population_female          BIGINT,
    population_density_per_km2 NUMERIC,
    area_km2                   NUMERIC,
    num_passenger_cars         BIGINT,
    num_dwellings              BIGINT,
    avg_dwelling_area_m2       NUMERIC,
    num_schools                INTEGER,
    num_kindergartens          INTEGER,
    share_age_0_14             NUMERIC,
    employment_rate            NUMERIC,
    PRIMARY KEY (municipality_id, year)
);

CREATE INDEX IF NOT EXISTS idx_munic_year_stats_density
    ON core.municipality_year_stats (population_density_per_km2);

-- 5.4 Generic municipality indicator fact (long form, optional)

CREATE TABLE IF NOT EXISTS core.municipality_indicator_long (
    municipality_id  INTEGER NOT NULL REFERENCES core.dim_municipality(municipality_id),
    year             INTEGER NOT NULL,
    indicator_code   TEXT NOT NULL,
    indicator_value  NUMERIC,
    PRIMARY KEY (municipality_id, year, indicator_code)
);

-- 5.5 Weather observations (future)

CREATE TABLE IF NOT EXISTS core.weather_observation (
    observation_id       SERIAL PRIMARY KEY,
    station_id           INTEGER NOT NULL REFERENCES core.dim_weather_station(station_id),
    observation_time     TIMESTAMPTZ NOT NULL,
    temperature_c        NUMERIC,
    precipitation_mm     NUMERIC,
    snow_depth_cm        NUMERIC,
    wind_speed_ms        NUMERIC,
    visibility_m         NUMERIC,
    weather_code         TEXT,
    UNIQUE (station_id, observation_time)
);

CREATE INDEX IF NOT EXISTS idx_weather_station_time
    ON core.weather_observation (station_id, observation_time);

CREATE INDEX IF NOT EXISTS idx_weather_time
    ON core.weather_observation (observation_time);

-- ============================================================================
-- 6. Notes / TODOs
-- ============================================================================

-- TODO: Verify coordinate system of pn2009_2023 GeoKoordinataX/Y and set the
--       correct SRID for intermediate geometry (likely EPSG:3794) before
--       transforming to 4326 in core.accident.geom.
--
-- TODO: Implement ETL jobs:
--   - COPY each CSV into staging_raw.*
--   - Parse and filter data rows into staging.* wide tables.
--   - Unpivot wide SURS tables into staging.municipality_year_indicator_long.
--   - Build core.dim_municipality from external reference + SURS names.
--   - Populate core.dim_date and core.dim_time via generated series.
--   - Populate core.dim_holiday from staging.holiday.
--   - Derive core.accident and core.accident_person from staging.accident_person.
--   - Aggregate indicators into core.municipality_year_stats and/or
--     core.municipality_indicator_long.
--
-- TODO: Add check constraints / enums for categorical fields where stable code
--       lists are available (e.g. severity, weather conditions, road type).

