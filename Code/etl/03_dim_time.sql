-- Step 3: Build core.dim_time
-- Generate one row per minute (00:00 to 23:59) for full coverage

TRUNCATE core.dim_time CASCADE;

INSERT INTO core.dim_time (time_of_day, hour, minute, time_bucket)
SELECT
    (timestamp '2000-01-01 00:00' + (mins || ' minutes')::INTERVAL)::TIME AS time_of_day,
    (mins / 60)::INTEGER AS hour,
    (mins % 60)::INTEGER AS minute,
    CASE
        WHEN (mins / 60) BETWEEN 0 AND 5 THEN 'night'
        WHEN (mins / 60) BETWEEN 6 AND 9 THEN 'morning_peak'
        WHEN (mins / 60) BETWEEN 10 AND 11 THEN 'mid_morning'
        WHEN (mins / 60) BETWEEN 12 AND 13 THEN 'midday'
        WHEN (mins / 60) BETWEEN 14 AND 16 THEN 'afternoon'
        WHEN (mins / 60) BETWEEN 17 AND 19 THEN 'evening_peak'
        WHEN (mins / 60) BETWEEN 20 AND 23 THEN 'evening'
        ELSE 'other'
    END AS time_bucket
FROM generate_series(0, 1439) AS mins;
