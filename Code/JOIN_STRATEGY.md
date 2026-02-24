## Join strategy plan

### 1. Accidents → municipalities

#### Primary method: spatial join via geometry
- **Inputs**:
  - `core.accident.geom` – point geometry per accident, from `GeoKoordinataX/Y`.
  - `core.dim_municipality.geom` – municipal polygons (imported from official shapefile).
- **Join rule**:
  - Assign `municipality_id` such that:
    - `ST_Contains(m.geom, a.geom)` is true, or
    - `ST_Within(a.geom, m.geom)` is true.
  - If multiple polygons match (border cases), pick the one with:
    - smallest `ST_Distance(a.geom, ST_Centroid(m.geom))`.
- **Fallbacks**:
  1. **Missing or invalid coordinates (0,0 or NULL)**:
     - Use `UpravnaEnotaStoritve` (administrative unit) and map to municipality via a curated mapping table `core.map_admin_unit_to_municipality`.
     - If multiple municipalities share an administrative unit, choose:
       - municipality whose centroid is nearest to the median location of all accidents with that combination of `UpravnaEnotaStoritve` and road code; **TODO:** define exact heuristic.
  2. **Point lies slightly outside any polygon** (edge-of-geometry / rounding):
     - Use `ST_DWithin(a.geom, m.geom, tolerance)` with a small tolerance (e.g. 50–100 m) and assign nearest polygon.
  3. **Residual unresolved cases**:
     - Keep `municipality_id` as NULL and track them in a data quality table for manual review.

#### Expected issues & mitigations
- **CRS mismatch**:
  - Ensure municipal polygons and accident geometries share the same SRID before join.  
  - **TODO:** confirm `GeoKoordinataX/Y` CRS (assumed D96/TM EPSG:3794) and use `ST_Transform` consistently.
- **Boundary changes**:
  - A few municipalities have changed over 2009–2023; for consistency, assign accidents to municipalities based on geometry valid at accident date if historical boundaries are available; otherwise, use current boundaries and document that limitation.

### 2. Accidents → holidays

#### Primary join: by accident date
- **Inputs**:
  - `core.accident.accident_date` (from `DatumPN`)
  - `core.dim_holiday.holiday_date` (from `DATUM` / `LETO`, `DAN`, `MESEC`)
- **Join rule**:
  - Convert `DATUM` like `1.01.2009` to `date`, then:
    - Left join accidents to `dim_holiday` on `accident_date = holiday_date`.
  - Alternatively, join accidents to `dim_date` and use `dim_date.holiday_id`.
- **Derived attributes on accident**:
  - `is_public_holiday` (`DELA_PROST_DAN = 'da'`)
  - `holiday_type` (from holiday name classification)
  - `is_long_weekend` (derived in `dim_date`, e.g. holiday adjacent to weekend).

#### Fallbacks / edge cases
- **Partial coverage**:
  - Holiday table covers 2000–2030; accidents are 2009–2023, so full overlap – no temporal gap expected.
- **Time-of-day**:
  - All holidays are full days; no adjustment for time-of-day needed.

### 3. Accidents → demographic indicators

#### Primary join: municipality + year
- **Inputs**:
  - `core.accident.municipality_id` (from spatial join / fallback mapping)
  - `core.accident.year` (from `Leto` / `accident_date`)
  - `core.municipality_year_stats(municipality_id, year, …)`
- **Join rule**:
  - `accident.municipality_id = stats.municipality_id AND accident.year = stats.year`.
- **Notes**:
  - Demographics are **yearly snapshots**; accidents are event-level. Using same-year stats approximates contemporaneous context.

#### Fallbacks / issues
- **Demographics starting later / sparse indicators**:
  - Some indicators (e.g. dwelling size) only exist for selected years (e.g. census years).
  - Strategy:
    - For missing indicators, use the **latest available year ≤ accident year** as a carry-forward (e.g. 2011 census value used for 2012–2014).
    - **TODO:** document per-indicator interpolation/extrapolation policy.
- **Municipality naming differences**:
  - Normalize municipality names when building `dim_municipality`:
    - trim whitespace, standardize casing,
    - unify bilingual variants (e.g. `Izola/Isola` vs `Izola/Isola `).
  - Use SURS codes as primary join key; names only for human reference.

### 4. Accidents → population density

#### Municipality-level density (primary)
- **Source**: `gostota_poseljenosti.csv` (municipality/year).
- **Join rule**:
  - As part of `core.municipality_year_stats`, then inherited by accidents via municipality+year join.

#### Settlement-level density (optional, higher resolution)
- **Source**: `Gostota poseljenosti.csv` (settlement/year).
- **Join strategy**:
  1. Build `core.dim_settlement` with geometry and municipality FK (external spatial data).
  2. For each accident, find **nearest settlement centroid within its municipality**.
  3. Attach density for matching year (if available) or nearest year.
- **Use cases**:
  - Distinguish dense city-centre segments from more rural parts of the same municipality.
  - Support hotspot analysis based on settlement-level densities.

### 5. Accidents → weather

> Weather datasets are not yet present in `Dataset/`, but the model will anticipate them.

#### Primary join: date/time + nearest station
- **Inputs (future)**:
  - `core.accident.geom`, `accident_timestamp` (date + time)
  - `core.dim_weather_station.geom` (station locations)
  - `core.weather_observation(station_id, observation_timestamp, …)`
- **Spatial step**:
  - For each accident:
    - Compute nearest station within radius `R` (e.g. 10 km):  
      `ST_Distance(a.geom, s.geom) = min` and `ST_DWithin(a.geom, s.geom, R)`.
  - If multiple stations within `R`, choose:
    - the one with longest continuous operational history, or
    - the nearest one.
- **Temporal step**:
  - If observations are hourly:
    - Round or floor `accident_timestamp` to nearest hour and match exact hour if available.
    - Else choose the observation closest in time within a window (e.g. ±2 hours).
  - If only daily data:
    - Match on accident date; optionally flag if accident occurred at night and use previous/next day if more appropriate (**TODO:** finalize rule based on available data).
- **Fallbacks**:
  1. **No station within radius R**:
     - Increase search radius to a maximum (e.g. 30–50 km) and pick closest station; record actual distance.
  2. **Still no station**:
     - Fall back to regional or national aggregate (e.g. region-day mean) and store that in `weather_observation` as synthetic records.
  3. **Missing observation at exact time**:
     - Use nearest observation within allowed time window; otherwise, nearest in same day.

### 6. Accidents → holidays (derived views)

To simplify analytics, define views:
- `core.accident_enriched`:
  - Left join `core.accident` with `dim_date`, `dim_holiday`, `municipality_year_stats`, and core demographics, exposing:
    - flags such as `is_public_holiday`, `is_weekend`, `is_school_holiday`,
    - demographic attributes like `population_total`, `population_density_per_km2`, `employment_rate`.

### 7. Accidents → schools / kindergartens

- **Source**: `st_sol.csv` (schools), `st_vrtcev.csv` (kindergartens).
- **Join path**:
  - `accident` → `municipality_year_stats` (includes `num_schools`, `num_kindergartens`).
- **Use**:
  - Analyze risk near municipalities with many educational institutions (higher child pedestrian exposure).
  - For higher spatial precision, future extension could join accidents to school point locations (external dataset) within a given buffer.

### 8. Summary of join keys

- **Accident → Municipality**:
  - **Primary**: spatial (`accident.geom` within `dim_municipality.geom`)
  - **Fallback**: normalized `UpravnaEnotaStoritve` → municipality mapping.

- **Accident → Demographics**:
  - `municipality_id` + `year`.

- **Accident → Holidays**:
  - `accident_date` = `holiday_date`.

- **Accident → Weather (future)**:
  - nearest station within radius + closest timestamp.

- **Accident → Settlement density (optional)**:
  - nearest settlement centroid within municipality + year.

**Assumptions & TODOs**
- **TODO:** Confirm CRS of accident coordinates and municipal polygons; standardize on a canonical SRID (likely 4326 in `core`, with raw projected staging).
- **TODO:** Introduce a robust municipality reference table (codes + normalized names) to reconcile all SURS exports and the accident `UpravnaEnotaStoritve`.
- **TODO:** Decide interpolation/extrapolation policies for sparse year indicators (e.g. dwelling characteristics).

