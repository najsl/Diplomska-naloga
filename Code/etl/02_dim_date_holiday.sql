-- Step 2: Build core.dim_holiday, core.dim_date, link holiday_id
-- Order: dim_holiday first (no deps), then dim_date (FK to dim_holiday)

-- 2.1 Populate core.dim_holiday from staging.holiday
-- Parse raw_date_text (D.MM.LLLL or D.MM.YYYY) to DATE
TRUNCATE core.dim_holiday CASCADE;

INSERT INTO core.dim_holiday (
    holiday_date,
    holiday_name,
    is_public_holiday,
    day_of_week,
    day_of_week_name,
    year,
    month,
    day
)
SELECT DISTINCT ON (TO_DATE(raw_date_text, 'DD.MM.YYYY'))
    TO_DATE(
        CASE
            WHEN raw_date_text ~ '^\d{1,2}\.\d{1,2}\.\d{4}$' THEN raw_date_text
            ELSE NULL
        END,
        'DD.MM.YYYY'
    ) AS holiday_date,
    holiday_name,
    LOWER(TRIM(is_public_holiday_raw)) = 'da' AS is_public_holiday,
    EXTRACT(ISODOW FROM TO_DATE(raw_date_text, 'DD.MM.YYYY'))::INTEGER AS day_of_week,
    weekday_name AS day_of_week_name,
    year,
    month,
    day
FROM staging.holiday
WHERE raw_date_text ~ '^\d{1,2}\.\d{1,2}\.\d{4}$'
  AND day IS NOT NULL AND month IS NOT NULL AND year IS NOT NULL
ORDER BY TO_DATE(raw_date_text, 'DD.MM.YYYY'), holiday_name;

-- 2.2 Generate core.dim_date (2000-01-01 to 2030-12-31)
TRUNCATE core.dim_date CASCADE;

INSERT INTO core.dim_date (
    date_id,
    full_date,
    year,
    quarter,
    month,
    day,
    week_of_year,
    day_of_week,
    day_of_week_name,
    is_weekend,
    holiday_id
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INTEGER AS date_id,
    d AS full_date,
    EXTRACT(YEAR FROM d)::INTEGER AS year,
    EXTRACT(QUARTER FROM d)::INTEGER AS quarter,
    EXTRACT(MONTH FROM d)::INTEGER AS month,
    EXTRACT(DAY FROM d)::INTEGER AS day,
    EXTRACT(WEEK FROM d)::INTEGER AS week_of_year,
    EXTRACT(ISODOW FROM d)::INTEGER AS day_of_week,
    TO_CHAR(d, 'Day') AS day_of_week_name,
    EXTRACT(ISODOW FROM d) IN (6, 7) AS is_weekend,
    h.holiday_id
FROM generate_series('2000-01-01'::DATE, '2030-12-31'::DATE, '1 day'::INTERVAL) AS d
LEFT JOIN core.dim_holiday h ON h.holiday_date = d;

-- 2.3 Add FK constraint if not exists (already in schema, but ensure it's applied)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_dim_date_holiday'
    ) THEN
        ALTER TABLE core.dim_date
            ADD CONSTRAINT fk_dim_date_holiday
            FOREIGN KEY (holiday_id) REFERENCES core.dim_holiday(holiday_id);
    END IF;
END $$;
