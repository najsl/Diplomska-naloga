-- Step 9: Municipality name mapping
-- 1. Create mapping table (if not exists - done in db/init/02_etl_extensions.sql)
-- 2. Populate distinct admin_unit_name from staging.accident_person where no match exists
--    for manual review/fill. Run after step 6 (or 8) to have dim_municipality populated.

-- Clear existing mappings (optional - comment out if you want to preserve manual overrides)
-- TRUNCATE core.municipality_name_mapping;

-- Insert auto-matches: admin_unit_name that already match dim_municipality.name_sl
-- These serve as baseline; manual overrides can be added for mismatches
INSERT INTO core.municipality_name_mapping (admin_unit_name, municipality_id)
SELECT DISTINCT s.admin_unit_name, m.municipality_id
FROM staging.accident_person s
JOIN core.dim_municipality m ON LOWER(TRIM(m.name_sl)) = LOWER(TRIM(s.admin_unit_name))
WHERE s.admin_unit_name IS NOT NULL AND TRIM(s.admin_unit_name) <> ''
  AND s.accident_date_raw ~ '^\d{4}-\d{2}-\d{2}$'
ON CONFLICT (admin_unit_name) DO NOTHING;

-- Report: admin_unit_name values with NO match (for manual mapping)
-- Run this query to get the list for manual review:
-- SELECT DISTINCT s.admin_unit_name
-- FROM staging.accident_person s
-- WHERE s.admin_unit_name IS NOT NULL AND TRIM(s.admin_unit_name) <> ''
--   AND s.accident_date_raw ~ '^\d{4}-\d{2}-\d{2}$'
--   AND NOT EXISTS (
--     SELECT 1 FROM core.municipality_name_mapping m
--     WHERE m.admin_unit_name = s.admin_unit_name
--   )
--   AND NOT EXISTS (
--     SELECT 1 FROM core.dim_municipality d
--     WHERE LOWER(TRIM(d.name_sl)) = LOWER(TRIM(s.admin_unit_name))
--   )
-- ORDER BY s.admin_unit_name;
