-- Step 4: Build core.dim_municipality from SURS data
-- Extract unique municipality names from st_prebivalcev (skip metadata header/footer)
-- Geometry left NULL for now (Phase 1)

TRUNCATE core.dim_municipality CASCADE;

WITH mun_raw AS (
    -- Extract municipality from column 2 of st_prebivalcev (id > 3 skips header)
    SELECT DISTINCT TRIM(BOTH FROM split_part(raw_line, ',', 2)) AS name_sl
    FROM staging_raw.st_prebivalcev
    WHERE id > 3
      AND split_part(raw_line, ',', 2) IS NOT NULL
      AND TRIM(split_part(raw_line, ',', 2)) <> ''
      -- Exclude metadata/footer
      AND TRIM(split_part(raw_line, ',', 2)) !~ '^(Metodološka|Podatkovna|SI-STAT|ID tabele|LETO)'
      AND TRIM(split_part(raw_line, ',', 2)) !~ '^\d+$'  -- not a number
),
mun_clean AS (
    SELECT name_sl
    FROM mun_raw
    WHERE LENGTH(name_sl) > 1
)
INSERT INTO core.dim_municipality (name_sl, name_bilingual)
SELECT
    name_sl,
    name_sl AS name_bilingual  -- can refine later for Koper/Capodistria etc.
FROM mun_clean
ORDER BY name_sl;
