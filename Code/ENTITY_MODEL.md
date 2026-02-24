## Canonical entities and relationships

### Overview
- **Core fact**: traffic accidents (event-level), enriched with:
  - participant-level details
  - municipality and spatial context
  - holiday flags
  - demographic and socio-economic indicators
  - (later) weather observations
- **Dimensions**: date, time, municipality, settlement (optional), holiday, weather station, indicators.

### Fact tables

#### `core.accident`
- **Grain**: one row per *accident event* (unique `accident_id`).
- **Primary key**: `accident_id` (surrogate, derived from `ZaporednaStevilkaPN`).
- **Core attributes (from `pn2009_2023.csv`)**:
  - `source_accident_id` (original `ZaporednaStevilkaPN`)
  - `classification` (`KlasifikacijaNesrece`)
  - `admin_unit_code` / `admin_unit_name` (normalized from `UpravnaEnotaStoritve`)
  - `accident_date` (from `DatumPN`)
  - `accident_time` (from `UraPN`, normalized)
  - `in_settlement_flag` (from `VNaselju`)
  - `location_context` (`Lokacija`, `OpisKraja`)
  - `road_type`, `road_code`, `road_name`, `road_section_code`, `road_section_name`
  - `stationing` (`StacionazaDogodka`)
  - `cause` (`VzrokNesrece`)
  - `type` (`TipNesrece`)
  - `weather_raw` (`VremenskeOkoliscine`)
  - `traffic_flow` (`StanjePrometa`)
  - `road_surface_condition` (`StanjeVozisca`)
  - `road_surface_type` (`VrstaVozisca`)
  - `x_coord_raw`, `y_coord_raw` (`GeoKoordinataX`, `GeoKoordinataY`)
  - `geom` – **PostGIS `geometry(Point, 4326)`**, derived via transformation from raw projected coords  
    - **TODO:** confirm input SRID (likely EPSG:3794) and transformation pipeline.
  - `year` (from `Leto` or extracted from date)
- **Foreign keys**:
  - `date_id` → `core.dim_date(date_id)`
  - `time_id` → `core.dim_time(time_id)` (or directly store `accident_time` and index)
  - `municipality_id` → `core.dim_municipality(municipality_id)`
  - `holiday_id` (nullable) → `core.dim_holiday(holiday_id)`
  - `weather_observation_id` (nullable) → `core.weather_observation(observation_id)`
  - `settlement_id` (nullable) → `core.dim_settlement(settlement_id)` (for future, via spatial join)

#### `core.accident_person`
- **Grain**: one row per *person/vehicle involved in an accident*.
- **Primary key**: `accident_person_id` (surrogate).
- **Natural key**: (`accident_id`, `person_seq`) where `person_seq` derives from `ZaporednaStevilkaOsebeVPN`.
- **Attributes (from `pn2009_2023.csv`)**:
  - `accident_id` (FK → `core.accident`)
  - `person_seq` (`ZaporednaStevilkaOsebeVPN`)
  - `role_in_event` (`Povzrocitelj`)
  - `age` (`Starost`)
  - `sex` (`Spol`)
  - `residence_admin_unit` (`UEStalnegaPrebivalisca`)
  - `nationality` (`Drzavljanstvo`)
  - `injury_severity` (`PoskodbaUdelezenca`)
  - `participant_type` (`VrstaUdelezenca`)
  - `seat_belt_used_flag` (`UporabaVarnostnegaPasu`)
  - `driving_experience_years`, `driving_experience_months`
  - `breath_test_value`, `blood_alcohol_value` (numeric, cleaned)
- **Foreign keys (logical)**:
  - `accident_id` → `core.accident`
  - `age_group_id` (optional) → derived age-group dimension for analytics.

#### `core.municipality_year_stats`
- **Grain**: one row per *municipality + year*.
- **Primary key**: (`municipality_id`, `year`).
- **Source files**:
  - `st_prebivalcev.csv` – total population
  - `st_moskih.csv`, `st_zensk.csv` – male/female counts
  - `gostota_poseljenosti.csv` – population density
  - `povrsina_obcine.csv` – area (km²)
  - `st_avtomobilov.csv` – number of cars
  - `st_stanovanj.csv` – number of dwellings
  - `povp_povrsina_stanovanj.csv` – avg floor area
  - `st_sol.csv`, `st_vrtcev.csv` – number of schools/kindergartens
  - `starost_prebivalcev.csv` – age structure measures (e.g. share 0–14)
  - `stopnja_delovne_aktivnosti.csv` – employment/active population rate
- **Selected attributes (long/tidy form, wide metrics)**:
  - `municipality_id` (FK)
  - `year`
  - `population_total`
  - `population_male`
  - `population_female`
  - `population_density_per_km2`
  - `area_km2`
  - `num_passenger_cars`
  - `num_dwellings`
  - `avg_dwelling_area_m2`
  - `num_schools`
  - `num_kindergartens`
  - `share_age_0_14` (and possibly additional age bands, **TODO:** finalize list based on full `starost_prebivalcev.csv` contents)
  - `employment_rate`
- **Foreign keys**:
  - `municipality_id` → `core.dim_municipality`

#### `core.municipality_indicator_long` (optional alternative)
- **Grain**: one row per (`municipality_id`, `year`, `indicator_code`).
- **Use**: generic extensible store for any future indicators beyond the fixed set above.
- **Primary key**: (`municipality_id`, `year`, `indicator_code`).
- **Attributes**:
  - `indicator_code` (e.g. `POP_TOTAL`, `DENSITY`, `CARS`, `AGE_0_14_SHARE`, `ACTIVITY_RATE`)
  - `indicator_value` (numeric)

### Dimension tables

#### `core.dim_municipality`
- **Grain**: one row per municipality.
- **Primary key**: `municipality_id` (surrogate).
- **Business keys**:
  - `surs_municipality_code` (official SURS code, **TODO:** to be loaded from external reference)
  - `name_sl` (official Slovenian name)
  - `name_bilingual` (e.g. `Koper/Capodistria`, nullable)
- **Attributes**:
  - `statistical_region` (e.g. Gorenjska, Osrednjeslovenska…)
  - `nuts3_code` (optional)
  - `area_km2` (canonical value from `povrsina_obcine.csv`)
  - `geom` – `geometry(MultiPolygon, <SRID>)` for municipal boundaries  
    - **TODO:** import geometry from official PostGIS-ready shapefile (e.g. GURS/SURS) and confirm SRID (likely 3794 or 4326).
- **Relationships**:
  - Referenced by `core.accident` (via spatial join or name mapping)
  - Referenced by `core.municipality_year_stats` and `core.municipality_indicator_long`.

#### `core.dim_settlement` (optional, for finer spatial context)
- **Grain**: one row per settlement (naselje).
- **Source**: external SI-STAT or geospatial dataset + `Gostota poseljenosti.csv`.
- **Primary key**: `settlement_id`.
- **Attributes**:
  - `settlement_name`
  - `municipality_id` (FK)
  - `geom` – `geometry(Point or Polygon, <SRID>)` (settlement centroid or area)
- **Usage**:
  - Accident-to-settlement assignment via nearest settlement centroid.
  - Use settlement-level density as additional covariate in risk models.

#### `core.dim_date`
- **Grain**: one row per calendar date.
- **Primary key**: `date_id` (e.g. `YYYYMMDD` integer).
- **Attributes**:
  - `date` (date)
  - `year`, `quarter`, `month`, `day`, `week`, `day_of_week`
  - `is_weekend_flag`
  - `is_holiday_flag` (from join with `core.dim_holiday`)
  - `holiday_id` (nullable FK)
- **Source**:
  - Generated calendar table (covers at least 2000–2030 to match holiday data and accident period).

#### `core.dim_time`
- **Grain**: one row per time-of-day bucket (e.g. minute or 15-minute interval).
- **Primary key**: `time_id`.
- **Attributes**:
  - `time_of_day` (time)
  - `hour`, `minute`
  - `time_of_day_bucket` (e.g. night/morning/peak).

#### `core.dim_holiday`
- **Grain**: one row per distinct holiday **date** and type.
- **Primary key**: `holiday_id`.
- **Business key**: `holiday_date` (`date`).
- **Attributes**:
  - `holiday_name`
  - `is_public_holiday_flag` (from `DELA_PROST_DAN`)
  - `is_school_holiday_flag` (**TODO:** optional, if derived)
  - `day_of_week`, `year`, `month`, `day`
- **Source**: `seznampraznikovindelaprostihdni20002030.csv`.

#### `core.dim_weather_station` (future)
- **Grain**: one row per weather station.
- **Primary key**: `station_id`.
- **Attributes**:
  - `station_name`
  - `provider_code` (ARSO id, etc.)
  - `geom` – `geometry(Point, 4326 or 3794)`
  - `elevation_m`
- **Source**: external ARSO station list (**TODO:** to be added).

### Weather observations (future)

#### `core.weather_observation`
- **Grain**: one row per (`station_id`, `observation_timestamp`) – could be hourly or daily.
- **Primary key**: `observation_id` (surrogate).
- **Business key**: (`station_id`, `observation_timestamp`).
- **Attributes (example)**:
  - `station_id` (FK)
  - `observation_timestamp` (timestamptz)
  - `temperature_c`
  - `precipitation_mm`
  - `snow_depth_cm`
  - `wind_speed_ms`
  - `visibility_m`
  - `weather_code` (ARSO code)
- **Relationship**:
  - `core.accident.weather_observation_id` – matched via nearest station & nearest-in-time logic.

### Relationships (ERD-style narrative)

- **`core.accident` ↔ `core.accident_person`**
  - **Type**: 1-to-many (one accident has many participants).
  - **Join**: `accident_person.accident_id = accident.accident_id`.

- **`core.accident` ↔ `core.dim_date`**
  - **Type**: many-to-1.
  - **Join**: `accident.date_id = dim_date.date_id` (from `DatumPN`).

- **`core.accident` ↔ `core.dim_time`**
  - **Type**: many-to-1.
  - **Join**: `accident.time_id = dim_time.time_id` (from `UraPN`).

- **`core.accident` ↔ `core.dim_municipality`**
  - **Primary method**: assign municipality via spatial join between `accident.geom` (point) and municipal polygons.
  - **Fallback**: map via normalized `UpravnaEnotaStoritve` to municipality (look-up table).
  - **Type**: many-to-1; `accident.municipality_id` FK.

- **`core.accident` ↔ `core.municipality_year_stats`**
  - **Type**: many-to-1.
  - **Join**: `accident.municipality_id = stats.municipality_id AND accident.year = stats.year`.

- **`core.accident` ↔ `core.dim_holiday` / `core.dim_date`**
  - **Type**: many-to-1.
  - **Join**:
    - First, link accident to `dim_date` using `accident_date`.
    - `dim_date.holiday_id` links to `dim_holiday` if the date is a known holiday.

- **`core.accident` ↔ `core.weather_observation` (future)**
  - **Type**: many-to-1.
  - **Join rule (conceptual)**:
    - For each accident:
      - Find nearest weather station within a max radius (e.g. 10–20 km) from `accident.geom`.
      - Select the weather observation closest in time (e.g. same hour or nearest hour) for that station.
      - If none within radius, fall back to broader regional or daily aggregate (**TODO:** finalize threshold values).

- **`core.accident` ↔ `core.dim_settlement` (optional)**
  - **Type**: many-to-1.
  - **Join**: nearest settlement centroid to `accident.geom` (within municipality).
  - **Use**: high-resolution urban vs rural context using `Gostota poseljenosti.csv`.

### Geometry columns (PostGIS)

- **Accidents**
  - `core.accident.geom`: `geometry(Point, 4326)`
  - Derived from raw `GeoKoordinataX/Y` in national projected CRS:
    - Staged as `geometry(Point, 3794)` (if D96/TM confirmed), then `ST_Transform` to 4326 for analytics.
  - **Indexes**:
    - GiST index on `core.accident.geom` for spatial queries/hotspot detection.

- **Municipalities**
  - `core.dim_municipality.geom`: `geometry(MultiPolygon, 4326 or 3794)` (consistent with accidents after transformation).
  - Used for:
    - spatial join accidents → municipality
    - polygon-based aggregations and hotspot analysis.

- **Settlements (optional)**
  - `core.dim_settlement.geom`: `geometry(Point or Polygon, same SRID as municipalities)`.

### Fact and dimension classification

- **Fact tables**:
  - `core.accident`
  - `core.accident_person`
  - `core.municipality_year_stats`
  - `core.municipality_indicator_long` (if implemented)
  - `core.weather_observation` (future)

- **Dimension tables**:
  - `core.dim_municipality`
  - `core.dim_settlement` (optional)
  - `core.dim_date`
  - `core.dim_time`
  - `core.dim_holiday`
  - `core.dim_weather_station`

**Assumptions**:
- Municipality geometries and codes will be imported from authoritative external sources (not present in `Dataset/`).
- Accident coordinates are in a consistent projected CRS; we assume D96/TM and will validate against external documentation.  
- All demographic SI-STAT exports relate to municipalities as of current boundaries; **TODO:** document any boundary changes that might affect long-term trend analysis.

