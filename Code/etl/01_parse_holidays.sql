-- Step 1: Parse staging_raw.seznampraznikovindelaprostihdni20002030 → staging.holiday
-- Semicolon-delimited: DATUM;IME_PRAZNIKA;DAN_V_TEDNU;DELA_PROST_DAN;DAN;MESEC;LETO
-- Skip header row (id=1), trim DELA_PROST_DAN

TRUNCATE staging.holiday;

INSERT INTO staging.holiday (
    raw_date_text,
    holiday_name,
    weekday_name,
    is_public_holiday_raw,
    day,
    month,
    year
)
SELECT
    TRIM(BOTH FROM split_part(raw_line, ';', 1)) AS raw_date_text,
    TRIM(BOTH FROM split_part(raw_line, ';', 2)) AS holiday_name,
    TRIM(BOTH FROM split_part(raw_line, ';', 3)) AS weekday_name,
    TRIM(BOTH FROM split_part(raw_line, ';', 4)) AS is_public_holiday_raw,
    NULLIF(TRIM(split_part(raw_line, ';', 5)), '')::INTEGER AS day,
    NULLIF(TRIM(split_part(raw_line, ';', 6)), '')::INTEGER AS month,
    NULLIF(TRIM(split_part(raw_line, ';', 7)), '')::INTEGER AS year
FROM staging_raw.seznampraznikovindelaprostihdni20002030
WHERE id > 1  -- skip header
  AND TRIM(raw_line) <> ''
  AND split_part(raw_line, ';', 5) ~ '^\d+$';  -- day is numeric (skip metadata)
