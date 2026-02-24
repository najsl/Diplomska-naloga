## CSV inventory

### pn2009_2023.csv
- **Row count (approx.)**: 522 385 data rows (2009–2023)
- **Grain**: one row per *person involved in an accident* (participant-level); multiple rows share the same `ZaporednaStevilkaPN` (accident id).
- **Delimiter / encoding**: comma-separated, UTF-8 with Slovenian diacritics.
- **Key columns (raw)**:
  - `ZaporednaStevilkaPN` (accident sequential id, integer-like)
  - `ZaporednaStevilkaOsebeVPN` (participant sequential id within accident, integer-like)
  - **Candidate primary key (staging)**: (`ZaporednaStevilkaPN`, `ZaporednaStevilkaOsebeVPN`) – appears unique in sample.
- **Important columns & inferred types**:
  - `ZaporednaStevilkaPN`: integer (accident id)
  - `KlasifikacijaNesrece`: text (severity classification)
  - `UpravnaEnotaStoritve`: text (administrative unit; close to municipality but not identical)
  - `DatumPN`: date (ISO `YYYY-MM-DD`)
  - `UraPN`: time as text (`H.MM`), needs parsing to proper `time`
  - `VNaselju`: text/boolean-like flag (`DA`/`NE`)
  - `Lokacija`: text
  - `VrstaCesteNaselja`, `SifraCesteNaselja`, `TekstCesteNaselja`, `SifraOdsekaUlice`, `TekstOdsekaUlice`: text / codes
  - `StacionazaDogodka`: text / numeric distance along road
  - `OpisKraja`: text (free-form location description)
  - `VzrokNesrece`, `TipNesrece`: text (cause, type)
  - `VremenskeOkoliscine`, `StanjePrometa`, `StanjeVozisca`, `VrstaVozisca`: categorical text
  - `GeoKoordinataX`, `GeoKoordinataY`: numeric (projected coordinates, likely D96/TM; **TODO: confirm SRID, probably EPSG:3794**)
  - `ZaporednaStevilkaOsebeVPN`: integer (participant id)
  - `Povzrocitelj`: text (`POVZROČITELJ`, `UDELEŽENEC`, etc.)
  - `Starost`: integer (age in years, may contain missing)
  - `Spol`: text (`MOŠKI`, `ŽENSKI`)
  - `UEStalnegaPrebivalisca`: text (administrative unit of residence)
  - `Drzavljanstvo`: text
  - `PoskodbaUdelezenca`: text (injury severity)
  - `VrstaUdelezenca`: text (role: driver, passenger, pedestrian, etc.)
  - `UporabaVarnostnegaPasu`: text (`DA`/`NE`/`NEZNANO`)
  - `VozniskiStazVLetih`, `VozniskiStazVMesecih`: integer, may be `0` or missing
  - `VrednostAlkotesta`, `VrednostStrokovnegaPregleda`: numeric as localized text (commas, quotes), need cleaning
  - `Leto`: integer year (redundant with `DatumPN`)
- **Date / time fields**: `DatumPN`, `UraPN`, `Leto`.
- **Geography fields**:
  - `GeoKoordinataX`, `GeoKoordinataY` – can be converted to `geometry(Point, <SRID>)`.
  - `UpravnaEnotaStoritve` – text key that can later be mapped to municipalities.
- **Missingness / data issues (from sample)**:
  - Some `UEStalnegaPrebivalisca` empty.
  - Alcohol fields stored as strings with quotes/commas, some `",00"`, missing, or only professional-test populated.
  - Some coordinates are `0,0` – need to be treated as missing and handled via fallback joins.
  - `UraPN` has formats like `3.45`, `5.5`, `21.39` (needs normalization).
- **Time granularity**: event-level (exact date + time).

### seznampraznikovindelaprostihdni20002030.csv
- **Row count (approx.)**: 573 data rows (years 2000–2030, only special days).
- **Grain**: one row per holiday / memorial day (not full calendar).
- **Delimiter / encoding**: semicolon-separated (`;`), UTF-8.
- **Columns & inferred types**:
  - `DATUM`: text `D.MM.LLLL` (e.g. `1.01.2000`), convertible to `date`
  - `IME_PRAZNIKA`: text (holiday name, includes commas)
  - `DAN_V_TEDNU`: text (weekday name)
  - `DELA_PROST_DAN`: text flag (`da`/`ne` with a trailing space in some rows)
  - `DAN`: integer day-of-month
  - `MESEC`: integer month
  - `LETO`: integer year
- **Key candidates**: `DATUM` is unique across dataset; (`LETO`, `DAN`, `MESEC`) combination also unique.
- **Missingness / issues**:
  - Some `DELA_PROST_DAN` values have trailing spaces (`'ne '`); need trimming.
  - Dataset only includes holidays and certain memorial days (e.g. `dan Rudolfa Maistra`), not ordinary days.
- **Time granularity**: date-level (no time-of-day).

### Gostota poseljenosti.csv
- **Row count (approx.)**: 147 data rows.
- **Source style**: SI-STAT export for **settlements / urban areas** (`MESTNO NASELJE`) with metadata footer.
- **Grain**: one row per *settlement* (naselje) + columns for years 2011–2023 containing population density.
- **Delimiter / encoding**: comma-separated, UTF-8; first lines contain metadata, header row at line 3.
- **Columns (effective data)**:
  - Column 1: settlement or group label (e.g. `Mestna naselja - SKUPAJ`, `Ajdovščina`, `Bled`…), text.
  - Columns 2–14: numeric densities for years 2011–2023 (decimals with `.` separator).
- **Key candidates**:
  - Settlement name alone appears unique within this extract.
- **Missingness / issues**:
  - SI-STAT metadata appended at bottom (lines like `Metodološka pojasnila`, `LETO:`, etc.), must be filtered out on load.
  - First few rows contain “total” aggregates (e.g. `Mestna naselja - SKUPAJ`) that should be treated as separate members or excluded in core.
- **Geography / time**:
  - Geography: settlement names, can be mapped to municipalities or to point/centroid geometries later.
  - Time: yearly densities.

### gostota_poseljenosti.csv
- **Row count (approx.)**: 281 data rows.
- **Source style**: SI-STAT export for **municipalities** (`MERITVE, OBČINE , LETO`).
- **Grain**: one row per *measure + municipality*; columns for years 2009–2023.
- **Columns (effective data)**:
  - Column 1: measure (`Gostota naseljenosti - 1. julij` or aggregate row `SLOVENIJA`).
  - Column 2: municipality name (e.g. `Ajdovščina`, `Ankaran/Ancarano`).
  - Columns 3–17: yearly density values (decimals) for 2009–2023.
- **Inferred types**:
  - Measure, municipality: text
  - Year columns: numeric (density, `prebivalci na km2`)
- **Key candidates**:
  - (`municipality`, `year`) when pivoted to long form.
- **Missingness / issues**:
  - Some municipalities added later (e.g. `Ankaran/Ancarano`) have `-` for earlier years.
  - Footer and metadata lines after the table; must be excluded in staging.
- **Geography / time**:
  - Geography: municipality name can be linked to municipality dimension via standardized codes/names.
  - Time: yearly snapshot as of 1 July.

### povrsina_obcine.csv
- **Row count (approx.)**: 281 data rows.
- **Grain**: one row per *measure + municipality*; surface area (km²) by year, but values are effectively constant over 2009–2023 except for a few boundary changes.
- **Columns**:
  - Column 1: measure (`Površina (km2) - 1. januar`, `SLOVENIJA`)
  - Column 2: municipality name
  - Columns 3–17: area values (integers; some rows show slight differences for boundary changes or shapefile updates).
- **Key candidates**:
  - (`municipality`) — area is time-invariant for most practical purposes; we can collapse to a single canonical value in core.
- **Missingness / issues**:
  - Some municipal areas change slightly over time; **TODO:** decide whether to store per-year areas or canonicalize to a reference year (e.g. 2023).
- **Geography / time**:
  - Supports computing density and spatial normalization; join to municipality dimension by name/code.

### st_prebivalcev.csv
- **Row count (approx.)**: 273 data rows.
- **Grain**: one row per *municipality*, with columns for population by year (2009–2023); includes an aggregate `SLOVENIJA`.
- **Columns**:
  - Column 1: measure label (`Število prebivalcev - 1. julij`)
  - Column 2: municipality name
  - Columns 3–17: integer population counts per year.
- **Key candidates**:
  - (`municipality`, `year`) when unpivoted.
- **Missingness / issues**:
  - Metadata/footer lines; must be removed.
  - Some municipalities created later (e.g. Mirna) have `-` or are absent for early years.
- **Time granularity**: annual population snapshot (1 July).

### st_moskih.csv
- **Row count (approx.)**: 273 data rows.
- **Grain**: similar to `st_prebivalcev.csv` but only male population.
- **Columns & types**:
  - Measure label: `Število moških - 1. julij`
  - Municipality: text
  - Year columns 2009–2023: integer counts of males.
- **Keys / join**:
  - (`municipality`, `year`) with `st_prebivalcev` and `st_zensk` to derive age/sex structure.
- **Issues**:
  - Same SI-STAT artifacts as other demographic tables; requires cleaning of metadata rows.

### st_zensk.csv
- **Row count (approx.)**: 273 data rows.
- **Grain**: female population by municipality/year (`Število žensk - 1. julij`).
- **Structure / keys / issues**: identical pattern to `st_moskih.csv`; join on (`municipality`, `year`).

### st_avtomobilov.csv
- **Row count (approx.)**: 273 data rows.
- **Grain**: number of **passenger cars** by municipality at 31 December (yearly).
- **Columns**:
  - Measure: `Število osebnih avtomobilov - 31. december`
  - Municipality
  - Year columns 2009–2023: integer counts of cars.
- **Analytical use**: car-per-capita, motorization as risk factor.
- **Keys**: (`municipality`, `year`).

### st_stanovanj.csv
- **Row count (approx.)**: 273 data rows.
- **Grain**: number of dwellings (`Število stanovanj - 1. januar`) per municipality/year.
- **Columns**:
  - Measure label, municipality, year columns 2011, 2015, 2019, 2021,… (sparse; only census/reference years populated).
- **Issues**:
  - Many cells contain `...` (missing / confidential) or are blank; coverage only at selected years.
  - Will need interpolation or cautious use in analysis.

### povp_povrsina_stanovanj.csv
- **Row count (approx.)**: 273 data rows.
- **Grain**: **average useful floor area** of dwellings (m²) by municipality/year.
- **Columns**:
  - Measure: `Povprečna uporabna površina stanovanj (m2)`
  - Municipality
  - Year columns (2011, 2015, 2019, 2021…) with decimal values; many years missing (`...`).
- **Use**: housing stock / socio-economic proxy; joinable by (`municipality`, `year`).
- **Issues**:
  - Sparse; must be treated as optional indicator with limited temporal coverage.

### st_sol.csv
- **Row count (approx.)**: 277 data rows.
- **Grain**: number of schools per municipality/year (`Število šol`).
- **Columns**:
  - Measure, municipality, year columns 2009–2023 (small integers).
- **Issues**:
  - Some cells `-` or `...` (e.g. municipalities without schools).

### st_vrtcev.csv
- **Row count (approx.)**: 277 data rows.
- **Grain**: number of kindergartens per municipality/year (`Število vrtcev`).
- **Columns**:
  - Measure, municipality, year columns 2009–2023 (integers).
- **Use**:
  - Proxy for urbanization / service availability; join on (`municipality`, `year`).

### starost_prebivalcev.csv
- **Row count (approx.)**: 707 data rows.
- **Grain**:
  - Multiple age-structure *measures* per municipality/year (e.g. `Delež prebivalcev starih 0 do 14 let - 1. januar`; likely other age bands follow further down).
- **Columns**:
  - Measure name (text)
  - Municipality
  - Year columns 2009–2023 with decimal percentages.
- **Keys**:
  - (`measure`, `municipality`, `year`) when unpivoted.
- **Issues**:
  - Values expressed as percentages; need conversion to numeric (decimal) and possible recomputation to counts via `population * share`.
  - Footer/metadata blocks as in other SI-STAT exports.

### stopnja_delovne_aktivnosti.csv
- **Row count (approx.)**: 277 data rows.
- **Grain**: employment activity rate per municipality/year (`Stopnja delovne aktivnosti (%)`).
- **Columns**:
  - Measure, municipality, year columns 2009–2023, with decimal percentages.
- **Use**:
  - Socio-economic indicator; join on (`municipality`, `year`).

### st_zensk.csv (already above), st_moskih.csv (already above)
- See respective sections; both are sex-disaggregated population counts aligning with `st_prebivalcev`.

### Summary of entity clusters
- **Accidents/events**: `pn2009_2023.csv` – core event/participant-level data with time and location.
- **Holidays/calendar**: `seznampraznikovindelaprostihdni20002030.csv` – date-level special days.
- **Municipality-level demographics & infrastructure**:
  - Population, male/female counts: `st_prebivalcev.csv`, `st_moskih.csv`, `st_zensk.csv`
  - Population density: `gostota_poseljenosti.csv`
  - Area: `povrsina_obcine.csv`
  - Dwellings and dwelling size: `st_stanovanj.csv`, `povp_povrsina_stanovanj.csv`
  - Car ownership: `st_avtomobilov.csv`
  - Education and childcare capacity: `st_sol.csv`, `st_vrtcev.csv`
  - Age structure: `starost_prebivalcev.csv`
  - Labour market: `stopnja_delovne_aktivnosti.csv`
- **Settlement-level density**:
  - `Gostota poseljenosti.csv` – more granular density by settlement (can be used later for advanced spatial joins if settlement geometries are available).

**Assumptions (shared across files)**:
- Municipality names follow SURS conventions and may include bilingual forms (e.g. `Koper/Capodistria`); **TODO:** build a standardized municipality dimension with official codes for robust joins.
- SI-STAT exports contain metadata lines before and after the main table; staging must load and then filter to data rows only.
- All decimal values use `.` as decimal separator; any `...` or `-` should be treated as missing values (`NULL`) in staging.

