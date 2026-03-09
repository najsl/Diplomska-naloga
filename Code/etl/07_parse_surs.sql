-- Step 7: Parse SURS raw tables into staging.municipality_year_indicator_long
-- Skip metadata (id 1-3), parse wide format, unpivot to long
-- Indicator codes: POP_TOTAL, POP_MALE, POP_FEMALE, DENSITY, AREA_KM2, CARS, DWELLINGS, AVG_DWELLING_M2, SCHOOLS, KINDERGARTENS, SHARE_AGE_0_14, EMPLOYMENT_RATE

TRUNCATE staging.municipality_year_indicator_long;

-- Helper: safe numeric parse (handles '-', '...', '..', etc.)
CREATE OR REPLACE FUNCTION staging.safe_numeric(val TEXT) RETURNS NUMERIC AS $$
DECLARE
    cleaned TEXT;
BEGIN
    cleaned := TRIM(REGEXP_REPLACE(COALESCE(val, ''), '[^0-9.,-]', '', 'g'));
    cleaned := REPLACE(cleaned, ',', '.');
    IF cleaned IN ('', '-', '.', '..', '...') OR cleaned !~ '^-?[\d.]+$' THEN
        RETURN NULL;
    END IF;
    RETURN cleaned::NUMERIC;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Helper: extract municipality from column 2, year value from column index
-- SURS format: row 4 = "measure,SLOVENIJA,v2009,v2010,..." or ",Ajdovscina,v2009,..."
-- Year columns start at position 3 (2009) through 17 (2023)

WITH year_cols AS (
    SELECT unnest(ARRAY[2009,2010,2011,2012,2013,2014,2015,2016,2017,2018,2019,2020,2021,2022,2023]) AS yr,
           unnest(ARRAY[3,4,5,6,7,8,9,10,11,12,13,14,15,16,17]) AS col_idx
),
st_prebivalcev_data AS (
    SELECT id, raw_line,
           TRIM(BOTH FROM split_part(raw_line, ',', 2)) AS municipality_name,
           split_part(raw_line, ',', 3) AS v2009, split_part(raw_line, ',', 4) AS v2010,
           split_part(raw_line, ',', 5) AS v2011, split_part(raw_line, ',', 6) AS v2012,
           split_part(raw_line, ',', 7) AS v2013, split_part(raw_line, ',', 8) AS v2014,
           split_part(raw_line, ',', 9) AS v2015, split_part(raw_line, ',', 10) AS v2016,
           split_part(raw_line, ',', 11) AS v2017, split_part(raw_line, ',', 12) AS v2018,
           split_part(raw_line, ',', 13) AS v2019, split_part(raw_line, ',', 14) AS v2020,
           split_part(raw_line, ',', 15) AS v2021, split_part(raw_line, ',', 16) AS v2022,
           split_part(raw_line, ',', 17) AS v2023
    FROM staging_raw.st_prebivalcev
    WHERE id > 3 AND split_part(raw_line, ',', 2) IS NOT NULL AND TRIM(split_part(raw_line, ',', 2)) <> ''
      AND split_part(raw_line, ',', 2) !~ '^(Metodološka|Podatkovna|SI-STAT|ID tabele)'
)
INSERT INTO staging.municipality_year_indicator_long (municipality_name, year, indicator_code, value_numeric, source_table, source_measure)
SELECT municipality_name, y.yr,
       'POP_TOTAL',
       staging.safe_numeric(
           CASE y.yr WHEN 2009 THEN v2009 WHEN 2010 THEN v2010 WHEN 2011 THEN v2011 WHEN 2012 THEN v2012
                    WHEN 2013 THEN v2013 WHEN 2014 THEN v2014 WHEN 2015 THEN v2015 WHEN 2016 THEN v2016
                    WHEN 2017 THEN v2017 WHEN 2018 THEN v2018 WHEN 2019 THEN v2019 WHEN 2020 THEN v2020
                    WHEN 2021 THEN v2021 WHEN 2022 THEN v2022 WHEN 2023 THEN v2023 END),
       'st_prebivalcev', 'Število prebivalcev - 1. julij'
FROM st_prebivalcev_data CROSS JOIN (SELECT generate_series(2009, 2023) AS yr) y
WHERE LENGTH(municipality_name) > 1;

-- st_moskih (POP_MALE)
INSERT INTO staging.municipality_year_indicator_long (municipality_name, year, indicator_code, value_numeric, source_table, source_measure)
SELECT TRIM(BOTH FROM split_part(raw_line, ',', 2)), yr, 'POP_MALE',
       staging.safe_numeric(
           CASE yr WHEN 2009 THEN split_part(raw_line, ',', 3) WHEN 2010 THEN split_part(raw_line, ',', 4)
                   WHEN 2011 THEN split_part(raw_line, ',', 5) WHEN 2012 THEN split_part(raw_line, ',', 6)
                   WHEN 2013 THEN split_part(raw_line, ',', 7) WHEN 2014 THEN split_part(raw_line, ',', 8)
                   WHEN 2015 THEN split_part(raw_line, ',', 9) WHEN 2016 THEN split_part(raw_line, ',', 10)
                   WHEN 2017 THEN split_part(raw_line, ',', 11) WHEN 2018 THEN split_part(raw_line, ',', 12)
                   WHEN 2019 THEN split_part(raw_line, ',', 13) WHEN 2020 THEN split_part(raw_line, ',', 14)
                   WHEN 2021 THEN split_part(raw_line, ',', 15) WHEN 2022 THEN split_part(raw_line, ',', 16)
                   WHEN 2023 THEN split_part(raw_line, ',', 17) END),
       'st_moskih', 'Število moških - 1. julij'
FROM staging_raw.st_moskih, generate_series(2009, 2023) yr
WHERE id > 3 AND TRIM(split_part(raw_line, ',', 2)) <> ''
  AND split_part(raw_line, ',', 2) !~ '^(Metodološka|Podatkovna|SI-STAT|ID)';

-- st_zensk (POP_FEMALE)
INSERT INTO staging.municipality_year_indicator_long (municipality_name, year, indicator_code, value_numeric, source_table, source_measure)
SELECT TRIM(split_part(raw_line, ',', 2)), yr,
       'POP_FEMALE',
       staging.safe_numeric(
           CASE yr WHEN 2009 THEN split_part(raw_line, ',', 3) WHEN 2010 THEN split_part(raw_line, ',', 4)
                   WHEN 2011 THEN split_part(raw_line, ',', 5) WHEN 2012 THEN split_part(raw_line, ',', 6)
                   WHEN 2013 THEN split_part(raw_line, ',', 7) WHEN 2014 THEN split_part(raw_line, ',', 8)
                   WHEN 2015 THEN split_part(raw_line, ',', 9) WHEN 2016 THEN split_part(raw_line, ',', 10)
                   WHEN 2017 THEN split_part(raw_line, ',', 11) WHEN 2018 THEN split_part(raw_line, ',', 12)
                   WHEN 2019 THEN split_part(raw_line, ',', 13) WHEN 2020 THEN split_part(raw_line, ',', 14)
                   WHEN 2021 THEN split_part(raw_line, ',', 15) WHEN 2022 THEN split_part(raw_line, ',', 16)
                   WHEN 2023 THEN split_part(raw_line, ',', 17) END),
       'st_zensk', 'Število žensk - 1. julij'
FROM staging_raw.st_zensk, generate_series(2009, 2023) yr
WHERE id > 3 AND TRIM(split_part(raw_line, ',', 2)) <> ''
  AND split_part(raw_line, ',', 2) !~ '^(Metodološka|Podatkovna|SI-STAT|ID)';

-- gostota_poseljenosti (DENSITY)
INSERT INTO staging.municipality_year_indicator_long (municipality_name, year, indicator_code, value_numeric, source_table, source_measure)
SELECT TRIM(BOTH FROM split_part(raw_line, ',', 2)), yr, 'DENSITY',
       staging.safe_numeric(
           CASE yr WHEN 2009 THEN split_part(raw_line, ',', 3) WHEN 2010 THEN split_part(raw_line, ',', 4)
                   WHEN 2011 THEN split_part(raw_line, ',', 5) WHEN 2012 THEN split_part(raw_line, ',', 6)
                   WHEN 2013 THEN split_part(raw_line, ',', 7) WHEN 2014 THEN split_part(raw_line, ',', 8)
                   WHEN 2015 THEN split_part(raw_line, ',', 9) WHEN 2016 THEN split_part(raw_line, ',', 10)
                   WHEN 2017 THEN split_part(raw_line, ',', 11) WHEN 2018 THEN split_part(raw_line, ',', 12)
                   WHEN 2019 THEN split_part(raw_line, ',', 13) WHEN 2020 THEN split_part(raw_line, ',', 14)
                   WHEN 2021 THEN split_part(raw_line, ',', 15) WHEN 2022 THEN split_part(raw_line, ',', 16)
                   WHEN 2023 THEN split_part(raw_line, ',', 17) END),
       'gostota_poseljenosti', 'Gostota naseljenosti - 1. julij'
FROM staging_raw.gostota_poseljenosti_municipality, generate_series(2009, 2023) yr
WHERE id > 3 AND TRIM(split_part(raw_line, ',', 2)) <> ''
  AND split_part(raw_line, ',', 2) !~ '^(Metodološka|Podatkovna|SI-STAT|ID)';

-- povrsina_obcine (AREA_KM2)
INSERT INTO staging.municipality_year_indicator_long (municipality_name, year, indicator_code, value_numeric, source_table, source_measure)
SELECT TRIM(BOTH FROM split_part(raw_line, ',', 2)), yr, 'AREA_KM2',
       staging.safe_numeric(
           CASE yr WHEN 2009 THEN split_part(raw_line, ',', 3) WHEN 2010 THEN split_part(raw_line, ',', 4)
                   WHEN 2011 THEN split_part(raw_line, ',', 5) WHEN 2012 THEN split_part(raw_line, ',', 6)
                   WHEN 2013 THEN split_part(raw_line, ',', 7) WHEN 2014 THEN split_part(raw_line, ',', 8)
                   WHEN 2015 THEN split_part(raw_line, ',', 9) WHEN 2016 THEN split_part(raw_line, ',', 10)
                   WHEN 2017 THEN split_part(raw_line, ',', 11) WHEN 2018 THEN split_part(raw_line, ',', 12)
                   WHEN 2019 THEN split_part(raw_line, ',', 13) WHEN 2020 THEN split_part(raw_line, ',', 14)
                   WHEN 2021 THEN split_part(raw_line, ',', 15) WHEN 2022 THEN split_part(raw_line, ',', 16)
                   WHEN 2023 THEN split_part(raw_line, ',', 17) END),
       'povrsina_obcine', 'Površina (km2) - 1. januar'
FROM staging_raw.povrsina_obcine, generate_series(2009, 2023) yr
WHERE id > 3 AND TRIM(split_part(raw_line, ',', 2)) <> ''
  AND split_part(raw_line, ',', 2) !~ '^(Metodološka|Podatkovna|SI-STAT|ID)';

-- st_avtomobilov (CARS)
INSERT INTO staging.municipality_year_indicator_long (municipality_name, year, indicator_code, value_numeric, source_table, source_measure)
SELECT TRIM(BOTH FROM split_part(raw_line, ',', 2)), yr, 'CARS',
       staging.safe_numeric(
           CASE yr WHEN 2009 THEN split_part(raw_line, ',', 3) WHEN 2010 THEN split_part(raw_line, ',', 4)
                   WHEN 2011 THEN split_part(raw_line, ',', 5) WHEN 2012 THEN split_part(raw_line, ',', 6)
                   WHEN 2013 THEN split_part(raw_line, ',', 7) WHEN 2014 THEN split_part(raw_line, ',', 8)
                   WHEN 2015 THEN split_part(raw_line, ',', 9) WHEN 2016 THEN split_part(raw_line, ',', 10)
                   WHEN 2017 THEN split_part(raw_line, ',', 11) WHEN 2018 THEN split_part(raw_line, ',', 12)
                   WHEN 2019 THEN split_part(raw_line, ',', 13) WHEN 2020 THEN split_part(raw_line, ',', 14)
                   WHEN 2021 THEN split_part(raw_line, ',', 15) WHEN 2022 THEN split_part(raw_line, ',', 16)
                   WHEN 2023 THEN split_part(raw_line, ',', 17) END),
       'st_avtomobilov', 'Število osebnih avtomobilov - 31. december'
FROM staging_raw.st_avtomobilov, generate_series(2009, 2023) yr
WHERE id > 3 AND TRIM(split_part(raw_line, ',', 2)) <> ''
  AND split_part(raw_line, ',', 2) !~ '^(Metodološka|Podatkovna|SI-STAT|ID)';

-- st_sol (SCHOOLS), st_vrtcev (KINDERGARTENS), stopnja_delovne_aktivnosti (EMPLOYMENT_RATE)
INSERT INTO staging.municipality_year_indicator_long (municipality_name, year, indicator_code, value_numeric, source_table, source_measure)
SELECT TRIM(BOTH FROM split_part(raw_line, ',', 2)), yr, 'SCHOOLS',
       staging.safe_numeric(
           CASE yr WHEN 2009 THEN split_part(raw_line, ',', 3) WHEN 2010 THEN split_part(raw_line, ',', 4)
                   WHEN 2011 THEN split_part(raw_line, ',', 5) WHEN 2012 THEN split_part(raw_line, ',', 6)
                   WHEN 2013 THEN split_part(raw_line, ',', 7) WHEN 2014 THEN split_part(raw_line, ',', 8)
                   WHEN 2015 THEN split_part(raw_line, ',', 9) WHEN 2016 THEN split_part(raw_line, ',', 10)
                   WHEN 2017 THEN split_part(raw_line, ',', 11) WHEN 2018 THEN split_part(raw_line, ',', 12)
                   WHEN 2019 THEN split_part(raw_line, ',', 13) WHEN 2020 THEN split_part(raw_line, ',', 14)
                   WHEN 2021 THEN split_part(raw_line, ',', 15) WHEN 2022 THEN split_part(raw_line, ',', 16)
                   WHEN 2023 THEN split_part(raw_line, ',', 17) END),
       'st_sol', 'Število šol'
FROM staging_raw.st_sol, generate_series(2009, 2023) yr
WHERE id > 3 AND TRIM(split_part(raw_line, ',', 2)) <> ''
  AND split_part(raw_line, ',', 2) !~ '^(Metodološka|Podatkovna|SI-STAT|ID)';

INSERT INTO staging.municipality_year_indicator_long (municipality_name, year, indicator_code, value_numeric, source_table, source_measure)
SELECT TRIM(BOTH FROM split_part(raw_line, ',', 2)), yr, 'KINDERGARTENS',
       staging.safe_numeric(
           CASE yr WHEN 2009 THEN split_part(raw_line, ',', 3) WHEN 2010 THEN split_part(raw_line, ',', 4)
                   WHEN 2011 THEN split_part(raw_line, ',', 5) WHEN 2012 THEN split_part(raw_line, ',', 6)
                   WHEN 2013 THEN split_part(raw_line, ',', 7) WHEN 2014 THEN split_part(raw_line, ',', 8)
                   WHEN 2015 THEN split_part(raw_line, ',', 9) WHEN 2016 THEN split_part(raw_line, ',', 10)
                   WHEN 2017 THEN split_part(raw_line, ',', 11) WHEN 2018 THEN split_part(raw_line, ',', 12)
                   WHEN 2019 THEN split_part(raw_line, ',', 13) WHEN 2020 THEN split_part(raw_line, ',', 14)
                   WHEN 2021 THEN split_part(raw_line, ',', 15) WHEN 2022 THEN split_part(raw_line, ',', 16)
                   WHEN 2023 THEN split_part(raw_line, ',', 17) END),
       'st_vrtcev', 'Število vrtcev'
FROM staging_raw.st_vrtcev, generate_series(2009, 2023) yr
WHERE id > 3 AND TRIM(split_part(raw_line, ',', 2)) <> ''
  AND split_part(raw_line, ',', 2) !~ '^(Metodološka|Podatkovna|SI-STAT|ID)';

INSERT INTO staging.municipality_year_indicator_long (municipality_name, year, indicator_code, value_numeric, source_table, source_measure)
SELECT TRIM(BOTH FROM split_part(raw_line, ',', 2)), yr, 'EMPLOYMENT_RATE',
       staging.safe_numeric(
           CASE yr WHEN 2009 THEN split_part(raw_line, ',', 3) WHEN 2010 THEN split_part(raw_line, ',', 4)
                   WHEN 2011 THEN split_part(raw_line, ',', 5) WHEN 2012 THEN split_part(raw_line, ',', 6)
                   WHEN 2013 THEN split_part(raw_line, ',', 7) WHEN 2014 THEN split_part(raw_line, ',', 8)
                   WHEN 2015 THEN split_part(raw_line, ',', 9) WHEN 2016 THEN split_part(raw_line, ',', 10)
                   WHEN 2017 THEN split_part(raw_line, ',', 11) WHEN 2018 THEN split_part(raw_line, ',', 12)
                   WHEN 2019 THEN split_part(raw_line, ',', 13) WHEN 2020 THEN split_part(raw_line, ',', 14)
                   WHEN 2021 THEN split_part(raw_line, ',', 15) WHEN 2022 THEN split_part(raw_line, ',', 16)
                   WHEN 2023 THEN split_part(raw_line, ',', 17) END),
       'stopnja_delovne_aktivnosti', 'Stopnja delovne aktivnosti (%)'
FROM staging_raw.stopnja_delovne_aktivnosti, generate_series(2009, 2023) yr
WHERE id > 3 AND TRIM(split_part(raw_line, ',', 2)) <> ''
  AND split_part(raw_line, ',', 2) !~ '^(Metodološka|Podatkovna|SI-STAT|ID)';

-- st_stanovanj (DWELLINGS) - sparse years (2011, 2015, 2019, 2021...); safe_numeric handles '...'
INSERT INTO staging.municipality_year_indicator_long (municipality_name, year, indicator_code, value_numeric, source_table, source_measure)
SELECT TRIM(BOTH FROM split_part(raw_line, ',', 2)), yr, 'DWELLINGS',
       staging.safe_numeric(
           CASE yr WHEN 2009 THEN split_part(raw_line, ',', 3) WHEN 2010 THEN split_part(raw_line, ',', 4)
                   WHEN 2011 THEN split_part(raw_line, ',', 5) WHEN 2012 THEN split_part(raw_line, ',', 6)
                   WHEN 2013 THEN split_part(raw_line, ',', 7) WHEN 2014 THEN split_part(raw_line, ',', 8)
                   WHEN 2015 THEN split_part(raw_line, ',', 9) WHEN 2016 THEN split_part(raw_line, ',', 10)
                   WHEN 2017 THEN split_part(raw_line, ',', 11) WHEN 2018 THEN split_part(raw_line, ',', 12)
                   WHEN 2019 THEN split_part(raw_line, ',', 13) WHEN 2020 THEN split_part(raw_line, ',', 14)
                   WHEN 2021 THEN split_part(raw_line, ',', 15) WHEN 2022 THEN split_part(raw_line, ',', 16)
                   WHEN 2023 THEN split_part(raw_line, ',', 17) END),
       'st_stanovanj', 'Število stanovanj'
FROM staging_raw.st_stanovanj, generate_series(2009, 2023) yr
WHERE id > 3 AND TRIM(split_part(raw_line, ',', 2)) <> ''
  AND split_part(raw_line, ',', 2) !~ '^(Metodološka|Podatkovna|SI-STAT|ID)';

-- povp_povrsina_stanovanj (AVG_DWELLING_M2) - same sparse pattern
INSERT INTO staging.municipality_year_indicator_long (municipality_name, year, indicator_code, value_numeric, source_table, source_measure)
SELECT TRIM(BOTH FROM split_part(raw_line, ',', 2)), yr, 'AVG_DWELLING_M2',
       staging.safe_numeric(
           CASE yr WHEN 2009 THEN split_part(raw_line, ',', 3) WHEN 2010 THEN split_part(raw_line, ',', 4)
                   WHEN 2011 THEN split_part(raw_line, ',', 5) WHEN 2012 THEN split_part(raw_line, ',', 6)
                   WHEN 2013 THEN split_part(raw_line, ',', 7) WHEN 2014 THEN split_part(raw_line, ',', 8)
                   WHEN 2015 THEN split_part(raw_line, ',', 9) WHEN 2016 THEN split_part(raw_line, ',', 10)
                   WHEN 2017 THEN split_part(raw_line, ',', 11) WHEN 2018 THEN split_part(raw_line, ',', 12)
                   WHEN 2019 THEN split_part(raw_line, ',', 13) WHEN 2020 THEN split_part(raw_line, ',', 14)
                   WHEN 2021 THEN split_part(raw_line, ',', 15) WHEN 2022 THEN split_part(raw_line, ',', 16)
                   WHEN 2023 THEN split_part(raw_line, ',', 17) END),
       'povp_povrsina_stanovanj', 'Povprečna površina stanovanj (m2)'
FROM staging_raw.povp_povrsina_stanovanj, generate_series(2009, 2023) yr
WHERE id > 3 AND TRIM(split_part(raw_line, ',', 2)) <> ''
  AND split_part(raw_line, ',', 2) !~ '^(Metodološka|Podatkovna|SI-STAT|ID)';

-- starost_prebivalcev (SHARE_AGE_0_14) - filter rows where col1 contains "0 do 14" or "Delez prebivalcev starih 0 do 14"
INSERT INTO staging.municipality_year_indicator_long (municipality_name, year, indicator_code, value_numeric, source_table, source_measure)
SELECT TRIM(BOTH FROM split_part(raw_line, ',', 2)), yr, 'SHARE_AGE_0_14',
       staging.safe_numeric(
           CASE yr WHEN 2009 THEN split_part(raw_line, ',', 3) WHEN 2010 THEN split_part(raw_line, ',', 4)
                   WHEN 2011 THEN split_part(raw_line, ',', 5) WHEN 2012 THEN split_part(raw_line, ',', 6)
                   WHEN 2013 THEN split_part(raw_line, ',', 7) WHEN 2014 THEN split_part(raw_line, ',', 8)
                   WHEN 2015 THEN split_part(raw_line, ',', 9) WHEN 2016 THEN split_part(raw_line, ',', 10)
                   WHEN 2017 THEN split_part(raw_line, ',', 11) WHEN 2018 THEN split_part(raw_line, ',', 12)
                   WHEN 2019 THEN split_part(raw_line, ',', 13) WHEN 2020 THEN split_part(raw_line, ',', 14)
                   WHEN 2021 THEN split_part(raw_line, ',', 15) WHEN 2022 THEN split_part(raw_line, ',', 16)
                   WHEN 2023 THEN split_part(raw_line, ',', 17) END),
       'starost_prebivalcev', 'Delež prebivalcev starih 0 do 14 let'
FROM staging_raw.starost_prebivalcev, generate_series(2009, 2023) yr
WHERE id > 3 AND TRIM(split_part(raw_line, ',', 2)) <> ''
  AND split_part(raw_line, ',', 2) !~ '^(Metodološka|Podatkovna|SI-STAT|ID)'
  AND (split_part(raw_line, ',', 1) LIKE '%0 do 14%' OR split_part(raw_line, ',', 1) LIKE '%Delez prebivalcev starih 0 do 14%');
