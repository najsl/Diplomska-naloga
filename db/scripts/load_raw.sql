-- Load CSV files into staging_raw tables (one line per raw_line)
-- Run from db/ directory after: docker compose up -d
-- Usage: Get-Content scripts/load_raw.sql | docker exec -i postgres_db psql -U diplomska -d diplomska

\set ON_ERROR_STOP on

-- 1. Accidents (pn2009_2023.csv)
\echo 'Loading pn2009_2023...'
COPY staging_raw.pn2009_2023 (raw_line) FROM '/dataset/pn2009_2023.csv' WITH (FORMAT text, ENCODING 'UTF8');

-- 2. Holidays (seznampraznikovindelaprostihdni20002030.csv)
\echo 'Loading seznampraznikovindelaprostihdni20002030...'
COPY staging_raw.seznampraznikovindelaprostihdni20002030 (raw_line) FROM '/dataset/seznampraznikovindelaprostihdni20002030.csv' WITH (FORMAT text, ENCODING 'UTF8');

-- 3. Population density - municipality (gostota_poseljenosti.csv)
\echo 'Loading gostota_poseljenosti_municipality...'
COPY staging_raw.gostota_poseljenosti_municipality (raw_line) FROM '/dataset/gostota_poseljenosti.csv' WITH (FORMAT text, ENCODING 'UTF8');

-- 4. Population density - settlement (Gostota poseljenosti.csv)
\echo 'Loading gostota_poseljenosti_settlement...'
COPY staging_raw.gostota_poseljenosti_settlement (raw_line) FROM '/dataset/Gostota poseljenosti.csv' WITH (FORMAT text, ENCODING 'UTF8');

-- 5. Area (povrsina_obcine.csv)
\echo 'Loading povrsina_obcine...'
COPY staging_raw.povrsina_obcine (raw_line) FROM '/dataset/povrsina_obcine.csv' WITH (FORMAT text, ENCODING 'UTF8');

-- 6. Population (st_prebivalcev.csv)
\echo 'Loading st_prebivalcev...'
COPY staging_raw.st_prebivalcev (raw_line) FROM '/dataset/st_prebivalcev.csv' WITH (FORMAT text, ENCODING 'UTF8');

-- 7. Male population (st_moskih.csv)
\echo 'Loading st_moskih...'
COPY staging_raw.st_moskih (raw_line) FROM '/dataset/st_moskih.csv' WITH (FORMAT text, ENCODING 'UTF8');

-- 8. Female population (st_zensk.csv)
\echo 'Loading st_zensk...'
COPY staging_raw.st_zensk (raw_line) FROM '/dataset/st_zensk.csv' WITH (FORMAT text, ENCODING 'UTF8');

-- 9. Cars (st_avtomobilov.csv)
\echo 'Loading st_avtomobilov...'
COPY staging_raw.st_avtomobilov (raw_line) FROM '/dataset/st_avtomobilov.csv' WITH (FORMAT text, ENCODING 'UTF8');

-- 10. Dwellings (st_stanovanj.csv)
\echo 'Loading st_stanovanj...'
COPY staging_raw.st_stanovanj (raw_line) FROM '/dataset/st_stanovanj.csv' WITH (FORMAT text, ENCODING 'UTF8');

-- 11. Avg dwelling area (povp_povrsina_stanovanj.csv)
\echo 'Loading povp_povrsina_stanovanj...'
COPY staging_raw.povp_povrsina_stanovanj (raw_line) FROM '/dataset/povp_povrsina_stanovanj.csv' WITH (FORMAT text, ENCODING 'UTF8');

-- 12. Schools (st_sol.csv)
\echo 'Loading st_sol...'
COPY staging_raw.st_sol (raw_line) FROM '/dataset/st_sol.csv' WITH (FORMAT text, ENCODING 'UTF8');

-- 13. Kindergartens (st_vrtcev.csv)
\echo 'Loading st_vrtcev...'
COPY staging_raw.st_vrtcev (raw_line) FROM '/dataset/st_vrtcev.csv' WITH (FORMAT text, ENCODING 'UTF8');

-- 14. Age structure (starost_prebivalcev.csv)
\echo 'Loading starost_prebivalcev...'
COPY staging_raw.starost_prebivalcev (raw_line) FROM '/dataset/starost_prebivalcev.csv' WITH (FORMAT text, ENCODING 'UTF8');

-- 15. Employment rate (stopnja_delovne_aktivnosti.csv)
\echo 'Loading stopnja_delovne_aktivnosti...'
COPY staging_raw.stopnja_delovne_aktivnosti (raw_line) FROM '/dataset/stopnja_delovne_aktivnosti.csv' WITH (FORMAT text, ENCODING 'UTF8');

\echo 'Done. Verifying row counts...'
SELECT 'pn2009_2023' AS table_name, COUNT(*) FROM staging_raw.pn2009_2023
UNION ALL SELECT 'seznampraznikovindelaprostihdni20002030', COUNT(*) FROM staging_raw.seznampraznikovindelaprostihdni20002030
UNION ALL SELECT 'gostota_poseljenosti_municipality', COUNT(*) FROM staging_raw.gostota_poseljenosti_municipality
UNION ALL SELECT 'gostota_poseljenosti_settlement', COUNT(*) FROM staging_raw.gostota_poseljenosti_settlement
UNION ALL SELECT 'povrsina_obcine', COUNT(*) FROM staging_raw.povrsina_obcine
UNION ALL SELECT 'st_prebivalcev', COUNT(*) FROM staging_raw.st_prebivalcev
UNION ALL SELECT 'st_moskih', COUNT(*) FROM staging_raw.st_moskih
UNION ALL SELECT 'st_zensk', COUNT(*) FROM staging_raw.st_zensk
UNION ALL SELECT 'st_avtomobilov', COUNT(*) FROM staging_raw.st_avtomobilov
UNION ALL SELECT 'st_stanovanj', COUNT(*) FROM staging_raw.st_stanovanj
UNION ALL SELECT 'povp_povrsina_stanovanj', COUNT(*) FROM staging_raw.povp_povrsina_stanovanj
UNION ALL SELECT 'st_sol', COUNT(*) FROM staging_raw.st_sol
UNION ALL SELECT 'st_vrtcev', COUNT(*) FROM staging_raw.st_vrtcev
UNION ALL SELECT 'starost_prebivalcev', COUNT(*) FROM staging_raw.starost_prebivalcev
UNION ALL SELECT 'stopnja_delovne_aktivnosti', COUNT(*) FROM staging_raw.stopnja_delovne_aktivnosti
ORDER BY table_name;
